"""Global prompt file: cross-worker reloads, atomic writes, failed writes keep the previous configuration."""

import json
import os

import pytest

from src.core.settings import system_prompts as store


@pytest.fixture
def prompts_path(tmp_path, monkeypatch):
    path = tmp_path / "conf" / "prompts.json"
    monkeypatch.setattr(store, "_prompts_path", lambda: path)
    store.load_system_prompts()
    yield path
    monkeypatch.undo()
    store.load_system_prompts()


def write_external(path, **values):
    """Another worker's write: the same atomic replacement, outside this module's state."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".other")
    tmp.write_text(json.dumps({**store.DEFAULT_PROMPTS, **values}), encoding="utf-8")
    os.replace(tmp, path)


def test_reader_started_before_the_file_exists_sees_it_once_created(prompts_path):
    assert not prompts_path.exists()
    assert store.get_system_prompts()["stream_system_prompt"] == store.DEFAULT_PROMPTS["stream_system_prompt"]
    write_external(prompts_path, stream_system_prompt="Created by another worker.")
    assert store.get_system_prompts()["stream_system_prompt"] == "Created by another worker."


def test_external_updates_are_picked_up_even_with_an_unchanged_timestamp(prompts_path):
    write_external(prompts_path, stream_system_prompt="First.")
    assert store.get_system_prompts()["stream_system_prompt"] == "First."
    stamp = prompts_path.stat().st_mtime_ns
    write_external(prompts_path, stream_system_prompt="Second, longer text.")
    os.utime(prompts_path, ns=(stamp, stamp))  # coarse filesystem clock: same timestamp, different size
    assert store.get_system_prompts()["stream_system_prompt"] == "Second, longer text."
    prompts_path.unlink()
    assert store.get_system_prompts() == store.DEFAULT_PROMPTS


def test_save_replaces_the_file_atomically_and_updates_memory(prompts_path):
    saved = store.save_system_prompts({"memory_system_prompt": "Saved.", "unknown_key": "ignored"})
    assert saved["memory_system_prompt"] == "Saved."
    on_disk = json.loads(prompts_path.read_text(encoding="utf-8"))
    assert on_disk["memory_system_prompt"] == "Saved." and "unknown_key" not in on_disk
    assert [p.name for p in prompts_path.parent.iterdir()] == ["prompts.json"]  # no temp files left


def test_failed_write_keeps_the_previous_configuration(prompts_path, monkeypatch):
    store.save_system_prompts({"stream_system_prompt": "Before."})
    before_file = prompts_path.read_text(encoding="utf-8")

    def broken_replace(src, dst):
        raise OSError("disk full")

    monkeypatch.setattr(store.os, "replace", broken_replace)
    with pytest.raises(OSError):
        store.save_system_prompts({"stream_system_prompt": "After."})
    assert prompts_path.read_text(encoding="utf-8") == before_file
    assert store.get_system_prompts()["stream_system_prompt"] == "Before."
    assert [p.name for p in prompts_path.parent.iterdir()] == ["prompts.json"]


def test_a_failure_while_serializing_never_exposes_partial_json(prompts_path, monkeypatch):
    store.save_system_prompts({"stream_system_prompt": "Intact."})

    def half_dump(obj, handle, **_):
        handle.write('{"stream_system_prompt": "trunc')
        raise RuntimeError("crash mid-write")

    monkeypatch.setattr(store.json, "dump", half_dump)
    with pytest.raises(RuntimeError):
        store.save_system_prompts({"stream_system_prompt": "Never visible."})
    monkeypatch.undo()
    monkeypatch.setattr(store, "_prompts_path", lambda: prompts_path)
    assert json.loads(prompts_path.read_text(encoding="utf-8"))["stream_system_prompt"] == "Intact."
    assert store.get_system_prompts()["stream_system_prompt"] == "Intact."


def test_a_save_does_not_revert_another_workers_newer_keys(prompts_path):
    store.get_system_prompts()
    write_external(prompts_path, tools_system_prompt="From worker B.")
    store.save_system_prompts({"stream_system_prompt": "From worker A."})
    on_disk = json.loads(prompts_path.read_text(encoding="utf-8"))
    assert on_disk["tools_system_prompt"] == "From worker B."
    assert on_disk["stream_system_prompt"] == "From worker A."
