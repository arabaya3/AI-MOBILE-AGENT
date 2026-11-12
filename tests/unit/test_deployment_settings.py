"""A non-local deployment refuses to start with a default or weak SECRET_KEY or a wildcard CORS origin."""

import pytest

from src.core.settings.config import Settings, assert_deployable_settings, deployment_problems

STRONG = "x" * 48


def make(**overrides):
    base = dict(AWS_ACCESS_KEY_ID="a", AWS_SECRET_ACCESS_KEY="b", AWS_REGION="r", AWS_S3_BUCKET="bucket")
    return Settings(**{**base, **overrides})


@pytest.mark.parametrize("env", ["staging", "production", "Staging "])
@pytest.mark.parametrize("secret", ["", "change-me", "short-secret"])
def test_weak_secrets_block_deployments(env, secret):
    config = make(APP_ENV=env, SECRET_KEY=secret)
    assert deployment_problems(config)
    with pytest.raises(RuntimeError) as err:
        assert_deployable_settings(config)
    assert secret == "" or secret not in str(err.value)


def test_wildcard_cors_blocks_deployments():
    assert deployment_problems(make(APP_ENV="staging", SECRET_KEY=STRONG, CORS_ALLOW_ORIGINS=["*"]))


def test_strong_settings_pass_and_local_environments_are_exempt():
    assert deployment_problems(make(APP_ENV="staging", SECRET_KEY=STRONG, CORS_ALLOW_ORIGINS=["https://web.example"])) == []
    assert deployment_problems(make(APP_ENV="development", SECRET_KEY="change-me")) == []
    assert deployment_problems(make(APP_ENV="test", SECRET_KEY="")) == []
