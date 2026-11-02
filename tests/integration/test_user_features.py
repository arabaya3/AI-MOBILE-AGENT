"""Phase 4 user-facing contracts: requests, conversation actions, notifications, preferences."""

import asyncio

import pytest
from sqlalchemy import select

from src.services.databases.postgresql.models import (
    ChatSession,
    ChatShare,
    GenerationAttempt,
    LLMUsageEvent,
    Notification,
    SpaceMember,
)

from tests.conftest import auth_headers
from tests.integration.test_chat_stream import parse_sse


@pytest.fixture
async def world(factory):
    alice = await factory.user("alice@example.com")
    bob = await factory.user("bob@example.com")
    admin = await factory.user("admin@example.com")
    team = await factory.space("Team")
    other = await factory.space("Other")
    await factory.member(team, alice)
    await factory.member(team, bob)
    await factory.member(team, admin, role="admin")
    await factory.member(other, alice)
    return {"alice": alice, "bob": bob, "admin": admin, "team": team, "other": other}


def requests_url(space):
    return f"/api/v1/spaces/{space.id}/requests"


async def submit(client, user, space, type_, payload=None):
    return await client.post(requests_url(space), json={"type": type_, "payload": payload or {}}, headers=auth_headers(user, space))


# --- Requests -----------------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("type_", "payload", "status"),
    [
        ("model_access", {}, 422),
        ("model_access", {"model": "x" * 101}, 422),
        ("tool_access", {"tool": "rm -rf"}, 422),
        ("quota_change", {}, 422),
        ("quota_change", {"daily_token_limit": -5}, 422),
        ("quota_change", {"daily_token_limit": True}, 422),
        ("other", {}, 422),
        ("other", {"reason": "x" * 501}, 422),
        ("bogus", {}, 400),
    ],
)
async def test_request_forms_accept_only_the_real_contract(client, world, type_, payload, status):
    assert (await submit(client, world["alice"], world["team"], type_, payload)).status_code == status


async def test_quota_requests_cannot_smuggle_model_access(client, world, session_factory):
    response = await submit(
        client, world["alice"], world["team"], "quota_change",
        {"daily_token_limit": 9000, "allowed_models": ["gpt-everything"], "role": "admin"},
    )
    assert response.status_code == 201
    assert response.json()["payload"] == {"daily_token_limit": 9000}
    approved = await client.post(
        f"{requests_url(world['team'])}/{response.json()['id']}/review",
        json={"decision": "approved"},
        headers=auth_headers(world["admin"], world["team"]),
    )
    assert approved.status_code == 200
    async with session_factory() as db:
        member = (await db.execute(select(SpaceMember).where(SpaceMember.user_id == world["alice"].id, SpaceMember.space_id == world["team"].id))).scalar_one()
    assert member.daily_token_limit == 9000 and not member.allowed_models


async def test_resubmitting_returns_the_pending_request_even_concurrently(client, world):
    responses = await asyncio.gather(*(submit(client, world["alice"], world["team"], "model_access", {"model": "teia-stub-2"}) for _ in range(4)))
    assert all(r.status_code == 201 for r in responses)
    assert len({r.json()["id"] for r in responses}) == 1
    other_model = await submit(client, world["alice"], world["team"], "model_access", {"model": "other-model"})
    assert other_model.json()["id"] != responses[0].json()["id"]


async def test_approved_upload_access_takes_effect_and_is_not_requestable_twice(client, world):
    created = await submit(client, world["alice"], world["team"], "upload_access", {"reason": "Need to share reports"})
    assert created.status_code == 201
    await client.post(
        f"{requests_url(world['team'])}/{created.json()['id']}/review",
        json={"decision": "approved", "note": "OK"},
        headers=auth_headers(world["admin"], world["team"]),
    )
    me = await client.get(f"/api/v1/spaces/{world['team'].id}/me", headers=auth_headers(world["alice"], world["team"]))
    assert me.json()["can_upload_documents"] is True
    assert (await submit(client, world["alice"], world["team"], "upload_access")).status_code == 409


async def test_users_see_only_their_own_requests_and_cannot_review(client, world):
    created = (await submit(client, world["alice"], world["team"], "other", {"reason": "Please add a glossary"})).json()
    mine = (await client.get("/api/v1/spaces/requests/mine", headers=auth_headers(world["alice"]))).json()
    assert [r["id"] for r in mine] == [created["id"]]
    assert (await client.get("/api/v1/spaces/requests/mine", headers=auth_headers(world["bob"]))).json() == []
    assert (await client.get(requests_url(world["team"]), headers=auth_headers(world["bob"], world["team"]))).status_code == 403
    review = await client.post(
        f"{requests_url(world['team'])}/{created['id']}/review",
        json={"decision": "approved"},
        headers=auth_headers(world["bob"], world["team"]),
    )
    assert review.status_code == 403


async def test_review_notification_carries_structured_details(client, world, session_factory):
    created = (await submit(client, world["alice"], world["team"], "model_access", {"model": "teia-stub-2"})).json()
    await client.post(
        f"{requests_url(world['team'])}/{created['id']}/review",
        json={"decision": "declined", "note": "Budget"},
        headers=auth_headers(world["admin"], world["team"]),
    )
    listed = (await client.get("/api/v1/notifications/", headers=auth_headers(world["alice"]))).json()
    assert listed[0]["type"] == "request_declined"
    assert listed[0]["metadata"] == {
        "space_name": "Team", "request_type": "model_access", "request_id": created["id"], "note": "Budget",
    }
    assert (await client.get("/api/v1/notifications/", headers=auth_headers(world["bob"]))).json() == []
    other_read = await client.post(f"/api/v1/notifications/{listed[0]['id']}/read", headers=auth_headers(world["bob"]))
    assert other_read.json() == {"success": False}
    count = (await client.get("/api/v1/notifications/unread-count", headers=auth_headers(world["alice"]))).json()
    assert count == {"count": 1}


# --- Conversation actions -----------------------------------------------------------------------


async def test_rename_is_owner_and_space_scoped(client, world, factory):
    session = await factory.session(world["team"], world["alice"])
    url = f"/api/v1/chat/sessions/{session.id}"
    renamed = await client.patch(url, json={"title": "  Budget   review  "}, headers=auth_headers(world["alice"], world["team"]))
    assert renamed.status_code == 200 and renamed.json()["title"] == "Budget review"
    assert (await client.patch(url, json={"title": "x"}, headers=auth_headers(world["bob"], world["team"]))).status_code == 404
    assert (await client.patch(url, json={"title": "x"}, headers=auth_headers(world["alice"], world["other"]))).status_code == 404
    assert (await client.patch(url, json={"title": ""}, headers=auth_headers(world["alice"], world["team"]))).status_code == 422


async def test_delete_removes_conversation_and_links_but_keeps_accounting(client, world, session_factory):
    events = parse_sse((await client.post("/api/v1/chat/query/stream", json={"message": "hello"}, headers=auth_headers(world["alice"], world["team"]))).text)
    session_id = events[-1][1]["session_id"]
    share = await client.post(f"/api/v1/chat/sessions/{session_id}/share", headers=auth_headers(world["alice"], world["team"]))
    token = share.json()["token"]
    url = f"/api/v1/chat/sessions/{session_id}"
    assert (await client.delete(url, headers=auth_headers(world["bob"], world["team"]))).status_code == 404
    assert (await client.delete(url, headers=auth_headers(world["alice"], world["team"]))).status_code == 204
    assert (await client.get(url, headers=auth_headers(world["alice"], world["team"]))).status_code == 404
    assert (await client.get(f"/api/v1/chat/shared/{token}")).status_code == 404
    async with session_factory() as db:
        assert (await db.execute(select(ChatSession).where(ChatSession.id == session_id))).first() is None
        assert (await db.execute(select(ChatShare).where(ChatShare.session_id == session_id))).first() is None
        usage = (await db.execute(select(LLMUsageEvent).where(LLMUsageEvent.user_id == world["alice"].id))).scalars().all()
        attempts = (await db.execute(select(GenerationAttempt).where(GenerationAttempt.user_id == world["alice"].id))).scalars().all()
    assert len(usage) == 1 and usage[0].session_id is None
    assert len(attempts) == 1 and attempts[0].session_id is None
    overview = (await client.get("/api/v1/chat/usage/overview", headers=auth_headers(world["alice"], world["team"]))).json()
    assert overview["requests"]["total"] == 1


# --- Preferences --------------------------------------------------------------------------------


async def test_preferences_update_only_allowed_fields(client, world):
    headers = auth_headers(world["alice"])
    updated = await client.patch("/api/v1/auth/me", json={"preferred_language": "ar", "industry": " Law "}, headers=headers)
    assert updated.status_code == 200
    assert (updated.json()["preferred_language"], updated.json()["industry"]) == ("ar", "Law")
    assert (await client.patch("/api/v1/auth/me", json={"role": "super_admin"}, headers=headers)).status_code == 422
    assert (await client.patch("/api/v1/auth/me", json={"preferred_language": "fr"}, headers=headers)).status_code == 422
    cleared = await client.patch("/api/v1/auth/me", json={"industry": None}, headers=headers)
    assert cleared.json()["industry"] is None and cleared.json()["preferred_language"] == "ar"
    assert (await client.get("/api/v1/auth/me", headers=headers)).json()["role"] == "viewer"


async def test_notifications_from_other_users_stay_private(client, world, session_factory):
    async with session_factory() as db:
        db.add(Notification(user_id=world["bob"].id, type="policy_updated", title="t", message="m", read=False))
        await db.commit()
    assert (await client.get("/api/v1/notifications/", headers=auth_headers(world["alice"]))).json() == []
    assert (await client.post("/api/v1/notifications/mark-all-read", headers=auth_headers(world["alice"]))).json() == {"count": 0}
