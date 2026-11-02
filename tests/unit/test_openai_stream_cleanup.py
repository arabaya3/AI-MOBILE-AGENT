"""The real OpenAI adapter against a controlled fake upstream stream: cleanup on every exit path."""

import asyncio
import queue
import threading
import time
from types import SimpleNamespace

import pytest

from src.core.settings.config import settings
from src.services.llm_providers.openai.chat import OpenAIChatService

END = object()
BOOM = object()


def delta(text):
    return SimpleNamespace(choices=[SimpleNamespace(delta=SimpleNamespace(content=text))], usage=None)


def usage(prompt, completion):
    return SimpleNamespace(
        choices=[], usage=SimpleNamespace(prompt_tokens=prompt, completion_tokens=completion, total_tokens=prompt + completion)
    )


class FakeStream:
    """Blocks on each read until the test feeds an event; close() unblocks a pending read, like an HTTP close."""

    def __init__(self, unblock_on_close=True):
        self.events = queue.Queue()
        self.closed = threading.Event()
        self.unblock_on_close = unblock_on_close
        self.pulled = 0

    def feed(self, *events):
        for event in events:
            self.events.put(event)

    def close(self):
        self.closed.set()
        if self.unblock_on_close:
            self.events.put(END)

    def __iter__(self):
        return self

    def __next__(self):
        event = self.events.get()
        if event is END:
            if self.closed.is_set():
                raise RuntimeError("connection closed")
            raise StopIteration
        if event is BOOM:
            raise RuntimeError("upstream exploded")
        self.pulled += 1
        return event


class FakeClient:
    def __init__(self, stream, create_gate=None):
        self.stream = stream
        self.create_gate = create_gate
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create))

    def _create(self, **_kwargs):
        if self.create_gate is not None:
            self.create_gate.wait()
        return self.stream


def adapter(client):
    service = OpenAIChatService(model="gpt-4o-mini")
    service._get_client = lambda *_args, **_kwargs: client
    return service


def stream_of(service, sink=None):
    return service.stream_with_memory(history=[], question="hi", contexts=[], usage_sink=sink)


def workers():
    return [t for t in threading.enumerate() if t.name == "openai-chat-stream"]


async def wait_until(condition, timeout=3.0):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if condition():
            return True
        await asyncio.sleep(0.01)
    return condition()


@pytest.fixture(autouse=True)
def no_leftover_workers():
    yield
    for thread in workers():
        thread.join(timeout=3)
    assert workers() == []


async def test_completion_reports_usage_and_closes_upstream():
    stream = FakeStream()
    stream.feed(delta("Hel"), delta("lo"), usage(7, 3), END)
    sink = {}
    chunks = [chunk async for chunk in stream_of(adapter(FakeClient(stream)), sink)]
    assert "".join(chunks) == "Hello"
    assert sink == {"input_tokens": 7, "output_tokens": 3, "total_tokens": 10}
    assert stream.closed.is_set()


async def test_cancel_while_upstream_is_blocked_closes_it_and_ends_the_worker():
    stream = FakeStream()
    stream.feed(delta("first"))
    gen = stream_of(adapter(FakeClient(stream)))
    assert await gen.__anext__() == "first"
    assert workers(), "the worker is blocked reading the next event"
    await gen.aclose()  # what StreamingResponse does when the client disconnects
    assert stream.closed.is_set()
    assert await wait_until(lambda: not workers())


async def test_stalled_upstream_hits_idle_timeout_and_is_closed(monkeypatch):
    monkeypatch.setattr(settings, "PROVIDER_STREAM_IDLE_TIMEOUT_SECONDS", 0.2)
    stream = FakeStream()
    stream.feed(delta("partial"))
    chunks = [chunk async for chunk in stream_of(adapter(FakeClient(stream)))]
    assert chunks[0] == "partial"
    assert "[stream_error]" in chunks[-1] and "provider sent nothing" in chunks[-1]
    assert stream.closed.is_set()
    assert await wait_until(lambda: not workers())


async def test_upstream_error_is_reported_and_cleaned_up():
    stream = FakeStream()
    stream.feed(delta("a"), BOOM)
    sink = {}
    chunks = [chunk async for chunk in stream_of(adapter(FakeClient(stream)), sink)]
    assert chunks[0] == "a" and "[stream_error]" in chunks[-1]
    assert sink == {}
    assert stream.closed.is_set()
    assert await wait_until(lambda: not workers())


async def test_nothing_is_read_or_queued_after_cancel_even_if_close_does_not_unblock():
    stream = FakeStream(unblock_on_close=False)
    stream.feed(delta("first"))
    gen = stream_of(adapter(FakeClient(stream)))
    assert await gen.__anext__() == "first"
    await gen.aclose()
    assert stream.closed.is_set()
    # The provider keeps sending after the close; the worker reads at most the event it was blocked on.
    stream.feed(*[delta("late") for _ in range(50)])
    assert await wait_until(lambda: not workers())
    assert stream.pulled <= 2


async def test_cancel_while_create_is_pending_closes_the_stream_when_it_arrives(monkeypatch):
    monkeypatch.setattr(settings, "PROVIDER_STREAM_IDLE_TIMEOUT_SECONDS", 0.2)
    gate = threading.Event()
    stream = FakeStream()
    chunks = [chunk async for chunk in stream_of(adapter(FakeClient(stream, create_gate=gate)))]
    assert "[stream_error]" in chunks[-1]
    gate.set()
    assert await wait_until(lambda: not workers())
    assert stream.closed.is_set() and stream.pulled == 0
