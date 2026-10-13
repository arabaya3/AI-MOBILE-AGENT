"""Documents over the real routes: extraction subprocess, local S3 (moto), Qdrant local mode, stub embeddings."""

import asyncio
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

    again = await put(client, world["alice"], world["team"], "notes.txt", b"Falcon migration plan for spring.", upload_id)
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


# --- Deduplication never grants access; every accepted upload ID has a receipt -------------------


async def uploader(factory, world, email):
    user = await factory.user(email)
    await factory.member(world["team"], user)
    await factory.execute("UPDATE space_members SET can_upload_documents = true WHERE user_id = :u", u=user.id)
    return user


async def permission_count(factory, user) -> int:
    result = await factory.execute("SELECT count(*) FROM user_document_permissions WHERE user_id = :u", u=user.id)
    return result.scalar()


def assert_reveals_nothing(response, doc):
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "duplicate_conflict"
    assert doc["id"] not in response.text and doc["filename"] not in response.text


async def test_identical_bytes_of_an_inaccessible_document_are_refused(client, world, factory):
    carol = await uploader(factory, world, "carol@example.com")
    doc = (await put(client, world["alice"], world["team"], "secret-plan.txt", b"Merger terms draft v3")).json()
    before = await permission_count(factory, carol)

    response = await put(client, carol, world["team"], "mine.txt", b"Merger terms draft v3")
    assert_reveals_nothing(response, doc)
    assert await permission_count(factory, carol) == before
    listing = await client.get(f"{DOCS}/accessible", headers=auth_headers(carol, world["team"]))
    assert listing.json() == []


async def test_identical_bytes_after_revocation_are_refused_and_old_receipts_stop_resolving(client, world, factory):
    carol = await uploader(factory, world, "carol@example.com")
    doc = (await put(client, world["alice"], world["team"], "plan.txt", b"Shared roadmap 2027")).json()
    await client.post(
        f"{DOCS}/permissions",
        json={"user_id": carol.id, "document_ids": [doc["id"]]},
        headers=auth_headers(world["admin"], world["team"]),
    )
    first_id = str(uuid.uuid4())
    authorized = await put(client, carol, world["team"], "copy.txt", b"Shared roadmap 2027", first_id)
    assert authorized.status_code == 200 and authorized.json()["id"] == doc["id"]
    resolved = await client.get(f"{DOCS}/uploads/{first_id}", headers=auth_headers(carol, world["team"]))
    assert resolved.status_code == 200 and resolved.json()["id"] == doc["id"]

    await client.request(
        "DELETE",
        f"{DOCS}/permissions",
        json={"user_id": carol.id, "document_ids": [doc["id"]]},
        headers=auth_headers(world["admin"], world["team"]),
    )
    after = await put(client, carol, world["team"], "copy.txt", b"Shared roadmap 2027")
    assert_reveals_nothing(after, doc)
    replayed = await put(client, carol, world["team"], "copy.txt", b"Shared roadmap 2027", first_id)
    assert_reveals_nothing(replayed, doc)
    stale = await client.get(f"{DOCS}/uploads/{first_id}", headers=auth_headers(carol, world["team"]))
    assert stale.status_code == 404 and doc["id"] not in stale.text
    assert await permission_count(factory, carol) == 0


async def test_authorized_duplicate_gets_its_own_receipt_without_changing_the_original(client, world, factory):
    original_id = str(uuid.uuid4())
    doc = (await put(client, world["alice"], world["team"], "report.txt", b"Annual report text", original_id)).json()
    duplicate_id = str(uuid.uuid4())
    duplicate = await put(client, world["alice"], world["team"], "report-again.txt", b"Annual report text", duplicate_id)
    assert duplicate.status_code == 200 and duplicate.json()["id"] == doc["id"]

    # A lost response is reconciled through the duplicate's own upload ID.
    for upload_id in (original_id, duplicate_id):
        found = await client.get(f"{DOCS}/uploads/{upload_id}", headers=auth_headers(world["alice"], world["team"]))
        assert found.status_code == 200 and found.json()["id"] == doc["id"]
    row = (await factory.execute("SELECT filename, uploaded_by_user_id FROM documents WHERE id = :d", d=doc["id"])).one()
    assert tuple(row) == ("report.txt", world["alice"].id)
    receipts = await factory.execute("SELECT count(*) FROM document_upload_receipts WHERE document_id = :d", d=doc["id"])
    assert receipts.scalar() == 2


async def test_an_upload_id_reused_for_different_content_is_refused(client, world):
    upload_id = str(uuid.uuid4())
    first = await put(client, world["alice"], world["team"], "a.txt", b"first content here", upload_id)
    assert first.status_code == 201
    other = await put(client, world["alice"], world["team"], "b.txt", b"completely different content", upload_id)
    assert other.status_code == 409 and other.json()["detail"]["code"] == "upload_id_reused"
    same = await put(client, world["alice"], world["team"], "a.txt", b"first content here", upload_id)
    assert same.status_code == 200 and same.json()["id"] == first.json()["id"]
    listing = await client.get(f"{DOCS}/accessible", headers=auth_headers(world["alice"], world["team"]))
    assert len(listing.json()) == 1


async def test_receipts_are_isolated_per_user_and_space(client, world, factory):
    carol = await uploader(factory, world, "carol@example.com")
    upload_id = str(uuid.uuid4())
    await put(client, world["alice"], world["team"], "a.txt", b"isolated receipt text", upload_id)
    for user, space in ((carol, world["team"]), (world["admin"], world["team"]), (world["alice"], world["other"])):
        response = await client.get(f"{DOCS}/uploads/{upload_id}", headers=auth_headers(user, space))
        assert response.status_code == 404

    # The same upload ID used by another uploader is an independent upload, not a replay.
    theirs = await put(client, carol, world["team"], "c.txt", b"carol has different text", upload_id)
    assert theirs.status_code == 201


async def test_concurrent_identical_uploads_never_grant_access(client, world, factory):
    carol = await uploader(factory, world, "carol@example.com")
    body = b"Concurrent identical body " * 20
    responses = await asyncio.gather(
        put(client, world["alice"], world["team"], "a.txt", body),
        put(client, carol, world["team"], "c.txt", body),
    )
    assert sorted(r.status_code for r in responses) == [201, 409]
    loser = next(r for r in responses if r.status_code == 409)
    assert loser.json()["detail"]["code"] == "duplicate_conflict"
    winner = next(r for r in responses if r.status_code == 201).json()
    other = carol if winner["uploaded_by_user_id"] == world["alice"].id else world["alice"]
    assert (await client.get(f"{DOCS}/{winner['id']}", headers=auth_headers(other, world["team"]))).status_code == 404
    assert await permission_count(factory, other) == 0


async def test_concurrent_identical_uploads_by_one_reader_share_the_document(client, world):
    body = b"Same reader, two upload IDs " * 20
    ids = [str(uuid.uuid4()), str(uuid.uuid4())]
    responses = await asyncio.gather(*(put(client, world["alice"], world["team"], "a.txt", body, i) for i in ids))
    assert sorted(r.status_code for r in responses) == [200, 201]
    assert len({r.json()["id"] for r in responses}) == 1
    for upload_id in ids:
        found = await client.get(f"{DOCS}/uploads/{upload_id}", headers=auth_headers(world["alice"], world["team"]))
        assert found.status_code == 200


async def test_legacy_multipart_duplicates_follow_the_same_rule(client, world, factory):
    carol = await uploader(factory, world, "carol@example.com")
    doc = (await put(client, world["alice"], world["team"], "x.txt", b"Legacy duplicate body")).json()
    files = {"file": ("y.txt", b"Legacy duplicate body", "text/plain")}
    response = await client.post(f"{DOCS}/upload", files=files, headers=auth_headers(carol, world["team"]))
    assert response.status_code == 409
    assert doc["id"] not in response.text
    assert await permission_count(factory, carol) == 0
