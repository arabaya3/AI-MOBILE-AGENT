"""Retrieval scope and persisted citations through the real chat routes and the local retrieval path."""

import uuid

import pytest

from tests.conftest import auth_headers
from tests.integration.test_chat_stream import parse_sse

DOCS = "/api/v1/documents"
STREAM = "/api/v1/chat/query/stream"


@pytest.fixture
async def world(factory):
    alice = await factory.user("alice@example.com")
    bob = await factory.user("bob@example.com")
    admin = await factory.user("admin@example.com")
    team = await factory.space("Team")
    await factory.member(team, alice)
    await factory.member(team, bob)
    await factory.member(team, admin, role="admin")
    await factory.execute("UPDATE space_members SET can_upload_documents = true WHERE user_id = :u", u=alice.id)
    return {"alice": alice, "bob": bob, "admin": admin, "team": team}


async def upload(client, user, space, name, text):
    response = await client.put(
        f"{DOCS}/uploads/{uuid.uuid4()}",
        params={"filename": name},
        content=text.encode(),
        headers=auth_headers(user, space),
    )
    assert response.status_code == 201, response.text
    assert response.json()["state"] == "ready"
    return response.json()


async def ask(client, user, space, message, **extra):
    response = await client.post(STREAM, json={"message": message, **extra}, headers=auth_headers(user, space))
    return parse_sse(response.text)


async def history(client, user, space, session_id):
    response = await client.get(f"/api/v1/chat/sessions/{session_id}", headers=auth_headers(user, space))
    assert response.status_code == 200
    return response.json()["history"]


@pytest.fixture
async def docs(client, world):
    birds = await upload(client, world["alice"], world["team"], "birds.txt", "The heron colony nests near the northern marsh.")
    budget = await upload(client, world["alice"], world["team"], "budget.txt", "The quarterly budget allocates funds to servers.")
    return {"birds": birds, "budget": budget}


async def test_selected_documents_restrict_retrieval(client, world, docs):
    events = await ask(client, world["alice"], world["team"], "Where does the heron colony nest?", document_ids=[docs["budget"]["id"]])
    sources = events[0][1]["sources"]
    assert sources and {s["document_id"] for s in sources} == {docs["budget"]["id"]}

    events = await ask(client, world["alice"], world["team"], "Where does the heron colony nest?")
    sources = events[0][1]["sources"]
    assert sources[0]["document_id"] == docs["birds"]["id"]
    for source in sources:
        assert set(source["metadata"]) <= {"page", "page_number", "sheet_name", "slide_number", "type", "source_chunk_index", "sub_chunk_index"}


async def test_selection_never_broadens_when_it_becomes_invalid(client, world, docs, factory):
    await factory.execute("UPDATE documents SET state = 'processing' WHERE id = :d", d=docs["birds"]["id"])
    events = await ask(client, world["alice"], world["team"], "heron?", document_ids=[docs["birds"]["id"]])
    assert events[-1] == ("error", {"detail": "A selected document is not ready yet", "code": "document_not_ready"})

    events = await ask(client, world["bob"], world["team"], "heron?", document_ids=[docs["budget"]["id"]])
    assert events[-1][1]["code"] == "document_access_denied"

    events = await ask(client, world["alice"], world["team"], "heron colony marsh")
    assert all(s["document_id"] != docs["birds"]["id"] for s in events[0][1]["sources"])


async def test_citations_persist_through_history_and_branching(client, world, docs):
    events = await ask(client, world["alice"], world["team"], "heron colony marsh", document_ids=[docs["birds"]["id"]])
    done = events[-1][1]
    messages = await history(client, world["alice"], world["team"], done["session_id"])
    answer = next(m for m in messages if m["id"] == done["message_id"])
    assert answer["citations"][0] == {
        "available": True,
        "document_id": docs["birds"]["id"],
        "filename": "birds.txt",
        "chunk_index": 0,
        "page": None,
        "excerpt": "The heron colony nests near the northern marsh.",
    }
    user_turn = next(m for m in messages if m["role"] == "user")
    assert user_turn["citations"] is None

    branch = await client.post(
        f"/api/v1/chat/sessions/{done['session_id']}/branch",
        json={"from_message_id": done["message_id"]},
        headers=auth_headers(world["alice"], world["team"]),
    )
    branched = await history(client, world["alice"], world["team"], branch.json()["session_id"])
    assert branched[-1]["citations"][0]["document_id"] == docs["birds"]["id"]


async def test_non_streaming_answers_persist_citations(client, world, docs):
    response = await client.post(
        "/api/v1/chat/query",
        json={"message": "quarterly budget servers", "document_ids": [docs["budget"]["id"]]},
        headers=auth_headers(world["alice"], world["team"]),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["history"][-1]["citations"][0]["document_id"] == docs["budget"]["id"]
    assert "s3_url" not in response.text and "file_hash" not in response.text
    messages = await history(client, world["alice"], world["team"], body["session_id"])
    assert messages[-1]["citations"][0]["excerpt"].startswith("The quarterly budget")


async def test_revoked_access_hides_citation_content(client, world, docs):
    granted = await client.post(
        f"{DOCS}/permissions",
        json={"user_id": world["bob"].id, "document_ids": [docs["birds"]["id"]]},
        headers=auth_headers(world["admin"], world["team"]),
    )
    assert granted.status_code == 200
    events = await ask(client, world["bob"], world["team"], "heron colony marsh", document_ids=[docs["birds"]["id"]])
    done = events[-1][1]
    before = await history(client, world["bob"], world["team"], done["session_id"])
    assert before[-1]["citations"][0]["available"] is True

    revoked = await client.request(
        "DELETE",
        f"{DOCS}/permissions",
        json={"user_id": world["bob"].id, "document_ids": [docs["birds"]["id"]]},
        headers=auth_headers(world["admin"], world["team"]),
    )
    assert revoked.status_code == 200
    after = await history(client, world["bob"], world["team"], done["session_id"])
    assert after[-1]["citations"] == [{"available": False, "document_id": None, "filename": None, "chunk_index": None, "page": None, "excerpt": None}]
    assert "heron colony nests" not in str(after[-1]["citations"])
    download = await client.get(f"{DOCS}/{docs['birds']['id']}/download", headers=auth_headers(world["bob"], world["team"]))
    assert download.status_code == 404


async def test_hidden_documents_are_unavailable_to_members(client, world, docs):
    events = await ask(client, world["alice"], world["team"], "heron colony marsh", document_ids=[docs["birds"]["id"]])
    done = events[-1][1]
    hidden = await client.patch(
        f"{DOCS}/{docs['birds']['id']}/visibility",
        json={"is_hidden": True},
        headers=auth_headers(world["admin"], world["team"]),
    )
    assert hidden.status_code == 200
    messages = await history(client, world["alice"], world["team"], done["session_id"])
    assert messages[-1]["citations"][0]["available"] is False


async def test_public_shares_exclude_citations(client, world, docs):
    events = await ask(client, world["alice"], world["team"], "heron colony marsh", document_ids=[docs["birds"]["id"]])
    done = events[-1][1]
    share = await client.post(
        f"/api/v1/chat/sessions/{done['session_id']}/share", headers=auth_headers(world["alice"], world["team"])
    )
    shared = await client.get(f"/api/v1/chat/shared/{share.json()['token']}")
    assert shared.status_code == 200
    assert "citations" not in shared.text and "heron colony nests" not in shared.text
    assert "birds.txt" not in shared.text


async def test_messages_without_citations_still_load(client, world, factory):
    session = await factory.session(world["team"], world["alice"])
    messages = await history(client, world["alice"], world["team"], session.id)
    assert [m["citations"] for m in messages] == [None, None]
