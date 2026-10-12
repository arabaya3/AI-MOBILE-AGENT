from datetime import timedelta

from src.core.security.auth import create_access_token

from tests.conftest import auth_headers

ME = "/api/v1/auth/me"
FORBIDDEN_KEYS = {
    "hashed_password",
    "password",
    "custom_system_prompts",
    "daily_request_limit_override",
    "monthly_request_limit_override",
    "allowed_models_override",
}


async def test_requires_authentication(client):
    assert (await client.get(ME)).status_code == 401


async def test_rejects_expired_and_malformed_tokens(client, factory):
    user = await factory.user("me@example.com")
    expired = create_access_token(subject=user.id, scopes=[user.role], expires_delta=timedelta(seconds=-5))
    assert (await client.get(ME, headers={"Authorization": f"Bearer {expired}"})).status_code == 401
    assert (await client.get(ME, headers={"Authorization": "Bearer not-a-jwt"})).status_code == 401


async def test_rejects_inactive_user(client, factory):
    user = await factory.user("inactive@example.com", active=False)
    assert (await client.get(ME, headers=auth_headers(user))).status_code == 401


async def test_returns_only_the_callers_account_without_credentials(client, factory):
    user = await factory.user("me@example.com", password="Password123!")
    await factory.user("other@example.com")
    await factory.execute(
        "UPDATE users SET first_name = 'Lina', preferred_language = 'ar', "
        "custom_system_prompts = CAST(:prompts AS JSON) WHERE id = :id",
        prompts='{"x": "y"}',
        id=user.id,
    )

    response = await client.get(ME, headers=auth_headers(user))
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == user.id
    assert body["email"] == "me@example.com"
    assert body["role"] == "viewer"
    assert body["is_active"] is True
    assert body["first_name"] == "Lina"
    assert body["preferred_language"] == "ar"
    assert not FORBIDDEN_KEYS & body.keys()
    assert "other@example.com" not in response.text


async def test_role_comes_from_database_not_token_claims(client, factory):
    user = await factory.user("promoted@example.com")
    await factory.execute("UPDATE users SET role = 'admin' WHERE id = :id", id=user.id)
    token = create_access_token(subject=user.id, scopes=["viewer"])
    body = (await client.get(ME, headers={"Authorization": f"Bearer {token}"})).json()
    assert body["role"] == "admin"


async def test_wrong_current_password_is_400_not_session_expiry(client, factory):
    user = await factory.user("cp@example.com", password="Password123!")
    response = await client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "WrongPass123!", "new_password": "NewPassword1!"},
        headers=auth_headers(user),
    )
    assert response.status_code == 400
    ok = await client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "Password123!", "new_password": "NewPassword1!"},
        headers=auth_headers(user),
    )
    assert ok.status_code == 200
    login = await client.post("/api/v1/auth/login", json={"email": "cp@example.com", "password": "NewPassword1!"})
    assert login.status_code == 200


async def test_public_signup_cannot_choose_elevated_roles(client):
    for role in ("admin", "super_admin"):
        response = await client.post(
            "/api/v1/auth/signup",
            json={"email": f"{role}@example.com", "password": "Password123!", "role": role},
        )
        assert response.status_code == 403
    viewer = await client.post("/api/v1/auth/signup", json={"email": "new@example.com", "password": "Password123!"})
    assert viewer.status_code == 201
    assert viewer.json()["role"] == "viewer"


async def test_login_distinguishes_inactive_account(client, factory):
    await factory.user("off@example.com", password="Password123!", active=False)
    response = await client.post("/api/v1/auth/login", json={"email": "off@example.com", "password": "Password123!"})
    assert response.status_code == 403
    wrong = await client.post("/api/v1/auth/login", json={"email": "off@example.com", "password": "nope-nope"})
    assert wrong.status_code == 401
