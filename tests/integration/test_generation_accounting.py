"""Generation attempt ledger: completion, failure, unknown usage, duplicate finalization and quotas."""

import pytest
from sqlalchemy import select

from src.modules.apis.v1.chat import accounting
from src.services.databases.postgresql.models import GenerationAttempt, LLMUsageEvent

from tests.conftest import auth_headers
from tests.integration.test_chat_stream import parse_sse

STREAM = "/api/v1/chat/query/stream"


@pytest.fixture
async def world(factory):
    alice = await factory.user("alice@example.com")
    bob = await factory.user("bob@example.com")
    team = await factory.space("Team")
    await factory.member(team, alice)
    await factory.member(team, bob)
    return {"alice": alice, "bob": bob, "team": team}


async def ask(client, user, space, message):
    response = await client.post(STREAM, json={"message": message}, headers=auth_headers(user, space))
    return parse_sse(response.text)


async def rows(session_factory, model, **filters):
    async with session_factory() as db:
        stmt = select(model)
        for key, value in filters.items():
            stmt = stmt.where(getattr(model, key) == value)
        return list((await db.execute(stmt)).scalars().all())


async def test_completed_generation_records_attempt_and_usage_once(client, world, session_factory):
    events = await ask(client, world["alice"], world["team"], "hello")
    assert events[-1][0] == "done"
    [attempt] = await rows(session_factory, GenerationAttempt, user_id=world["alice"].id)
    assert (attempt.outcome, attempt.usage_state) == ("completed", "reported")
    assert attempt.total_tokens and attempt.usage_event_id
    [event] = await rows(session_factory, LLMUsageEvent, user_id=world["alice"].id)
    assert event.id == attempt.usage_event_id and event.total_tokens == attempt.total_tokens


async def test_missing_provider_usage_is_unknown_not_zero(client, world, session_factory):
    events = await ask(client, world["alice"], world["team"], "hello [[no-usage]]")
    assert events[-1][0] == "done"
    [attempt] = await rows(session_factory, GenerationAttempt, user_id=world["alice"].id)
    assert (attempt.outcome, attempt.usage_state, attempt.total_tokens) == ("completed", "unknown", None)
    assert await rows(session_factory, LLMUsageEvent, user_id=world["alice"].id) == []

    overview = (await client.get("/api/v1/chat/usage/overview?days=1", headers=auth_headers(world["alice"], world["team"]))).json()
    assert overview["requests"] == {
        "total": 1,
        "with_reported_usage": 0,
        "with_unknown_usage": 1,
        "unknown_breakdown": {"completed": 1},
    }
    assert overview["cost"]["amount"] is None and overview["cost"]["complete"] is False
    assert overview["tokens"]["total"] == 0


async def test_provider_failure_is_finalized_as_failed(client, world, session_factory):
    events = await ask(client, world["alice"], world["team"], "[[fail-after]] x")
    assert events[-1][1]["code"] == "provider_error"
    [attempt] = await rows(session_factory, GenerationAttempt, user_id=world["alice"].id)
    assert attempt.outcome == "failed" and attempt.error_code == "provider_error"


async def test_unexpected_failure_after_start_is_finalized(client, world, session_factory):
    events = await ask(client, world["alice"], world["team"], "[[raise]]")
    assert events[-1][1]["code"] == "internal"
    [attempt] = await rows(session_factory, GenerationAttempt, user_id=world["alice"].id)
    assert attempt.outcome == "failed" and attempt.usage_state == "unknown"


async def test_finalization_happens_once(world, session_factory):
    async with session_factory() as db:
        attempt_id = await accounting.start(
            db, space_id=world["team"].id, user_id=world["alice"].id, session_id=None,
            user_message_id=None, endpoint="test", model="teia-stub-1",
        )
    kwargs = dict(model="teia-stub-1", space_id=world["team"].id, user_id=world["alice"].id, session_id=None, endpoint="test")
    usage = {"input_tokens": 3, "output_tokens": 4, "total_tokens": 7}
    async with session_factory() as first, session_factory() as second:
        assert await accounting.finalize(first, attempt_id, outcome="completed", usage=usage, **kwargs) is True
        await first.commit()
        assert await accounting.finalize(second, attempt_id, outcome="cancelled", usage=usage, **kwargs) is False
        await second.commit()
    [attempt] = await rows(session_factory, GenerationAttempt, id=attempt_id)
    assert attempt.outcome == "completed"
    assert len(await rows(session_factory, LLMUsageEvent, user_id=world["alice"].id)) == 1


async def test_unknown_usage_counts_against_token_quota(client, world, session_factory, factory, monkeypatch):
    from src.core.settings.config import settings

    monkeypatch.setattr(settings, "QUOTA_UNKNOWN_USAGE_TOKENS", 4000)
    await factory.execute("UPDATE space_members SET daily_token_limit = 5000 WHERE user_id = :u", u=world["alice"].id)
    first = await ask(client, world["alice"], world["team"], "one [[no-usage]]")
    assert first[-1][0] == "done"
    second = await ask(client, world["alice"], world["team"], "two [[no-usage]]")
    assert second[-1][0] == "done"
    third = await ask(client, world["alice"], world["team"], "three")
    assert third[-1] == ("error", {"detail": "Daily token limit reached", "code": "quota_exceeded"})

    overview = (await client.get("/api/v1/chat/usage/overview?days=1", headers=auth_headers(world["alice"], world["team"]))).json()
    daily = next(limit for limit in overview["limits"] if limit["key"] == "daily_tokens")
    assert daily == {
        "key": "daily_tokens", "unit": "tokens", "window_hours": 24, "limit": 5000,
        "used": 8000, "remaining": 0, "reserved_for_unknown": 8000,
    }


async def test_non_streaming_answers_are_accounted(client, world, session_factory):
    response = await client.post("/api/v1/chat/query", json={"message": "hi"}, headers=auth_headers(world["alice"], world["team"]))
    assert response.status_code == 200
    [attempt] = await rows(session_factory, GenerationAttempt, user_id=world["alice"].id)
    assert (attempt.endpoint, attempt.outcome, attempt.usage_state) == ("chat.query", "completed", "reported")


async def test_usage_overview_is_private_and_validated(client, world, factory):
    await ask(client, world["alice"], world["team"], "hello")
    bob = (await client.get("/api/v1/chat/usage/overview", headers=auth_headers(world["bob"], world["team"]))).json()
    assert bob["requests"]["total"] == 0 and bob["cost"]["amount"] is None
    outsider = await factory.user("out@example.com")
    assert (await client.get("/api/v1/chat/usage/overview", headers=auth_headers(outsider, world["team"]))).status_code in (403, 404)
    assert (await client.get("/api/v1/chat/usage/overview?days=0", headers=auth_headers(world["alice"], world["team"]))).status_code == 422
    alice = (await client.get("/api/v1/chat/usage/overview?days=7", headers=auth_headers(world["alice"], world["team"]))).json()
    assert alice["window"]["days"] == 7 and alice["window"]["timezone"] == "UTC" and alice["window"]["kind"] == "rolling"
    assert alice["cost"]["basis"] == "estimated"
    unlimited = next(limit for limit in alice["limits"] if limit["key"] == "monthly_conversations")
    assert unlimited["limit"] is None and unlimited["remaining"] is None and unlimited["used"] == 1


async def test_invoice_pdf_never_shows_unknown_cost_as_zero(client, world):
    await ask(client, world["alice"], world["team"], "hello [[no-usage]]")
    response = await client.get("/api/v1/chat/usage/invoice/pdf?days=1", headers=auth_headers(world["alice"], world["team"]))
    assert response.status_code == 200 and response.headers["content-type"].startswith("application/pdf")
    from io import BytesIO

    import fitz

    text = "".join(page.get_text() for page in fitz.open(stream=BytesIO(response.content).read(), filetype="pdf"))
    assert "Unavailable" in text and "$0.0000" not in text
    assert "1 request(s) have no reported usage or price" in text
    other = await client.get("/api/v1/chat/usage/invoice/pdf", headers=auth_headers(world["bob"], world["team"]))
    other_text = "".join(page.get_text() for page in fitz.open(stream=other.content, filetype="pdf"))
    assert "Requests" in other_text and "1 request(s)" not in other_text
