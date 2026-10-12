"""Chat streaming over the real routes, persistence and usage paths, with the local stub provider."""

import json
from datetime import datetime

import pytest

from src.core.settings.config import settings
from src.services.llm_providers import provider

from tests.conftest import auth_headers

STREAM = "/api/v1/chat/query/stream"


def parse_sse(text: str) -> list[tuple[str, dict]]:
    events = []
    for frame in text.split("\n\n"):
        lines = [line for line in frame.splitlines() if line]
        if not lines:
            continue
        name = next(line[7:] for line in lines if line.startswith("event: "))
        data = "\n".join(line[6:] for line in lines if line.startswith("data: "))
        events.append((name, json.loads(data)))
    return events


@pytest.fixture
async def world(factory):
    alice = await factory.user("alice@example.com")
    bob = await factory.user("bob@example.com")
    team = await factory.space("Team")
    other = await factory.space("Other")
    await factory.member(team, alice)
    await factory.member(team, bob)
    await factory.member(other, alice)
    return {"alice": alice, "bob": bob, "team": team, "other": other}


async def stream(client, user, space, message, **extra):
    response = await client.post(STREAM, json={"message": message, **extra}, headers=auth_headers(user, space))
    return response, parse_sse(response.text)


async def history(client, user, space, session_id):
    response = await client.get(f"/api/v1/chat/sessions/{session_id}", headers=auth_headers(user, space))
    return response.status_code, response.json().get("history", [])


async def test_normal_stream_persists_and_reports_authoritative_ids(client, world, factory):
    response, events = await stream(client, world["alice"], world["team"], "hello مرحبا")
    assert response.status_code == 200
    names = [name for name, _ in events]
    assert names[0] == "meta" and names[-1] == "done" and "delta" in names
    meta, done = events[0][1], events[-1][1]
    assert done["session_id"] == meta["session_id"]
    text = "".join(data["text"] for name, data in events if name == "delta")
    assert text == "Echo: hello مرحبا"

    status, msgs = await history(client, world["alice"], world["team"], meta["session_id"])
    assert status == 200
    assert [(m["id"], m["role"]) for m in msgs] == [(done["user_message_id"], "user"), (done["message_id"], "assistant")]
    assert msgs[1]["content"] == text
    usage = (await factory.execute("SELECT count(*), sum(total_tokens) FROM llm_usage_events")).one()
    assert usage[0] == 1 and usage[1] > 0


async def test_provider_failure_before_output_is_a_typed_error_and_not_stored(client, world, factory):
    _, events = await stream(client, world["alice"], world["team"], "[[fail-before]] hi")
    assert [name for name, _ in events] == ["meta", "error"]
    error = events[-1][1]
    assert error["code"] == "provider_error" and error["partial"] is False
    _, msgs = await history(client, world["alice"], world["team"], events[0][1]["session_id"])
    assert [m["role"] for m in msgs] == ["user"]
    assert "[stream_error]" not in json.dumps(events)
    flagged = (await factory.execute("SELECT count(*) FROM llm_usage_events")).scalar_one()
    assert flagged == 1


async def test_provider_failure_after_partial_output_never_streams_the_marker(client, world):
    _, events = await stream(client, world["alice"], world["team"], "[[fail-after]] partial please")
    names = [name for name, _ in events]
    assert names[0] == "meta" and names[-1] == "error" and names.count("delta") >= 1
    assert events[-1][1]["partial"] is True
    assert all("[stream_error]" not in data.get("text", "") for _, data in events)
    _, msgs = await history(client, world["alice"], world["team"], events[0][1]["session_id"])
    assert [m["role"] for m in msgs] == ["user"]


async def test_unexpected_server_failure_does_not_leak_internals(client, world):
    response, events = await stream(client, world["alice"], world["team"], "[[raise]]")
    assert events[-1] == ("error", {"detail": "The reply could not be completed.", "code": "internal"})
    assert "stub provider crashed" not in response.text


async def test_policy_rejection_is_typed(client, world, factory):
    await factory.execute(
        "UPDATE spaces SET allowed_models = CAST(:m AS JSON) WHERE id = :s", m='["teia-stub-2"]', s=world["team"].id
    )
    _, events = await stream(client, world["alice"], world["team"], "hi", model="teia-stub-1")
    assert events == [("error", {"detail": "Model not allowed in this space", "code": "policy"})]
    _, ok = await stream(client, world["alice"], world["team"], "hi", model="teia-stub-2")
    assert ok[-1][0] == "done"


async def test_quota_rejection_is_typed_without_status_prefix(client, world, factory):
    await factory.execute("UPDATE spaces SET daily_token_limit = 10 WHERE id = :s", s=world["team"].id)
    await factory.execute(
        "INSERT INTO llm_usage_events (id, space_id, user_id, endpoint, model, request_count, input_tokens, "
        "output_tokens, total_tokens, created_at) VALUES ('u1', :s, :u, 'chat.query.stream', 'teia-stub-1', 1, 5, 20, 25, :t)",
        s=world["team"].id,
        u=world["alice"].id,
        t=datetime.utcnow(),
    )
    response, events = await stream(client, world["alice"], world["team"], "hi")
    assert response.status_code == 200
    assert events == [("error", {"detail": "Daily token limit reached", "code": "quota_exceeded"})]


async def test_http_errors_happen_before_streaming(client, world):
    assert (await client.post(STREAM, json={"message": "hi"})).status_code == 401
    outsider = await client.post(STREAM, json={"message": "hi"}, headers=auth_headers(world["bob"], world["other"]))
    assert outsider.status_code in (403, 404)
    assert (await client.post(STREAM, json={"message": ""}, headers=auth_headers(world["alice"], world["team"]))).status_code == 422


async def test_reactions_and_branching_work_immediately_after_done(client, world):
    _, events = await stream(client, world["alice"], world["team"], "first")
    done = events[-1][1]
    headers = auth_headers(world["alice"], world["team"])
    reaction = await client.post(f"/api/v1/chat/messages/{done['message_id']}/reaction", json={"reaction": "up"}, headers=headers)
    assert reaction.status_code == 200
    branch = await client.post(
        f"/api/v1/chat/sessions/{done['session_id']}/branch", json={"from_message_id": done["message_id"]}, headers=headers
    )
    assert branch.status_code == 200
    _, branched = await history(client, world["alice"], world["team"], branch.json()["session_id"])
    assert [m["role"] for m in branched] == ["user", "assistant"]


async def test_export_and_summary(client, world):
    _, events = await stream(client, world["alice"], world["team"], "export me")
    sid = events[-1][1]["session_id"]
    headers = auth_headers(world["alice"], world["team"])
    export = await client.get(f"/api/v1/chat/sessions/{sid}/export?format=md", headers=headers)
    assert export.status_code == 200 and "Echo: export me" in export.text
    summary = await client.get(f"/api/v1/chat/sessions/{sid}/summary", headers=headers)
    assert summary.status_code == 200 and "Overview" in summary.json()["summary"]


async def test_other_users_and_spaces_cannot_touch_a_conversation(client, world):
    _, events = await stream(client, world["alice"], world["team"], "private")
    done = events[-1][1]
    sid, mid = done["session_id"], done["message_id"]
    bob = auth_headers(world["bob"], world["team"])
    alice_other_space = auth_headers(world["alice"], world["other"])

    for headers in (bob, alice_other_space):
        assert (await client.get(f"/api/v1/chat/sessions/{sid}", headers=headers)).status_code == 404
        assert (await client.get(f"/api/v1/chat/sessions/{sid}/export", headers=headers)).status_code == 404
        assert (await client.get(f"/api/v1/chat/sessions/{sid}/summary", headers=headers)).status_code == 404
        assert (
            await client.post(f"/api/v1/chat/messages/{mid}/reaction", json={"reaction": "down"}, headers=headers)
        ).status_code == 404
        assert (
            await client.post(f"/api/v1/chat/sessions/{sid}/branch", json={"from_message_id": mid}, headers=headers)
        ).status_code == 404
        assert (await client.post(f"/api/v1/chat/sessions/{sid}/share", headers=headers)).status_code == 404
        listed = (await client.get("/api/v1/chat/sessions", headers=headers)).json()
        assert sid not in [s["id"] for s in listed]

    _, hijack_events = await stream(client, world["bob"], world["team"], "x", session_id=sid)
    assert hijack_events[-1][1]["code"] == "session_not_found"
    _, msgs = await history(client, world["alice"], world["team"], sid)
    assert len(msgs) == 2


async def test_model_list_comes_from_policy_or_provider(client, world, factory):
    headers = auth_headers(world["alice"], world["team"])
    assert (await client.get("/api/v1/chat/models", headers=headers)).json() == ["teia-stub-1", "teia-stub-2"]
    await factory.execute(
        "UPDATE spaces SET allowed_models = CAST(:m AS JSON) WHERE id = :s", m='["teia-stub-2"]', s=world["team"].id
    )
    assert (await client.get("/api/v1/chat/models", headers=headers)).json() == ["teia-stub-2"]


def test_stub_provider_is_refused_outside_development_and_test(monkeypatch):
    monkeypatch.setattr(settings, "APP_ENV", "production")
    with pytest.raises(RuntimeError):
        provider.get_chat_provider()
    with pytest.raises(RuntimeError):
        provider.assert_provider_configuration()
    monkeypatch.setattr(settings, "CHAT_PROVIDER_STUB", False)
    assert provider.get_chat_provider() is provider.openai_chat_service
