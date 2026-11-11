"""Space administration: boundaries, last-admin rule, limits and overrides, catalog, request review."""

import asyncio

import pytest
from sqlalchemy import select

from src.services.databases.postgresql.models import Notification, SpaceMember, SpaceRequest

from tests.conftest import auth_headers

SPACES = "/api/v1/spaces"


@pytest.fixture(autouse=True)
def registered_tools(monkeypatch):
    from src.services.tools.base import ToolDefinition
    from src.services.tools.registry import tool_registry

    class Tool:
        def __init__(self, name):
            self.definition = ToolDefinition(name=name, description="test", parameters=[])

    monkeypatch.setattr(tool_registry, "_tools", {n: Tool(n) for n in ("calculator", "web_search_tavily")})


@pytest.fixture
async def world(factory):
    ann = await factory.user("ann@example.com")
    ben = await factory.user("ben@example.com")
    mia = await factory.user("mia@example.com")
    out = await factory.user("out@example.com")
    team = await factory.space("Team")
    other = await factory.space("Other")
    await factory.member(team, ann, role="admin")
    await factory.member(team, mia)
    await factory.member(other, ben, role="admin")
    return {"ann": ann, "ben": ben, "mia": mia, "out": out, "team": team, "other": other}


def member_url(world, user, space="team"):
    return f"{SPACES}/{world[space].id}/members/{world[user].id}"


async def test_admin_operations_reject_members_outsiders_and_other_admins(client, world):
    team = world["team"].id
    calls = [
        ("get", f"{SPACES}/{team}/members", None),
        ("patch", member_url(world, "mia"), {"role": "admin"}),
        ("patch", f"{SPACES}/{team}/policy", {"daily_token_limit": 5000}),
        ("patch", f"{SPACES}/{team}", {"name": "Hijacked"}),
        ("get", f"{SPACES}/{team}/requests", None),
        ("get", f"{SPACES}/{team}/usage", None),
        ("get", f"{SPACES}/{team}/invites", None),
    ]
    for user in ("mia", "out", "ben"):
        for method, url, body in calls:
            kwargs = {"json": body} if body is not None else {}
            response = await getattr(client, method)(url, headers=auth_headers(world[user]), **kwargs)
            assert response.status_code == 403, (user, method, url)
    for method, url, body in calls:
        kwargs = {"json": body} if body is not None else {}
        response = await getattr(client, method)(url, headers=auth_headers(world["ann"]), **kwargs)
        assert response.status_code == 200, (method, url, response.text)


async def test_the_last_active_admin_cannot_be_demoted_or_revoked(client, world):
    headers = auth_headers(world["ann"])
    for body in ({"role": "member"}, {"status": "revoked"}):
        response = await client.patch(member_url(world, "ann"), json=body, headers=headers)
        assert response.status_code == 409 and "at least one active admin" in response.json()["detail"]
    assert (await client.patch(member_url(world, "mia"), json={"role": "admin"}, headers=headers)).status_code == 200
    assert (await client.patch(member_url(world, "ann"), json={"role": "member"}, headers=headers)).status_code == 200
    # Ann is no longer an admin; her session can no longer administer the space.
    assert (await client.get(f"{SPACES}/{world['team'].id}/members", headers=headers)).status_code == 403


async def test_concurrent_mutual_demotion_leaves_one_admin(client, world, session_factory):
    await client.patch(member_url(world, "mia"), json={"role": "admin"}, headers=auth_headers(world["ann"]))
    results = await asyncio.gather(
        client.patch(member_url(world, "mia"), json={"role": "member"}, headers=auth_headers(world["ann"])),
        client.patch(member_url(world, "ann"), json={"status": "revoked"}, headers=auth_headers(world["mia"])),
    )
    codes = sorted(r.status_code for r in results)
    assert codes in ([200, 403], [200, 409])
    async with session_factory() as db:
        admins = (
            await db.execute(
                select(SpaceMember).where(SpaceMember.space_id == world["team"].id, SpaceMember.role == "admin", SpaceMember.status == "active")
            )
        ).scalars().all()
    assert len(admins) == 1


async def test_policy_limits_distinguish_unlimited_zero_and_values(client, world):
    url = f"{SPACES}/{world['team'].id}/policy"
    headers = auth_headers(world["ann"])
    set_ = await client.patch(url, json={"daily_token_limit": 5000, "monthly_token_limit": 0}, headers=headers)
    assert set_.status_code == 422  # daily may not exceed monthly (0 = blocked)
    ok = await client.patch(url, json={"daily_token_limit": 0, "monthly_token_limit": 20000}, headers=headers)
    assert ok.json()["policy"]["daily_token_limit"] == 0 and ok.json()["policy"]["monthly_token_limit"] == 20000
    untouched = await client.patch(url, json={"daily_request_limit": 5}, headers=headers)
    assert untouched.json()["policy"]["monthly_token_limit"] == 20000
    cleared = await client.patch(url, json={"monthly_token_limit": None}, headers=headers)
    assert cleared.json()["policy"]["monthly_token_limit"] is None and cleared.json()["policy"]["daily_token_limit"] == 0
    for bad in (
        {"daily_request_limit": -1},
        {"daily_request_limit": "5"},
        {"daily_request_limit": True},
        {"daily_request_limit": 2_000_000_000},
        {"daily_token_limit": 50},
        {"monthly_request_limit": 4},  # below the stored daily limit of 5
    ):
        assert (await client.patch(url, json=bad, headers=headers)).status_code == 422, bad


async def test_member_overrides_inherit_or_set_explicit_values(client, world, factory):
    headers = auth_headers(world["ann"])
    await client.patch(f"{SPACES}/{world['team'].id}/policy", json={"daily_request_limit": 10}, headers=headers)
    url = member_url(world, "mia")
    explicit = await client.patch(url, json={"overrides": {"daily_request_limit": 0}}, headers=headers)
    assert explicit.json()["overrides"]["daily_request_limit"] == 0
    events = (await client.post("/api/v1/chat/query/stream", json={"message": "hi"}, headers=auth_headers(world["mia"], world["team"]))).text
    assert "Daily conversation limit reached" in events
    inherit = await client.patch(url, json={"overrides": {"daily_request_limit": None}}, headers=headers)
    assert inherit.json()["overrides"]["daily_request_limit"] is None
    events = (await client.post("/api/v1/chat/query/stream", json={"message": "hi"}, headers=auth_headers(world["mia"], world["team"]))).text
    assert "event: done" in events
    assert (await client.patch(url, json={"overrides": {"monthly_token_limit": -3}}, headers=headers)).status_code == 422


async def test_models_and_tools_must_come_from_the_catalog(client, world, factory):
    catalog = (await client.get(f"{SPACES}/{world['team'].id}/catalog", headers=auth_headers(world["mia"]))).json()
    model_ids = [m["id"] for m in catalog["models"]]
    tool_ids = [t["id"] for t in catalog["tools"]]
    assert "teia-stub-1" in model_ids and tool_ids
    assert set(catalog) == {"models", "tools"} and all(set(item) == {"id"} for item in catalog["models"] + catalog["tools"])
    assert (await client.get(f"{SPACES}/{world['team'].id}/catalog", headers=auth_headers(world["out"]))).status_code == 403

    url = f"{SPACES}/{world['team'].id}/policy"
    headers = auth_headers(world["ann"])
    assert (await client.patch(url, json={"allowed_models": ["teia-stub-1", "gpt-made-up"]}, headers=headers)).status_code == 422
    assert (await client.patch(url, json={"allowed_tools": ["rm_rf"]}, headers=headers)).status_code == 422
    ok = await client.patch(url, json={"allowed_models": ["teia-stub-1"], "allowed_tools": tool_ids[:1]}, headers=headers)
    assert ok.status_code == 200 and ok.json()["policy"]["allowed_models"] == ["teia-stub-1"]
    # Identifiers already stored stay valid, so a legacy policy can still be saved unchanged.
    await factory.execute("UPDATE spaces SET allowed_models = '[\"legacy-model\"]' WHERE id = :s", s=world["team"].id)
    assert (await client.patch(url, json={"allowed_models": ["legacy-model", "teia-stub-2"]}, headers=headers)).status_code == 200
    bad_override = await client.patch(member_url(world, "mia"), json={"overrides": {"allowed_tools": ["shell"]}}, headers=headers)
    assert bad_override.status_code == 422


async def request(client, world, user, type_, payload):
    response = await client.post(f"{SPACES}/{world['team'].id}/requests", json={"type": type_, "payload": payload}, headers=auth_headers(world[user]))
    assert response.status_code == 201, response.text
    return response.json()


def review_url(world, req):
    return f"{SPACES}/{world['team'].id}/requests/{req['id']}/review"


async def test_concurrent_reviews_apply_once_with_one_notification(client, world, session_factory):
    req = await request(client, world, "mia", "upload_access", {})
    headers = auth_headers(world["ann"])
    results = await asyncio.gather(
        client.post(review_url(world, req), json={"decision": "approved", "note": "ok"}, headers=headers),
        client.post(review_url(world, req), json={"decision": "declined", "note": "no"}, headers=headers),
        client.post(review_url(world, req), json={"decision": "approved"}, headers=headers),
    )
    assert sorted(r.status_code for r in results) == [200, 409, 409]
    winner = next(r.json() for r in results if r.status_code == 200)
    async with session_factory() as db:
        stored = await db.get(SpaceRequest, req["id"])
        notes = (await db.execute(select(Notification).where(Notification.user_id == world["mia"].id))).scalars().all()
        member = (await db.execute(select(SpaceMember).where(SpaceMember.user_id == world["mia"].id))).scalars().one()
    assert stored.status == winner["status"] and stored.reviewed_by_user_id == world["ann"].id
    assert len(notes) == 1
    assert member.can_upload_documents is (winner["status"] == "approved")


async def test_reviewers_cannot_review_their_own_requests(client, world, factory):
    await factory.member(world["team"], world["ben"], role="admin")
    req = await request(client, world, "ben", "other", {"reason": "please"})
    assert (await client.post(review_url(world, req), json={"decision": "approved"}, headers=auth_headers(world["ben"]))).status_code == 403
    assert (await client.post(review_url(world, req), json={"decision": "approved"}, headers=auth_headers(world["ann"]))).status_code == 200


async def test_approvals_change_only_their_own_field(client, world, factory, session_factory):
    headers = auth_headers(world["ann"])
    # A legacy quota_change row carrying model access must not grant models when approved.
    await factory.execute(
        "INSERT INTO space_requests (id, space_id, user_id, type, payload, status, created_at) VALUES "
        "('legacy', :s, :u, 'quota_change', '{\"daily_token_limit\": 5000, \"allowed_models\": [\"gpt-everything\"], \"role\": \"admin\"}', 'pending', now())",
        s=world["team"].id, u=world["mia"].id,
    )
    assert (await client.post(f"{SPACES}/{world['team'].id}/requests/legacy/review", json={"decision": "approved"}, headers=headers)).status_code == 200
    async with session_factory() as db:
        member = (await db.execute(select(SpaceMember).where(SpaceMember.user_id == world["mia"].id))).scalars().one()
    assert member.daily_token_limit == 5000 and not member.allowed_models and member.role == "member"

    model = await request(client, world, "mia", "model_access", {"model": "teia-stub-2"})
    assert (await client.post(review_url(world, model), json={"decision": "approved"}, headers=headers)).status_code == 200
    unknown = await request(client, world, "mia", "model_access", {"model": "gpt-made-up"})
    assert (await client.post(review_url(world, unknown), json={"decision": "approved"}, headers=headers)).status_code == 422
    assert (await client.post(review_url(world, unknown), json={"decision": "declined"}, headers=headers)).status_code == 200
    models = (await client.get("/api/v1/chat/models", headers=auth_headers(world["mia"], world["team"]))).json()
    assert "teia-stub-2" in models


async def test_tool_access_requests_use_the_catalog(client, world):
    tools = [t["id"] for t in (await client.get(f"{SPACES}/{world['team'].id}/catalog", headers=auth_headers(world["mia"]))).json()["tools"]]
    await client.patch(f"{SPACES}/{world['team'].id}/policy", json={"allowed_tools": []}, headers=auth_headers(world["ann"]))
    req = await request(client, world, "mia", "tool_access", {"tool": tools[0]})
    assert (await client.post(review_url(world, req), json={"decision": "approved"}, headers=auth_headers(world["ann"]))).status_code == 200
    members = (await client.get(f"{SPACES}/{world['team'].id}/members", headers=auth_headers(world["ann"]))).json()
    assert tools[0] in next(m for m in members if m["email"] == "mia@example.com")["overrides"]["allowed_tools"]


async def test_requests_list_shows_requester_and_is_space_scoped(client, world):
    await request(client, world, "mia", "upload_access", {})
    listed = (await client.get(f"{SPACES}/{world['team'].id}/requests", headers=auth_headers(world["ann"]))).json()
    assert listed[0]["user_email"] == "mia@example.com"
    assert (await client.get(f"{SPACES}/{world['other'].id}/requests", headers=auth_headers(world["ann"]))).status_code == 403
