"""Conversation limits count conversations started, from a ledger that deleting conversations does not touch."""

import asyncio

import pytest
from sqlalchemy import select

from src.services.databases.postgresql.models import ChatMessage, ConversationCreation

from tests.conftest import auth_headers
from tests.integration.test_chat_stream import parse_sse

STREAM = "/api/v1/chat/query/stream"
DAILY = ("error", {"detail": "Daily conversation limit reached", "code": "quota_exceeded"})
MONTHLY = ("error", {"detail": "Monthly conversation limit reached", "code": "quota_exceeded"})


@pytest.fixture
async def world(factory):
    alice = await factory.user("alice@example.com")
    bob = await factory.user("bob@example.com")
    team = await factory.space("Team")
    other = await factory.space("Other")
    for space in (team, other):
        await factory.member(space, alice)
        await factory.member(space, bob)
    return {"alice": alice, "bob": bob, "team": team, "other": other}


async def limit(factory, space, column, value):
    await factory.execute(f"UPDATE spaces SET {column} = :v WHERE id = :s", v=value, s=space.id)


async def ask(client, user, space, message="hello", session_id=None):
    body = {"message": message}
    if session_id:
        body["session_id"] = session_id
    return parse_sse((await client.post(STREAM, json=body, headers=auth_headers(user, space))).text)


async def start(client, user, space):
    events = await ask(client, user, space)
    assert events[-1][0] == "done", events[-1]
    return events[-1][1]["session_id"]


async def delete(client, user, space, session_id):
    response = await client.delete(f"/api/v1/chat/sessions/{session_id}", headers=auth_headers(user, space))
    assert response.status_code == 204


async def ledger(session_factory, user):
    async with session_factory() as db:
        return list((await db.execute(select(ConversationCreation).where(ConversationCreation.user_id == user.id))).scalars())


async def conversations_limit(client, user, space, key):
    overview = (await client.get("/api/v1/chat/usage/overview", headers=auth_headers(user, space))).json()
    return next(row for row in overview["limits"] if row["key"] == key)


@pytest.mark.parametrize(("column", "rejection", "key"), [("daily_request_limit", DAILY, "daily_conversations"), ("monthly_request_limit", MONTHLY, "monthly_conversations")])
async def test_deleting_a_conversation_does_not_restore_quota(client, world, factory, session_factory, column, rejection, key):
    await limit(factory, world["team"], column, 1)
    first = await start(client, world["alice"], world["team"])
    await delete(client, world["alice"], world["team"], first)
    assert await ask(client, world["alice"], world["team"]) == [rejection]
    [row] = await ledger(session_factory, world["alice"])
    assert row.kind == "new" and row.session_id is None  # kept, detached from the deleted conversation
    assert await conversations_limit(client, world["alice"], world["team"], key) == {
        "key": key, "unit": "conversations", "window_hours": 24 if key.startswith("daily") else 720,
        "limit": 1, "used": 1, "remaining": 0, "reserved_for_unknown": 0,
    }


async def test_monthly_window_counts_older_starts_that_the_daily_window_does_not(client, world, factory):
    await limit(factory, world["team"], "daily_request_limit", 1)
    await limit(factory, world["team"], "monthly_request_limit", 2)
    for days in (10, 40):
        await factory.execute(
            "INSERT INTO conversation_creations (id, space_id, user_id, kind, created_at) "
            "VALUES (:id, :s, :u, 'new', now() at time zone 'utc' - make_interval(days => :d))",
            id=f"old-{days}", s=world["team"].id, u=world["alice"].id, d=days,
        )
    await start(client, world["alice"], world["team"])  # 40-day-old start is outside both windows
    assert await ask(client, world["alice"], world["team"]) == [DAILY]
    await limit(factory, world["team"], "daily_request_limit", None)
    assert await ask(client, world["alice"], world["team"]) == [MONTHLY]  # 10-day-old start + today's

async def test_continuing_a_conversation_does_not_consume_a_start(client, world, factory, session_factory):
    await limit(factory, world["team"], "daily_request_limit", 1)
    session_id = await start(client, world["alice"], world["team"])
    for _ in range(3):
        events = await ask(client, world["alice"], world["team"], "more", session_id=session_id)
        assert events[-1][0] == "done"
    assert len(await ledger(session_factory, world["alice"])) == 1
    assert await ask(client, world["alice"], world["team"]) == [DAILY]


async def test_branching_starts_a_conversation_and_is_limited_like_one(client, world, factory, session_factory):
    session_id = await start(client, world["alice"], world["team"])
    async with session_factory() as db:
        message_id = (await db.execute(select(ChatMessage.id).where(ChatMessage.session_id == session_id).limit(1))).scalar_one()
    url = f"/api/v1/chat/sessions/{session_id}/branch"
    headers = auth_headers(world["alice"], world["team"])

    await limit(factory, world["team"], "daily_request_limit", 2)
    branched = await client.post(url, json={"from_message_id": message_id}, headers=headers)
    assert branched.status_code == 200
    kinds = sorted(row.kind for row in await ledger(session_factory, world["alice"]))
    assert kinds == ["branch", "new"]

    rejected = await client.post(url, json={"from_message_id": message_id}, headers=headers)
    assert rejected.status_code == 429 and rejected.json()["detail"] == "Daily conversation limit reached"
    await delete(client, world["alice"], world["team"], branched.json()["session_id"])
    assert (await client.post(url, json={"from_message_id": message_id}, headers=headers)).status_code == 429
    assert await ask(client, world["alice"], world["team"]) == [DAILY]


async def test_concurrent_starts_at_the_boundary_admit_exactly_one(client, world, factory, session_factory):
    await limit(factory, world["team"], "daily_request_limit", 1)
    results = await asyncio.gather(*(ask(client, world["alice"], world["team"], f"race {i}") for i in range(4)))
    finals = [events[-1] for events in results]
    assert sum(1 for event in finals if event[0] == "done") == 1
    assert [event for event in finals if event[0] != "done"] == [DAILY] * 3
    assert len(await ledger(session_factory, world["alice"])) == 1


async def test_counts_are_isolated_by_user_and_space(client, world, factory, session_factory):
    await limit(factory, world["team"], "daily_request_limit", 1)
    await limit(factory, world["other"], "daily_request_limit", 1)
    first = await start(client, world["alice"], world["team"])
    await delete(client, world["alice"], world["team"], first)
    assert await ask(client, world["alice"], world["team"]) == [DAILY]
    await start(client, world["bob"], world["team"])
    await start(client, world["alice"], world["other"])
    assert (await conversations_limit(client, world["bob"], world["team"], "daily_conversations"))["used"] == 1
    assert (await conversations_limit(client, world["alice"], world["other"], "daily_conversations"))["used"] == 1
