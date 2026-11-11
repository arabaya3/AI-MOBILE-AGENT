"""The mobile release-config preflight (mobile/tool/check_release_config.py) refuses unsafe or missing values."""

import importlib.util
import json
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "mobile" / "tool" / "check_release_config.py"
spec = importlib.util.spec_from_file_location("check_release_config", SCRIPT)
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


@pytest.mark.parametrize(
    ("config", "problem"),
    [
        ({}, "missing"),
        ({"API_BASE_URL": ""}, "missing"),
        ({"API_BASE_URL": "http://api.example.com/api/v1"}, "https"),
        ({"API_BASE_URL": "https://203.0.113.7/api/v1"}, "IP address"),
        ({"API_BASE_URL": "https://localhost/api/v1"}, "public host"),
        ({"API_BASE_URL": "https://user:pw@api.example.com/api/v1"}, "credentials"),
        ({"API_BASE_URL": "https://api.example.com/api/v1?x=1"}, "query"),
        ({"API_BASE_URL": "https://api.example.com/api/v1", "APP_LINK_HOSTS": "localhost"}, "invalid host"),
        ({"API_BASE_URL": "https://api.example.com/api/v1", "OPENAI_API_KEY": "x"}, "unknown key"),
    ],
)
def test_unsafe_configs_are_refused(config, problem):
    assert any(problem in p for p in check.problems(config))


def test_a_complete_config_passes(tmp_path, capsys):
    path = tmp_path / "prod.json"
    path.write_text(json.dumps({"API_BASE_URL": "https://api.example.com/api/v1", "APP_LINK_HOSTS": "app.example.com"}))
    assert check.main(["check", str(path)]) == 0
    assert "OK" in capsys.readouterr().out


def test_the_committed_examples_are_not_releasable():
    for name in ("staging.example.json", "prod.example.json"):
        assert check.main(["check", str(SCRIPT.parents[1] / "config" / name)]) == 1
