from datetime import datetime, timedelta

import pytest

from tests.conftest import auth_headers

SPACES = "/api/v1/spaces"


@pytest.fixture
async def world(factory):
    alice = await factory.user("alice@example.com")
    bob = await factory.user("bob@example.com")
    team = await factory.space("Team")
    closed = await factory.space("Closed", active=False)
    open_space = await factory.space("Open")
    await factory.member(team, alice, role="admin")
    await factory.member(closed, alice)
    return {"alice": alice, "bob": bob, "team": team, "closed": closed, "open": open_space}


async def test_lists_only_active_spaces_with_active_membership(client, world, factory):
    names = [s["name"] for s in (await client.get(SPACES, headers=auth_headers(world["alice"]))).json()]
    assert names == ["Team"]
    await factory.execute("UPDATE space_members SET status = 'revoked' WHERE user_id = :u", u=world["alice"].id)
    assert (await client.get(SPACES, headers=auth_headers(world["alice"]))).json() == []


async def test_membership_reports_role_and_rejects_non_members(client, world):
    path = f"{SPACES}/{world['team'].id}/me"
    mine = (await client.get(path, headers=auth_headers(world["alice"]))).json()
    assert mine["role"] == "admin" and mine["status"] == "active"
    assert (await client.get(path, headers=auth_headers(world["bob"]))).status_code == 403


async def test_join_request_is_idempotent_and_visible_to_requester(client, world):
    path = f"{SPACES}/{world['open'].id}/requests"
    first = await client.post(path, json={"type": "join"}, headers=auth_headers(world["bob"]))
    second = await client.post(path, json={"type": "join"}, headers=auth_headers(world["bob"]))
    assert first.status_code == second.status_code == 201
    assert first.json()["id"] == second.json()["id"]

    mine = (await client.get(f"{SPACES}/requests/mine", headers=auth_headers(world["bob"]))).json()
    assert [(r["space_id"], r["status"]) for r in mine] == [(world["open"].id, "pending")]
    assert (await client.get(f"{SPACES}/requests/mine", headers=auth_headers(world["alice"]))).json() == []


async def test_join_request_rejects_missing_inactive_and_existing_membership(client, world):
    bob, alice = auth_headers(world["bob"]), auth_headers(world["alice"])
    assert (await client.post(f"{SPACES}/missing/requests", json={"type": "join"}, headers=bob)).status_code == 404
    closed = f"{SPACES}/{world['closed'].id}/requests"
    assert (await client.post(closed, json={"type": "join"}, headers=bob)).status_code == 404
    team = f"{SPACES}/{world['team'].id}/requests"
    assert (await client.post(team, json={"type": "join"}, headers=alice)).status_code == 409


async def test_my_requests_requires_authentication(client):
    assert (await client.get(f"{SPACES}/requests/mine")).status_code == 401


async def test_invite_accept_enforces_email_expiry_and_single_use(client, world, factory):
    await factory.execute(
        "INSERT INTO space_invites (id, space_id, email, token, status, expires_at, created_at) "
        "VALUES ('i1', :s, 'bob@example.com', 'tok-valid-0000000000', 'pending', :future, :now), "
        "('i2', :s, 'bob@example.com', 'tok-expired-00000000', 'pending', :past, :now)",
        s=world["open"].id,
        future=datetime.utcnow() + timedelta(days=1),
        past=datetime.utcnow() - timedelta(days=1),
        now=datetime.utcnow(),
    )
    accept = f"{SPACES}/invites/accept"
    bob, alice = auth_headers(world["bob"]), auth_headers(world["alice"])
    assert (await client.post(accept, json={"token": "tok-valid-0000000000"}, headers=alice)).status_code == 403
    assert (await client.post(accept, json={"token": "tok-expired-00000000"}, headers=bob)).status_code == 400
    ok = await client.post(accept, json={"token": "tok-valid-0000000000"}, headers=bob)
    assert ok.status_code == 200 and ok.json()["space_id"] == world["open"].id
    assert (await client.post(accept, json={"token": "tok-valid-0000000000"}, headers=bob)).status_code == 404
    assert [s["name"] for s in (await client.get(SPACES, headers=bob)).json()] == ["Open"]
