import logging
import re
from datetime import datetime, timedelta
from urllib.parse import parse_qs, urlparse

import pytest

from src.services.email import service as email_module

FORGOT = "/api/v1/auth/forgot-password"
RESET = "/api/v1/auth/reset-password"
VALIDATE = "/api/v1/auth/reset-password/validate"
LOGIN = "/api/v1/auth/login"


def _token_from(message) -> str:
    plain = next(p for p in message.walk() if p.get_content_type() == "text/plain").get_payload(decode=True).decode()
    link = re.search(r"https://app\.example\.test/auth\?\S+", plain).group(0)
    return parse_qs(urlparse(link).query)["token"][0]


@pytest.fixture
async def user(factory):
    return await factory.user("alice@example.com", password="OldPassword1!")


async def test_response_is_identical_for_known_and_unknown_accounts(client, user, email_sink):
    known = await client.post(FORGOT, json={"email": "alice@example.com"})
    unknown = await client.post(FORGOT, json={"email": "nobody@example.com"})
    assert known.status_code == unknown.status_code == 200
    assert known.json() == unknown.json()
    assert "reset_token" not in known.json()
    assert len(email_sink.messages) == 1
    assert email_sink.messages[0]["To"] == "alice@example.com"


async def test_token_is_delivered_only_by_email_and_never_leaks(client, user, email_sink, caplog):
    caplog.set_level(logging.DEBUG)
    response = await client.post(FORGOT, json={"email": "alice@example.com"})
    token = _token_from(email_sink.messages[0])
    assert token not in response.text
    assert all(token not in record.getMessage() for record in caplog.records)


async def test_token_is_stored_hashed(client, user, email_sink, factory):
    await client.post(FORGOT, json={"email": "alice@example.com"})
    token = _token_from(email_sink.messages[0])
    hashes = [row[0] for row in (await factory.execute("SELECT token_hash FROM password_reset_tokens")).all()]
    assert token not in hashes and len(hashes) == 1


async def test_reset_succeeds_once_and_rejects_replay(client, user, email_sink):
    await client.post(FORGOT, json={"email": "alice@example.com"})
    token = _token_from(email_sink.messages[0])

    assert (await client.post(VALIDATE, json={"token": token})).json() == {"valid": True}
    assert (await client.post(RESET, json={"token": token, "new_password": "NewPassword1!"})).status_code == 200
    assert (await client.post(LOGIN, json={"email": "alice@example.com", "password": "NewPassword1!"})).status_code == 200
    assert (await client.post(LOGIN, json={"email": "alice@example.com", "password": "OldPassword1!"})).status_code == 401

    replay = await client.post(RESET, json={"token": token, "new_password": "Another1Pass!"})
    assert replay.status_code == 400
    assert (await client.post(VALIDATE, json={"token": token})).json() == {"valid": False}


async def test_expired_token_is_rejected(client, user, email_sink, factory):
    await client.post(FORGOT, json={"email": "alice@example.com"})
    token = _token_from(email_sink.messages[0])
    await factory.execute(
        "UPDATE password_reset_tokens SET expires_at = :past", past=datetime.utcnow() - timedelta(seconds=1)
    )
    assert (await client.post(VALIDATE, json={"token": token})).json() == {"valid": False}
    assert (await client.post(RESET, json={"token": token, "new_password": "NewPassword1!"})).status_code == 400


async def test_new_request_invalidates_previous_token(client, user, email_sink):
    await client.post(FORGOT, json={"email": "alice@example.com"})
    await client.post(FORGOT, json={"email": "alice@example.com"})
    first, second = (_token_from(m) for m in email_sink.messages)
    assert (await client.post(RESET, json={"token": first, "new_password": "NewPassword1!"})).status_code == 400
    assert (await client.post(RESET, json={"token": second, "new_password": "NewPassword1!"})).status_code == 200


async def test_invalid_token_is_rejected(client, user):
    assert (await client.post(RESET, json={"token": "bogus", "new_password": "NewPassword1!"})).status_code == 400
    assert (await client.post(VALIDATE, json={"token": "bogus"})).json() == {"valid": False}


async def test_disabled_email_never_exposes_or_creates_a_token(client, user, email_sink, factory, monkeypatch):
    monkeypatch.setattr(email_module.email_service, "enabled", False)
    response = await client.post(FORGOT, json={"email": "alice@example.com"})
    assert response.status_code == 200
    assert "reset_token" not in response.json()
    assert email_sink.messages == []
    assert (await factory.execute("SELECT count(*) FROM password_reset_tokens")).scalar_one() == 0


async def test_inactive_account_gets_generic_response_and_no_email(client, factory, email_sink):
    await factory.user("inactive@example.com", active=False)
    unknown = await client.post(FORGOT, json={"email": "nobody@example.com"})
    inactive = await client.post(FORGOT, json={"email": "inactive@example.com"})
    assert inactive.json() == unknown.json()
    assert email_sink.messages == []
