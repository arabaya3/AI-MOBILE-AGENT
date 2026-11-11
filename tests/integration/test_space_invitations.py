"""Invitations: emailed random tokens stored as hashes; expiry, revocation, resend, replay and binding."""

import asyncio
import logging
import re

import pytest
from sqlalchemy import select

from src.modules.apis.v1.spaces.invitations import hash_token
from src.services.databases.postgresql.models import SpaceInvite, SpaceMember
from src.services.email import service as email_module

from tests.conftest import auth_headers

SPACES = "/api/v1/spaces"
ACCEPT = f"{SPACES}/invites/accept"
TOKEN = re.compile(r"join-space\?token=([A-Za-z0-9_-]+)")


@pytest.fixture
async def world(factory):
    admin = await factory.user("admin@example.com")
    bob = await factory.user("bob@example.com")
    carol = await factory.user("carol@example.com")
    team = await factory.space("Team")
    other = await factory.space("Other")
    await factory.member(team, admin, role="admin")
    await factory.member(other, admin, role="admin")
    return {"admin": admin, "bob": bob, "carol": carol, "team": team, "other": other}


def tokens_sent(sink, to):
    found = []
    for msg in sink.messages:
        if msg["To"] != to:
            continue
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                found += TOKEN.findall(part.get_payload(decode=True).decode())
    return found


async def invite(client, world, email="bob@example.com", space="team"):
    return await client.post(f"{SPACES}/{world[space].id}/invites", json={"email": email}, headers=auth_headers(world["admin"]))


async def invites(session_factory, email):
    async with session_factory() as db:
        return list((await db.execute(select(SpaceInvite).where(SpaceInvite.email == email))).scalars())


async def test_token_goes_only_to_email_and_is_stored_hashed(client, world, email_sink, session_factory, caplog):
    caplog.set_level(logging.DEBUG)
    created = await invite(client, world)
    assert created.status_code == 200
    body = created.json()
    assert body["status"] == "pending" and body["email"] == "bob@example.com" and "token" not in str(body).lower()
    [token] = tokens_sent(email_sink, "bob@example.com")
    [row] = await invites(session_factory, "bob@example.com")
    assert row.token is None and row.token_hash == hash_token(token) and token not in row.token_hash
    listed = (await client.get(f"{SPACES}/{world['team'].id}/invites", headers=auth_headers(world["admin"]))).text
    assert token not in listed and row.token_hash not in listed
    assert token not in caplog.text


async def test_accept_is_single_use_and_bound_to_the_invited_address(client, world, email_sink):
    await invite(client, world)
    [token] = tokens_sent(email_sink, "bob@example.com")
    assert (await client.post(ACCEPT, json={"token": token}, headers=auth_headers(world["carol"]))).status_code == 403
    ok = await client.post(ACCEPT, json={"token": token}, headers=auth_headers(world["bob"]))
    assert ok.status_code == 200 and ok.json() == {"space_id": world["team"].id, "status": "active"}
    assert (await client.post(ACCEPT, json={"token": token}, headers=auth_headers(world["bob"]))).status_code == 404
    assert (await client.post(ACCEPT, json={"token": "x" * 43}, headers=auth_headers(world["bob"]))).status_code == 404


async def test_expired_and_revoked_invitations_are_refused(client, world, email_sink, factory):
    await invite(client, world)
    [token] = tokens_sent(email_sink, "bob@example.com")
    await factory.execute("UPDATE space_invites SET expires_at = now() at time zone 'utc' - interval '1 minute'")
    assert (await client.post(ACCEPT, json={"token": token}, headers=auth_headers(world["bob"]))).status_code == 400
    listed = (await client.get(f"{SPACES}/{world['team'].id}/invites", headers=auth_headers(world["admin"]))).json()
    assert listed[0]["status"] == "expired"

    await invite(client, world, "carol@example.com")
    [carol_token] = tokens_sent(email_sink, "carol@example.com")
    invite_id = next(i["id"] for i in (await client.get(f"{SPACES}/{world['team'].id}/invites", headers=auth_headers(world["admin"]))).json() if i["email"] == "carol@example.com")
    revoked = await client.post(f"{SPACES}/{world['team'].id}/invites/{invite_id}/revoke", headers=auth_headers(world["admin"]))
    assert revoked.json()["status"] == "revoked"
    assert (await client.post(ACCEPT, json={"token": carol_token}, headers=auth_headers(world["carol"]))).status_code == 404


async def test_resend_replaces_the_token_without_duplicating(client, world, email_sink, session_factory):
    first = (await invite(client, world)).json()
    again = (await invite(client, world)).json()
    assert again["id"] == first["id"] and again["send_count"] == 2
    resent = await client.post(f"{SPACES}/{world['team'].id}/invites/{first['id']}/resend", headers=auth_headers(world["admin"]))
    assert resent.json()["send_count"] == 3
    old1, old2, new = tokens_sent(email_sink, "bob@example.com")
    for old in (old1, old2):
        assert (await client.post(ACCEPT, json={"token": old}, headers=auth_headers(world["bob"]))).status_code == 404
    assert (await client.post(ACCEPT, json={"token": new}, headers=auth_headers(world["bob"]))).status_code == 200
    assert len(await invites(session_factory, "bob@example.com")) == 1
    async with session_factory() as db:
        members = (await db.execute(select(SpaceMember).where(SpaceMember.user_id == world["bob"].id))).scalars().all()
    assert len(members) == 1
    # Accepted invitations cannot be resent or revoked.
    assert (await client.post(f"{SPACES}/{world['team'].id}/invites/{first['id']}/resend", headers=auth_headers(world["admin"]))).status_code == 409
    assert (await client.post(f"{SPACES}/{world['team'].id}/invites/{first['id']}/revoke", headers=auth_headers(world["admin"]))).status_code == 409


async def test_expired_invitation_can_be_resent(client, world, email_sink, factory):
    created = (await invite(client, world)).json()
    await factory.execute("UPDATE space_invites SET status = 'expired'")
    resent = await client.post(f"{SPACES}/{world['team'].id}/invites/{created['id']}/resend", headers=auth_headers(world["admin"]))
    assert resent.status_code == 200 and resent.json()["status"] == "pending"
    token = tokens_sent(email_sink, "bob@example.com")[-1]
    assert (await client.post(ACCEPT, json={"token": token}, headers=auth_headers(world["bob"]))).status_code == 200


async def test_concurrent_acceptance_joins_once(client, world, email_sink, session_factory):
    await invite(client, world)
    [token] = tokens_sent(email_sink, "bob@example.com")
    results = await asyncio.gather(*(client.post(ACCEPT, json={"token": token}, headers=auth_headers(world["bob"])) for _ in range(5)))
    assert sorted(r.status_code for r in results) == [200, 404, 404, 404, 404]
    async with session_factory() as db:
        assert len((await db.execute(select(SpaceMember).where(SpaceMember.user_id == world["bob"].id))).scalars().all()) == 1


async def test_concurrent_invites_open_one_invitation(client, world, session_factory):
    results = await asyncio.gather(*(invite(client, world) for _ in range(4)))
    assert {r.status_code for r in results} == {200}
    assert len(await invites(session_factory, "bob@example.com")) == 1


async def test_members_revoked_members_and_inactive_spaces(client, world, email_sink, factory):
    await factory.member(world["team"], world["carol"])
    assert (await invite(client, world, "carol@example.com")).status_code == 409

    await factory.member(world["other"], world["bob"], role="admin", status="revoked")
    await invite(client, world, "bob@example.com", space="other")
    [token] = tokens_sent(email_sink, "bob@example.com")
    assert (await client.post(ACCEPT, json={"token": token}, headers=auth_headers(world["bob"]))).status_code == 200
    me = (await client.get(f"{SPACES}/{world['other'].id}/me", headers=auth_headers(world["bob"]))).json()
    assert (me["status"], me["role"]) == ("active", "member")  # returns without earlier admin rights

    await invite(client, world, "new@example.com")
    [pending] = tokens_sent(email_sink, "new@example.com")
    await factory.execute("UPDATE spaces SET is_active = false WHERE id = :s", s=world["team"].id)
    newcomer = await factory.user("new@example.com")
    assert (await client.post(ACCEPT, json={"token": pending}, headers=auth_headers(newcomer))).status_code == 404
    assert (await invite(client, world, "x@example.com")).status_code == 409


async def test_email_change_breaks_the_binding(client, world, email_sink, factory):
    await invite(client, world)
    [token] = tokens_sent(email_sink, "bob@example.com")
    await factory.execute("UPDATE users SET email = 'bob.new@example.com' WHERE id = :u", u=world["bob"].id)
    assert (await client.post(ACCEPT, json={"token": token}, headers=auth_headers(world["bob"]))).status_code == 403


async def test_no_email_delivery_means_no_invitation(client, world, monkeypatch, session_factory):
    monkeypatch.setattr(email_module.email_service, "enabled", False)
    response = await invite(client, world)
    assert response.status_code == 503 and "token" not in response.text.lower()
    assert await invites(session_factory, "bob@example.com") == []


async def test_only_space_admins_manage_invitations(client, world, factory):
    await factory.member(world["team"], world["carol"])
    created = (await invite(client, world)).json()
    base = f"{SPACES}/{world['team'].id}/invites"
    for user in (world["carol"], world["bob"]):
        headers = auth_headers(user)
        assert (await client.post(base, json={"email": "z@example.com"}, headers=headers)).status_code == 403
        assert (await client.get(base, headers=headers)).status_code == 403
        assert (await client.post(f"{base}/{created['id']}/revoke", headers=headers)).status_code == 403
        assert (await client.post(f"{base}/{created['id']}/resend", headers=headers)).status_code == 403
    # An admin of another space cannot touch this space's invitation through their own space.
    other = f"{SPACES}/{world['other'].id}/invites/{created['id']}/revoke"
    assert (await client.post(other, headers=auth_headers(world["admin"]))).status_code == 404
    assert (await client.post(base, json={"email": "not-an-email"}, headers=auth_headers(world["admin"]))).status_code == 422
