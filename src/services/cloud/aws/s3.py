"""AWS S3 storage service with prefix helpers."""

from pathlib import Path
from typing import Optional

import aioboto3
from botocore.exceptions import ClientError

from src.core.settings.config import settings
from src.core.settings.logging import logger


class S3Service:
    """AWS S3 file storage service."""

    def __init__(self):
        self.session = aioboto3.Session(
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_REGION,
        )
        self.bucket = settings.AWS_S3_BUCKET
        self.endpoint_url = (getattr(settings, "AWS_S3_ENDPOINT_URL", "") or "").strip() or None

    def client(self):
        return self.session.client("s3", endpoint_url=self.endpoint_url)

    @staticmethod
    def parse_url(s3_url: str) -> tuple[str, str]:
        """Split s3://bucket/key; raises ValueError for anything else."""
        value = (s3_url or "").strip()
        if not value.startswith("s3://"):
            raise ValueError("Not an s3:// URL")
        bucket, _, key = value[len("s3://"):].partition("/")
        if not bucket or not key:
            raise ValueError("Incomplete s3:// URL")
        return bucket, key

    async def download_to_file(self, s3_url: str, target: Path) -> None:
        bucket, key = self.parse_url(s3_url)
        async with self.client() as s3:
            await s3.download_file(bucket, key, str(target))

    async def iter_object(self, s3_url: str, chunk_size: int = 64 * 1024):
        """Yield the object's bytes in chunks; the connection closes when iteration ends."""
        bucket, key = self.parse_url(s3_url)
        async with self.client() as s3:
            obj = await s3.get_object(Bucket=bucket, Key=key)
            body = obj["Body"]
            try:
                while True:
                    chunk = await body.read(chunk_size)
                    if not chunk:
                        break
                    yield chunk
            finally:
                body.close()

    async def upload_file(self, file_path: Path, s3_key: str, *, bucket: Optional[str] = None) -> str:
        """Upload file to S3.
        
        Args:
            file_path: Local file path
            s3_key: S3 object key
            
        Returns:
            S3 URL of uploaded file
            
        Raises:
            ClientError: If upload fails
        """
        target_bucket = bucket or self.bucket
        if not target_bucket:
            raise ValueError("Target bucket is required for upload")
        logger.debug("Uploading file to S3", extra={"bucket": target_bucket, "key": s3_key, "path": str(file_path)})
        async with self.client() as s3:
            try:
                await s3.upload_file(
                    str(file_path),
                    target_bucket,
                    s3_key,
                    ExtraArgs={"ContentType": self._get_content_type(file_path)},
                )
            except ClientError as exc:
                code = (exc.response or {}).get("Error", {}).get("Code")
                if code in {"NoSuchBucket", "404"}:
                    # Best-effort: create missing bucket and retry once.
                    logger.warning("Bucket missing during upload; attempting to create", extra={"bucket": target_bucket})
                    if await self.create_bucket(target_bucket):
                        await s3.upload_file(
                            str(file_path),
                            target_bucket,
                            s3_key,
                            ExtraArgs={"ContentType": self._get_content_type(file_path)},
                        )
                    elif self.bucket and self.bucket != target_bucket:
                        # Fallback to shared bucket if per-space bucket cannot be created.
                        target_bucket = self.bucket
                        logger.warning(
                            "Falling back to shared bucket for upload",
                            extra={"bucket": target_bucket, "key": s3_key},
                        )
                        await s3.upload_file(
                            str(file_path),
                            target_bucket,
                            s3_key,
                            ExtraArgs={"ContentType": self._get_content_type(file_path)},
                        )
                    else:
                        raise
                else:
                    raise
        url = f"s3://{target_bucket}/{s3_key}"
        logger.debug("Uploaded file to S3", extra={"url": url})
        return url

    async def bucket_exists(self, bucket: str) -> bool:
        if not bucket:
            return False
        async with self.client() as s3:
            try:
                await s3.head_bucket(Bucket=bucket)
                return True
            except ClientError:
                return False

    async def create_bucket(self, bucket: str) -> bool:
        """Best-effort bucket creation.

        Many environments will not grant bucket-creation permissions; callers should treat
        failures as non-fatal and provision buckets via infra/terraform.
        """
        if not bucket:
            raise ValueError("Bucket name is required")
        logger.debug("Ensuring bucket exists", extra={"bucket": bucket})
        async with self.client() as s3:
            try:
                await s3.head_bucket(Bucket=bucket)
                logger.debug("Bucket already exists", extra={"bucket": bucket})
                return True
            except ClientError:
                logger.info("Bucket not found; attempting to create", extra={"bucket": bucket})

            # Some S3-compatible providers (e.g. MinIO) can reject CreateBucketConfiguration.
            # Try the AWS-style call first, then fall back to a minimal create_bucket.
            params = {"Bucket": bucket}
            if (settings.AWS_REGION or "").strip() and settings.AWS_REGION != "us-east-1":
                params["CreateBucketConfiguration"] = {"LocationConstraint": settings.AWS_REGION}

            try:
                await s3.create_bucket(**params)
                logger.info("Created bucket", extra={"bucket": bucket, "params": list(params.keys())})
                return True
            except Exception as exc:  # noqa: BLE001
                try:
                    await s3.create_bucket(Bucket=bucket)
                    logger.info("Created bucket using fallback call", extra={"bucket": bucket})
                    return True
                except Exception as fallback_exc:  # noqa: BLE001
                    logger.error(
                        "Failed to create bucket",
                        extra={"bucket": bucket, "error": str(exc), "fallback_error": str(fallback_exc)},
                    )
                    return False

    async def delete_file(self, s3_key: str) -> None:
        """Delete file from S3.
        
        Args:
            s3_key: S3 object key
        """
        async with self.client() as s3:
            await s3.delete_object(Bucket=self.bucket, Key=s3_key)
        logger.debug("Deleted S3 object", extra={"bucket": self.bucket, "key": s3_key})

    async def ensure_prefix(self, bucket: str, prefix: str) -> None:
        """Create an empty object to materialize a folder-like prefix."""

        normalized = prefix.strip("/")
        if not normalized:
            return
        key = f"{normalized}/"
        async with self.client() as s3:
            try:
                await s3.put_object(Bucket=bucket, Key=key, Body=b"")
                logger.debug("Ensured S3 prefix", extra={"bucket": bucket, "prefix": key})
            except ClientError as exc:
                logger.warning("Failed to create S3 prefix", extra={"bucket": bucket, "prefix": key, "error": str(exc)})

    @staticmethod
    def _get_content_type(file_path: Path) -> str:
        """Get content type from file extension."""
        content_types = {
            ".pdf": "application/pdf",
            ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            ".csv": "text/csv",
            ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            ".txt": "text/plain",
        }
        return content_types.get(file_path.suffix.lower(), "application/octet-stream")


s3_service = S3Service()