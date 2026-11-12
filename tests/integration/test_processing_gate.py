"""MAX_CONCURRENT_DOCUMENT_PROCESSING: one active processing operation across upload, retry and re-index routes."""

import asyncio
import uuid

import pytest

from src.core.settings.config import settings
from src.modules.apis.v1.documents import pipeline

from tests.conftest import auth_headers
from tests.integration.test_documents import DOCS, put, world  # noqa: F401  (fixture)


class Hold:
    """Makes pipeline.process wait until released, so overlapping requests really overlap."""

    def __init__(self, monkeypatch):
        self.entered = asyncio.Event()
        self.release = asyncio.Event()
        self.active = 0
        self.peak = 0
        original = pipeline.process

        async def held(db, doc, path, ext):
            self.active += 1
            self.peak = max(self.peak, self.active)
            self.entered.set()
            try:
                await self.release.wait()
                return await original(db, doc, path, ext)
            finally:
                self.active -= 1

        monkeypatch.setattr(pipeline, "process", held)


@pytest.fixture
def one_at_a_time(monkeypatch):
    monkeypatch.setattr(settings, "MAX_CONCURRENT_DOCUMENT_PROCESSING", 1)


async def test_concurrent_uploads_process_one_and_refuse_the_rest(client, world, monkeypatch, one_at_a_time):
    hold = Hold(monkeypatch)
    headers = auth_headers(world["alice"], world["team"])
    first_id = str(uuid.uuid4())
    first = asyncio.create_task(put(client, world["alice"], world["team"], "a.txt", b"Heron counts north", first_id))
    await asyncio.wait_for(hold.entered.wait(), 10)

    refused_ids = [str(uuid.uuid4()) for _ in range(3)]
    refused = await asyncio.gather(*(
        put(client, world["alice"], world["team"], f"b{i}.txt", f"Egret counts {i}".encode(), uid)
        for i, uid in enumerate(refused_ids)
    ))
    for response in refused:
        assert response.status_code == 503
        assert response.json()["detail"]["code"] == "processing_busy"
        assert response.headers["retry-after"] == "30"
    # Refused uploads stored nothing: no receipt, so the same upload ID can simply be sent again.
    for uid in refused_ids:
        assert (await client.get(f"{DOCS}/uploads/{uid}", headers=headers)).status_code == 404

    hold.release.set()
    done = await first
    assert done.status_code == 201 and done.json()["state"] == "ready"
    assert hold.peak == 1

    again = await put(client, world["alice"], world["team"], "b0.txt", b"Egret counts 0", refused_ids[0])
    assert again.status_code == 201 and again.json()["state"] == "ready"


async def test_retry_and_reindex_wait_for_the_same_slot(client, world, monkeypatch, factory, one_at_a_time):
    doc = (await put(client, world["alice"], world["team"], "r.txt", b"Ibis notes")).json()
    await factory.execute("UPDATE documents SET state = 'failed', state_error = 'timeout' WHERE id = :d", d=doc["id"])
    headers = auth_headers(world["alice"], world["team"])

    hold = Hold(monkeypatch)
    busy_upload = asyncio.create_task(put(client, world["alice"], world["team"], "busy.txt", b"Spoonbill notes"))
    await asyncio.wait_for(hold.entered.wait(), 10)

    retry = await client.post(f"{DOCS}/{doc['id']}/retry", headers=headers)
    assert retry.status_code == 503 and retry.json()["detail"]["code"] == "processing_busy"
    # The refused retry did not claim the document: it is still retryable afterwards.
    view = (await client.get(f"{DOCS}/{doc['id']}", headers=headers)).json()
    assert view["state"] == "failed" and view["can_retry"] is True
    reindex = await client.post(f"{DOCS}/vectorize/{doc['id']}", headers=headers)
    assert reindex.status_code == 503

    hold.release.set()
    assert (await busy_upload).status_code == 201
    retried = await client.post(f"{DOCS}/{doc['id']}/retry", headers=headers)
    assert retried.status_code == 200 and retried.json()["state"] == "ready"


async def test_a_failure_inside_processing_releases_the_slot(client, world, monkeypatch, one_at_a_time):
    async def explode(db, doc, path, ext):
        raise RuntimeError("extractor crashed")

    monkeypatch.setattr(pipeline, "process", explode)
    with pytest.raises(RuntimeError):
        await put(client, world["alice"], world["team"], "x.txt", b"Avocet notes")
    monkeypatch.undo()
    monkeypatch.setattr(settings, "MAX_CONCURRENT_DOCUMENT_PROCESSING", 1)
    ok = await put(client, world["alice"], world["team"], "y.txt", b"Stilt notes")
    assert ok.status_code == 201


async def test_the_cap_allows_exactly_n(client, world, monkeypatch):
    monkeypatch.setattr(settings, "MAX_CONCURRENT_DOCUMENT_PROCESSING", 2)
    hold = Hold(monkeypatch)
    tasks = [asyncio.create_task(put(client, world["alice"], world["team"], f"n{i}.txt", f"Curlew {i}".encode())) for i in range(2)]
    for _ in range(50):
        if hold.active == 2:
            break
        await asyncio.sleep(0.05)
    third = await put(client, world["alice"], world["team"], "n3.txt", b"Curlew 3")
    assert third.status_code == 503
    hold.release.set()
    assert [r.status_code for r in await asyncio.gather(*tasks)] == [201, 201]
    assert hold.peak == 2


async def test_zero_means_unlimited(client, world, monkeypatch):
    monkeypatch.setattr(settings, "MAX_CONCURRENT_DOCUMENT_PROCESSING", 0)
    hold = Hold(monkeypatch)
    tasks = [asyncio.create_task(put(client, world["alice"], world["team"], f"u{i}.txt", f"Godwit {i}".encode())) for i in range(3)]
    for _ in range(50):
        if hold.active == 3:
            break
        await asyncio.sleep(0.05)
    assert hold.active == 3
    hold.release.set()
    assert {r.status_code for r in await asyncio.gather(*tasks)} == {201}
