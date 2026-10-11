import hashlib
from datetime import datetime, timedelta

import pytest

from tests.conftest import auth_headers


@pytest.fixture
async def world(factory):
    owner = await factory.user("owner@example.test")
    peer = await factory.user("peer@example.test")
    outsider = await factory.user("outsider@example.test")
    space = await factory.space("Team")
    other_space = await factory.space("Other")
    await factory.member(space, owner)
    await factory.member(space, peer)
    await factory.member(other_space, outsider)
    chat = await factory.session(space, owner)
    return {"owner": owner, "peer": peer, "outsider": outsider, "space": space, "other_space": other_space, "chat": chat}


async def _share(client, w, **body):
    return await client.post(
        f"/api/v1/chat/sessions/{w['chat'].id}/share",
        json=body or None,
        headers=auth_headers(w["owner"], w["space"]),
    )


async def test_session_id_is_not_a_share_credential(client, world):
    assert (await client.get(f"/api/v1/chat/shared/{world['chat'].id}")).status_code == 404


async def test_unshared_conversation_is_not_reachable_even_with_other_shares(client, world, factory):
    other_chat = await factory.session(world["space"], world["owner"], messages=(("user", "secret plan"),))
    assert (await _share(client, world)).status_code == 201
    assert (await client.get(f"/api/v1/chat/shared/{other_chat.id}")).status_code == 404


async def test_owner_share_returns_only_intended_content(client, world):
    created = await _share(client, world)
    assert created.status_code == 201
    body = created.json()
    assert body["share_url"] == f"/api/v1/chat/shared/{body['token']}"
    assert world["chat"].id not in body["token"]

    viewed = await client.get(body["share_url"])
    assert viewed.status_code == 200
    assert viewed.headers["cache-control"] == "no-store"
    data = viewed.json()
    assert set(data) == {"title", "shared_at", "expires_at", "messages"}
    assert [(m["role"], m["content"]) for m in data["messages"]] == [("user", "Hello"), ("assistant", "Hi there")]
    assert all(set(m) == {"role", "content", "created_at"} for m in data["messages"])
    raw = viewed.text
    for private in (world["chat"].id, world["owner"].id, world["space"].id, "s3://", "owner@example.test"):
        assert private not in raw


async def test_token_is_stored_only_as_hash(client, world, factory):
    token = (await _share(client, world)).json()["token"]
    rows = (await factory.execute("SELECT token_hash FROM chat_shares")).all()
    assert rows == [(hashlib.sha256(token.encode()).hexdigest(),)]


async def test_share_requires_authentication(client, world):
    response = await client.post(f"/api/v1/chat/sessions/{world['chat'].id}/share")
    assert response.status_code == 401


async def test_member_cannot_share_someone_elses_session(client, world):
    response = await client.post(
        f"/api/v1/chat/sessions/{world['chat'].id}/share", headers=auth_headers(world["peer"], world["space"])
    )
    assert response.status_code == 404


async def test_outsider_cannot_share_or_list_across_spaces(client, world):
    path = f"/api/v1/chat/sessions/{world['chat'].id}"
    own_space = auth_headers(world["outsider"], world["other_space"])
    foreign_space = auth_headers(world["outsider"], world["space"])
    assert (await client.post(f"{path}/share", headers=own_space)).status_code == 404
    assert (await client.post(f"{path}/share", headers=foreign_space)).status_code in (403, 404)
    assert (await client.get(f"{path}/shares", headers=own_space)).status_code == 404


async def test_owner_cannot_share_through_a_different_space_header(client, world, factory):
    await factory.member(world["other_space"], world["owner"])
    response = await client.post(
        f"/api/v1/chat/sessions/{world['chat'].id}/share", headers=auth_headers(world["owner"], world["other_space"])
    )
    assert response.status_code == 404


async def test_invalid_and_malformed_tokens_are_rejected(client, world):
    await _share(client, world)
    for token in ("not-a-real-token", "x" * 200, "%00"):
        assert (await client.get(f"/api/v1/chat/shared/{token}")).status_code == 404


async def test_expired_share_is_rejected(client, world, factory):
    body = (await _share(client, world)).json()
    await factory.execute(
        "UPDATE chat_shares SET expires_at = :past WHERE id = :id",
        past=datetime.utcnow() - timedelta(seconds=1),
        id=body["share_id"],
    )
    assert (await client.get(body["share_url"])).status_code == 404


async def test_expiry_above_policy_maximum_is_rejected(client, world):
    assert (await _share(client, world, expires_in_hours=10_000)).status_code == 422


async def test_owner_can_revoke_and_link_stops_working(client, world):
    body = (await _share(client, world)).json()
    assert (await client.get(body["share_url"])).status_code == 200

    revoked = await client.delete(f"/api/v1/chat/shares/{body['share_id']}", headers=auth_headers(world["owner"]))
    assert revoked.status_code == 200
    assert revoked.json()["active"] is False
    assert (await client.get(body["share_url"])).status_code == 404


async def test_non_owner_cannot_revoke(client, world):
    body = (await _share(client, world)).json()
    response = await client.delete(f"/api/v1/chat/shares/{body['share_id']}", headers=auth_headers(world["peer"]))
    assert response.status_code == 404
    assert (await client.get(body["share_url"])).status_code == 200


async def test_listing_shares_never_returns_tokens(client, world):
    token = (await _share(client, world)).json()["token"]
    listed = await client.get(
        f"/api/v1/chat/sessions/{world['chat'].id}/shares", headers=auth_headers(world["owner"], world["space"])
    )
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    assert token not in listed.text


async def test_messages_added_after_sharing_are_not_exposed(client, world, factory):
    body = (await _share(client, world)).json()
    await factory.execute(
        "INSERT INTO chat_messages (id, session_id, role, content, meta_payload, created_at) "
        "VALUES ('later', :sid, 'user', 'added later', '{}', :ts)",
        sid=world["chat"].id,
        ts=datetime.utcnow() + timedelta(seconds=5),
    )
    contents = [m["content"] for m in (await client.get(body["share_url"])).json()["messages"]]
    assert "added later" not in contents


async def test_share_stops_when_owner_loses_space_access(client, world, factory):
    body = (await _share(client, world)).json()
    await factory.execute(
        "UPDATE space_members SET status = 'revoked' WHERE user_id = :uid AND space_id = :sid",
        uid=world["owner"].id,
        sid=world["space"].id,
    )
    assert (await client.get(body["share_url"])).status_code == 404


async def test_share_stops_when_space_is_deactivated(client, world, factory):
    body = (await _share(client, world)).json()
    await factory.execute("UPDATE spaces SET is_active = FALSE WHERE id = :sid", sid=world["space"].id)
    assert (await client.get(body["share_url"])).status_code == 404


async def test_inactive_space_cannot_create_shares(client, world, factory):
    await factory.execute("UPDATE spaces SET is_active = FALSE WHERE id = :sid", sid=world["space"].id)
    assert (await _share(client, world)).status_code in (403, 404)
