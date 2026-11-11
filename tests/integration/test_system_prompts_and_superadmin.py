"""S29: global prompts for super admins only, personal overrides for their owner only. S7: super-admin routes."""

from types import SimpleNamespace

import pytest

from src.core.settings import system_prompts
from src.services.llm_providers.openai.chat import OpenAIChatService

from tests.conftest import auth_headers
from tests.integration.test_chat_stream import parse_sse

GLOBAL = "/api/v1/system-prompts/global"
MINE = "/api/v1/system-prompts/me"


@pytest.fixture(autouse=True)
def prompts_file(tmp_path, monkeypatch):
    monkeypatch.setattr(system_prompts, "_prompts_path", lambda: tmp_path / "prompts.json")
    system_prompts.load_system_prompts()
    yield
    monkeypatch.undo()
    system_prompts.load_system_prompts()


@pytest.fixture
async def world(factory):
    root = await factory.user("root@example.com", role="super_admin")
    admin = await factory.user("admin@example.com")
    member = await factory.user("member@example.com")
    other = await factory.user("other@example.com")
    team = await factory.space("Team")
    await factory.member(team, admin, role="admin")
    await factory.member(team, member)
    await factory.member(team, other)
    return {"root": root, "admin": admin, "member": member, "other": other, "team": team}


async def test_global_prompts_need_a_super_admin(client, world):
    assert (await client.get(GLOBAL)).status_code == 401
    assert (await client.put(GLOBAL, json={"stream_system_prompt": "x"})).status_code == 401
    for user in ("member", "admin"):
        headers = auth_headers(world[user], world["team"])
        assert (await client.get(GLOBAL, headers=headers)).status_code == 403
        assert (await client.put(GLOBAL, json={"stream_system_prompt": "hijack"}, headers=headers)).status_code == 403
    assert "hijack" not in system_prompts.get_system_prompts()["stream_system_prompt"]

    root = auth_headers(world["root"])
    assert (await client.get(GLOBAL, headers=root)).json()["stream_system_prompt"]
    updated = await client.put(GLOBAL, json={"stream_system_prompt": "Global rule."}, headers=root)
    assert updated.status_code == 200 and updated.json()["stream_system_prompt"] == "Global rule."
    assert system_prompts.get_system_prompts()["stream_system_prompt"] == "Global rule."


async def test_the_old_combined_route_is_gone(client, world):
    headers = auth_headers(world["member"])
    assert (await client.get("/api/v1/system-prompts", headers=headers)).status_code in (404, 405)
    assert (await client.put("/api/v1/system-prompts", json={"stream_system_prompt": "x"}, headers=headers)).status_code in (404, 405)


async def test_personal_overrides_are_private_and_never_global(client, world):
    assert (await client.get(MINE)).status_code == 401
    before = system_prompts.get_system_prompts()
    mine = auth_headers(world["member"])
    saved = await client.put(MINE, json={"stream_system_prompt": "Only for me."}, headers=mine)
    assert saved.json() == {"overrides": {"stream_system_prompt": "Only for me."}, "applied_to_generation": False}
    # The response and later reads carry no global configuration.
    read = (await client.get(MINE, headers=mine)).json()
    assert set(read) == {"overrides", "applied_to_generation"}
    assert before["memory_system_prompt"] not in str(read)
    assert (await client.get(MINE, headers=auth_headers(world["other"]))).json()["overrides"] == {}
    assert system_prompts.get_system_prompts() == before
    cleared = await client.put(MINE, json={"stream_system_prompt": ""}, headers=mine)
    assert cleared.json()["overrides"] == {}
    too_long = await client.put(MINE, json={"stream_system_prompt": "x" * 20_001}, headers=mine)
    assert too_long.status_code == 422


async def test_chat_is_unchanged_by_personal_overrides(client, world):
    headers = auth_headers(world["member"], world["team"])
    await client.put(MINE, json={"stream_system_prompt": "Reply only in pirate speak."}, headers=headers)
    events = parse_sse((await client.post("/api/v1/chat/query/stream", json={"message": "hello"}, headers=headers)).text)
    assert events[-1][0] == "done"


async def test_generation_uses_the_global_prompt(client, world):
    await client.put(GLOBAL, json={"stream_system_prompt": "Global rule for every reply."}, headers=auth_headers(world["root"]))
    sent = {}

    class Stream:
        def __iter__(self):
            return iter([])

        def close(self):
            pass

    def create(**kwargs):
        sent.update(kwargs)
        return Stream()

    service = OpenAIChatService(model="gpt-4o-mini")
    service._get_client = lambda *_a, **_k: SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create)))
    async for _ in service.stream_with_memory(history=[], question="hi", contexts=[]):
        pass
    assert sent["messages"][0]["role"] == "system"
    assert sent["messages"][0]["content"].startswith("Global rule for every reply.")


async def test_superadmin_usage_route_is_reachable_and_restricted(client, world):
    url = "/api/v1/spaces/_superadmin/usage"
    assert (await client.get(url)).status_code == 401
    for user in ("member", "admin"):
        response = await client.get(url, headers=auth_headers(world[user]))
        assert response.status_code == 403 and response.json()["detail"] == "Super admin required"
    rows = await client.get(url, headers=auth_headers(world["root"]))
    assert rows.status_code == 200 and [r["space_name"] for r in rows.json()] == ["Team"]
    spaces = await client.get("/api/v1/spaces/_superadmin/spaces", headers=auth_headers(world["root"]))
    assert spaces.status_code == 200 and [s["name"] for s in spaces.json()] == ["Team"]


async def test_route_order_resolves_fixed_paths_first(world):
    from src.modules.apis.v1.spaces.router import router

    paths = [route.path for route in router.routes]
    for fixed in ("/spaces/_superadmin/usage", "/spaces/_superadmin/spaces", "/spaces/admin/dashboard"):
        assert paths.index(fixed) < paths.index("/spaces/{space_id}/usage"), fixed


async def test_super_admin_on_a_missing_space_is_404_not_a_server_error(client, world):
    response = await client.get("/api/v1/spaces/does-not-exist/usage", headers=auth_headers(world["root"]))
    assert response.status_code == 404
