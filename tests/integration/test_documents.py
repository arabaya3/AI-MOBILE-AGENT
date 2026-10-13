"""Documents over the real routes: extraction subprocess, local S3 (moto), Qdrant local mode, stub embeddings."""

import io
import uuid
import zipfile
from datetime import datetime, timedelta
from pathlib import Path

import pytest

from src.core.settings.config import settings
from src.modules.apis.v1.documents import pipeline
from src.services.databases.qdrant.client import qdrant_vector_store

from tests.conftest import auth_headers

DOCS = "/api/v1/documents"


@pytest.fixture
async def world(factory):
    alice = await factory.user("alice@example.com")
    bob = await factory.user("bob@example.com")
    admin = await factory.user("admin@example.com")
    outsider = await factory.user("outsider@example.com")
    team = await factory.space("Team")
    other = await factory.space("Other")
    await factory.member(team, alice)
    await factory.member(team, bob)
    await factory.member(team, admin, role="admin")
    await factory.member(other, alice)
    await factory.execute("UPDATE space_members SET can_upload_documents = true WHERE user_id = :u", u=alice.id)
    return {"alice": alice, "bob": bob, "admin": admin, "outsider": outsider, "team": team, "other": other}


async def put(client, user, space, name, body, upload_id=None, **kwargs):
    upload_id = upload_id or str(uuid.uuid4())
    return await client.put(
        f"{DOCS}/uploads/{upload_id}",
        params={"filename": name},
        content=body,
        headers=auth_headers(user, space),
        **kwargs,
    )


def temp_files() -> list[Path]:
    return [p for p in pipeline.WORK_DIR.glob("*")] if pipeline.WORK_DIR.exists() else []


def make_pdf(text: str, password: str | None = None) -> bytes:
    import fitz

    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((72, 72), text)
    options = {}
    if password:
        options = {"encryption": fitz.PDF_ENCRYPT_AES_256, "user_pw": password, "owner_pw": password}
    data = doc.tobytes(**options)
    doc.close()
    return data


async def count_points(document_id: str) -> int:
    from qdrant_client.http import models

    result = qdrant_vector_store.client.count(
        collection_name=qdrant_vector_store.collection_name,
        count_filter=models.Filter(
            must=[models.FieldCondition(key="document_id", match=models.MatchValue(value=document_id))]
        ),
        exact=True,
    )
    return result.count


async def test_upload_processes_to_ready_and_is_idempotent_by_upload_id(client, world):
    upload_id = str(uuid.uuid4())
    response = await put(client, world["alice"], world["team"], "notes.txt", b"Falcon migration plan for spring.", upload_id)
    assert response.status_code == 201
    doc = response.json()
    assert doc["state"] == "ready" and doc["chunks_count"] >= 1 and doc["error_code"] is None
    assert await count_points(doc["id"]) == doc["chunks_count"]

    again = await put(client, world["alice"], world["team"], "notes.txt", b"different bytes entirely", upload_id)
    assert again.status_code == 200 and again.json()["id"] == doc["id"]

    looked_up = await client.get(f"{DOCS}/uploads/{upload_id}", headers=auth_headers(world["alice"], world["team"]))
    assert looked_up.status_code == 200 and looked_up.json()["id"] == doc["id"]
    listing = await client.get(f"{DOCS}/accessible", headers=auth_headers(world["alice"], world["team"]))
    assert [d["id"] for d in listing.json()] == [doc["id"]]
    assert temp_files() == []


async def test_upload_ids_are_private_to_the_uploader(client, world):
    upload_id = str(uuid.uuid4())
    await put(client, world["alice"], world["team"], "a.txt", b"alpha bravo", upload_id)
    response = await client.get(f"{DOCS}/uploads/{upload_id}", headers=auth_headers(world["bob"], world["team"]))
    assert response.status_code == 404


async def test_exact_size_boundary(client, world, monkeypatch):
    monkeypatch.setattr(settings, "MAX_UPLOAD_BYTES", 2048)
    exact = await put(client, world["alice"], world["team"], "exact.txt", b"a " * 1024)
    assert exact.status_code == 201
    over = await put(client, world["alice"], world["team"], "over.txt", b"a " * 1024 + b"b")
    assert over.status_code == 413 and over.json()["detail"]["code"] == "too_large"
    listing = await client.get(f"{DOCS}/accessible", headers=auth_headers(world["alice"], world["team"]))
    assert [d["filename"] for d in listing.json()] == ["exact.txt"]
    assert temp_files() == []


async def test_real_limit_rejects_one_byte_over_25_mib(client, world):
    body = b"x" * (25 * 1024 * 1024 + 1)
    response = await put(client, world["alice"], world["team"], "big.txt", body)
    assert response.status_code == 413
    assert temp_files() == []


async def test_limit_is_enforced_without_content_length(client, world, monkeypatch):
    monkeypatch.setattr(settings, "MAX_UPLOAD_BYTES", 4096)

    async def chunked():
        for _ in range(10):
            yield b"y" * 1024

    response = await put(client, world["alice"], world["team"], "stream.txt", chunked())
    assert response.status_code == 413
    assert temp_files() == []


@pytest.mark.parametrize(
    ("name", "body", "status", "code"),
    [
        ("tool.exe", b"MZ....", 415, "unsupported_type"),
        ("fake.pdf", b"just text pretending", 415, "invalid_content"),
        ("fake.docx", b"not a zip at all", 415, "invalid_content"),
        ("legacy.docx", b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1" + b"\x00" * 64, 422, "encrypted"),
        ("latin1.txt", "café".encode("latin-1"), 415, "unsupported_encoding"),
        ("empty.txt", b"", 422, "empty"),
    ],
)
async def test_content_is_validated_by_bytes_not_by_name(client, world, name, body, status, code):
    response = await put(client, world["alice"], world["team"], name, body)
    assert response.status_code == status
    assert response.json()["detail"]["code"] == code
    assert temp_files() == []


async def test_docx_without_document_part_is_rejected(client, world):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("other.xml", "<x/>")
    response = await put(client, world["alice"], world["team"], "odd.docx", buffer.getvalue())
    assert response.status_code == 415


async def test_encrypted_pdf_fails_with_a_safe_code(client, world):
    response = await put(client, world["alice"], world["team"], "locked.pdf", make_pdf("secret", password="pw"))
    assert response.status_code == 201
    doc = response.json()
    assert doc["state"] == "failed" and doc["error_code"] == "encrypted" and doc["can_retry"] is False


async def test_pdf_citation_keeps_the_real_page_number(client, world):
    response = await put(client, world["alice"], world["team"], "report.pdf", make_pdf("Quarterly heron census results"))
    assert response.json()["state"] == "ready"
    chunks = await client.get(f"{DOCS}/{response.json()['id']}/chunks", headers=auth_headers(world["alice"], world["team"]))
    assert chunks.json()["chunks"][0]["metadata"]["page"] == 1


async def test_filename_is_sanitized_against_traversal(client, world):
    response = await put(client, world["alice"], world["team"], "../../etc/pass\nwd.txt", b"harmless text")
    assert response.status_code == 201
    assert response.json()["filename"] == "pass_wd.txt"


async def test_upload_requires_permission_membership_and_space(client, world):
    assert (await put(client, world["bob"], world["team"], "a.txt", b"x y z")).status_code == 403
    assert (await put(client, world["outsider"], world["team"], "a.txt", b"x y z")).status_code in (403, 404)
    response = await client.put(f"{DOCS}/uploads/{uuid.uuid4()}", params={"filename": "a.txt"}, content=b"x")
    assert response.status_code == 401
    assert temp_files() == []


async def test_documents_stay_in_their_space_and_with_their_readers(client, world):
    doc = (await put(client, world["alice"], world["team"], "plan.txt", b"secret plan words")).json()
    other = await client.get(f"{DOCS}/accessible", headers=auth_headers(world["alice"], world["other"]))
    assert other.json() == []
    for path in (f"{DOCS}/{doc['id']}", f"{DOCS}/{doc['id']}/download", f"{DOCS}/{doc['id']}/chunks"):
        assert (await client.get(path, headers=auth_headers(world["bob"], world["team"]))).status_code == 404
        assert (await client.get(path, headers=auth_headers(world["alice"], world["other"]))).status_code == 404
    admin_view = await client.get(f"{DOCS}/{doc['id']}", headers=auth_headers(world["admin"], world["team"]))
    assert admin_view.status_code == 200


async def test_download_streams_the_original_with_safe_headers(client, world):
    body = "Bilingual نص text\n".encode("utf-8")
    doc = (await put(client, world["alice"], world["team"], "تقرير \"q\".txt", body)).json()
    response = await client.get(f"{DOCS}/{doc['id']}/download", headers=auth_headers(world["alice"], world["team"]))
    assert response.status_code == 200
    assert response.content == body
    assert response.headers["x-content-type-options"] == "nosniff"
    assert "sandbox" in response.headers["content-security-policy"]
    assert response.headers["cache-control"] == "no-store"
    disposition = response.headers["content-disposition"]
    assert '"' not in disposition.split('filename="', 1)[1].rstrip('"').replace('"; filename*', "")
    assert "filename*=UTF-8''" in disposition and "s3://" not in response.text


async def test_indexing_failure_is_reported_and_retry_is_single_and_idempotent(client, world, monkeypatch):
    original = pipeline.index_document

    async def broken(doc):
        raise RuntimeError("embedding failed")

    monkeypatch.setattr(pipeline, "index_document", broken)
    doc = (await put(client, world["alice"], world["team"], "retry.txt", b"Kestrel survey notes")).json()
    assert doc["state"] == "failed" and doc["error_code"] == "indexing_failed" and doc["can_retry"] is True
    assert (await client.post(f"{DOCS}/{doc['id']}/retry", headers=auth_headers(world["bob"], world["team"]))).status_code == 404

    monkeypatch.setattr(pipeline, "index_document", original)
    retried = await client.post(f"{DOCS}/{doc['id']}/retry", headers=auth_headers(world["alice"], world["team"]))
    assert retried.status_code == 200 and retried.json()["state"] == "ready"
    assert await count_points(doc["id"]) == retried.json()["chunks_count"]

    again = await client.post(f"{DOCS}/{doc['id']}/retry", headers=auth_headers(world["alice"], world["team"]))
    assert again.status_code == 409
    reindexed = await client.post(f"{DOCS}/vectorize/{doc['id']}", headers=auth_headers(world["alice"], world["team"]))
    assert reindexed.status_code == 200
    assert await count_points(doc["id"]) == retried.json()["chunks_count"]


async def test_only_one_concurrent_retry_claim_wins(client, world, factory, session_factory):
    doc = (await put(client, world["alice"], world["team"], "claim.txt", b"Osprey data")).json()
    await factory.execute("UPDATE documents SET state = 'failed', state_error = 'timeout' WHERE id = :d", d=doc["id"])
    async with session_factory() as first, session_factory() as second:
        assert await pipeline.claim_for_retry(first, doc["id"]) is True
        assert await pipeline.claim_for_retry(second, doc["id"]) is False


async def test_abandoned_processing_is_reported_as_interrupted(client, world, factory):
    doc = (await put(client, world["alice"], world["team"], "lost.txt", b"Plover notes")).json()
    old = datetime.utcnow() - timedelta(seconds=pipeline.lease_seconds() + 5)
    await factory.execute(
        "UPDATE documents SET state = 'processing', state_updated_at = :t WHERE id = :d", t=old, d=doc["id"]
    )
    view = (await client.get(f"{DOCS}/{doc['id']}", headers=auth_headers(world["alice"], world["team"]))).json()
    assert view["state"] == "failed" and view["error_code"] == "interrupted" and view["can_retry"] is True


async def test_extraction_timeout_fails_cleanly(client, world, monkeypatch):
    monkeypatch.setattr(settings, "PROCESSING_TIMEOUT_SECONDS", 0)
    doc = (await put(client, world["alice"], world["team"], "slow.txt", b"Grebe text")).json()
    assert doc["state"] == "failed" and doc["error_code"] == "timeout"
    assert temp_files() == []


async def test_legacy_multipart_upload_still_works_and_is_capped(client, world, monkeypatch):
    files = {"file": ("legacy.txt", b"Web upload of tern counts", "text/plain")}
    response = await client.post(f"{DOCS}/upload-and-vectorize", files=files, headers=auth_headers(world["alice"], world["team"]))
    assert response.status_code == 201
    assert response.json()["upload"]["status"] == "completed"

    monkeypatch.setattr(settings, "MAX_UPLOAD_BYTES", 1024)
    big = {"file": ("big.txt", b"z" * (200 * 1024), "text/plain")}
    response = await client.post(f"{DOCS}/upload-and-vectorize", files=big, headers=auth_headers(world["alice"], world["team"]))
    assert response.status_code == 413
