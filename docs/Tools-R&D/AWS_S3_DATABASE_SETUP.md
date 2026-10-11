# Document Upload with AWS S3 & Database Storage

## 🔐 Required AWS Credentials

Add these to your `.env` file:

```env
# AWS S3 Configuration
AWS_ACCESS_KEY_ID=AKIA...              # Your AWS Access Key ID
AWS_SECRET_ACCESS_KEY=abc123...        # Your AWS Secret Access Key
AWS_REGION=us-east-1                   # AWS Region where bucket exists
AWS_S3_BUCKET=my-documents-bucket      # Your S3 bucket name

# PostgreSQL Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=Lex-Tech_agents
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password
```

---

## 📋 AWS Setup Steps

### 1. Create S3 Bucket

```bash
aws s3 mb s3://my-documents-bucket --region us-east-1
```

### 2. Create IAM User with S3 Permissions

**Required Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-documents-bucket/*",
        "arn:aws:s3:::my-documents-bucket"
      ]
    }
  ]
}
```

### 3. Get Access Keys

1. Go to IAM Console → Users → Your User → Security credentials
2. Create access key → Application running outside AWS
3. Copy `Access Key ID` and `Secret Access Key`

---

## 🗄️ Database Setup

### PostgreSQL with Docker

```bash
docker run -d \
  --name Lex-Tech-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=Lex-Tech_agents \
  -p 5432:5432 \
  postgres:16-alpine
```

### Or using Docker Compose

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: Lex-Tech_agents
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

---

## 🚀 Start the Application

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Edit .env with your credentials
nano .env

# 3. Install dependencies
poetry install

# 4. Start server (auto-creates DB tables)
python run.py
```

Server: http://localhost:8000
API Docs: http://localhost:8000/docs

---

## 📤 Upload Documents

### Single Upload

```bash
curl -X POST "http://localhost:8000/api/v1/documents/upload" \
  -F "file=@document.pdf"
```

**Response:**
```json
{
  "document_id": "550e8400-e29b-41d4-a716-446655440000",
  "filename": "document.pdf",
  "file_type": "pdf",
  "file_size": 204800,
  "status": "completed",
  "chunks_count": 15,
  "uploaded_at": "2025-01-20T10:30:00Z",
  "message": "Document processed successfully"
}
```

### Multiple Upload

```bash
curl -X POST "http://localhost:8000/api/v1/documents/upload-multiple" \
  -F "files=@doc1.pdf" \
  -F "files=@sheet.xlsx" \
  -F "files=@presentation.pptx"
```

### Python Client

```python
import requests

# Single upload
with open("document.pdf", "rb") as f:
    response = requests.post(
        "http://localhost:8000/api/v1/documents/upload",
        files={"file": f}
    )
    print(response.json())

# Multiple upload
files = [
    ("files", open("doc1.pdf", "rb")),
    ("files", open("doc2.xlsx", "rb")),
]
response = requests.post(
    "http://localhost:8000/api/v1/documents/upload-multiple",
    files=files
)
```

---

## 💾 Data Storage

### S3 Storage
- **Path:** `s3://your-bucket/documents/{document_id}.{ext}`
- **Example:** `s3://my-docs/documents/550e8400-e29b-41d4-a716-446655440000.pdf`

### Database Storage (PostgreSQL)

**Table: `documents`**

| Column | Type | Description |
|--------|------|-------------|
| id | String (PK) | Document UUID |
| filename | String | Original filename |
| file_type | String | pdf/docx/xlsx/csv/pptx/txt |
| file_size | Integer | Size in bytes |
| file_hash | String (Unique) | SHA-256 hash |
| s3_url | String | S3 storage URL |
| status | String | completed/failed/processing |
| chunks_count | Integer | Number of chunks extracted |
| chunks_data | JSON | Array of extracted chunks |
| processing_time | Integer | Processing time in ms |
| error_message | Text | Error details (if failed) |
| uploaded_at | DateTime | Upload timestamp |
| processed_at | DateTime | Processing completion time |

### Query Database

```python
from sqlalchemy import select
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import Document

async with get_db() as db:
    # Get all documents
    result = await db.execute(select(Document))
    docs = result.scalars().all()
    
    # Get by ID
    result = await db.execute(
        select(Document).where(Document.id == "doc-id-here")
    )
    doc = result.scalar_one_or_none()
    
    # Get by hash (check duplicates)
    result = await db.execute(
        select(Document).where(Document.file_hash == "sha256-hash")
    )
    existing = result.scalar_one_or_none()
```

---

## 🏗️ Architecture

```
Upload Request
    ↓
[1] Validate file type
    ↓
[2] Generate UUID
    ↓
[3] Save to local temp → /data/documents/{uuid}.{ext}
    ↓
[4] Upload to S3 → s3://bucket/documents/{uuid}.{ext}
    ↓
[5] Process document → Extract chunks
    ↓
[6] Save to PostgreSQL → Store metadata + chunks + S3 URL
    ↓
[7] Delete local temp file
    ↓
Response with document_id
```

---

## 📊 File Processing

### Supported Formats

| Format | Extension | Chunks |
|--------|-----------|--------|
| PDF | .pdf | Pages/sections |
| Word | .docx | Paragraphs |
| Excel | .xlsx | Sheets |
| CSV | .csv | Full data |
| PowerPoint | .pptx | Slides |
| Text | .txt | Paragraphs |

### Chunk Structure

```json
{
  "text": "Extracted content here...",
  "metadata": {
    "type": "paragraph|page|sheet|slide",
    "page": 1,
    "index": 0
  }
}
```

---

## 🔧 Configuration

### Change S3 Bucket

Edit `.env`:
```env
AWS_S3_BUCKET=new-bucket-name
```

### Change S3 Path Structure

Edit `src/services/cloud/aws/s3.py` line 37:
```python
s3_key = f"documents/{document_id}{file_ext}"  # Change path here
```

### Change Database Schema

Edit `src/services/databases/postgresql/models.py` to add fields.

---

## ✅ Verification

### Check S3 Upload

```bash
aws s3 ls s3://my-documents-bucket/documents/
```

### Check Database

```bash
docker exec -it Lex-Tech-postgres psql -U postgres -d Lex-Tech_agents

# Query documents
SELECT id, filename, file_type, status, chunks_count 
FROM documents 
ORDER BY uploaded_at DESC 
LIMIT 10;
```

---

## 🐛 Troubleshooting

**Error: S3 Access Denied**
- Check IAM user has correct permissions
- Verify bucket name matches `.env`
- Ensure credentials are correct

**Error: Database Connection Failed**
- Check PostgreSQL is running: `docker ps`
- Verify credentials in `.env`
- Test connection: `psql -h localhost -U postgres -d Lex-Tech_agents`

**Error: File Processing Failed**
- Check file format is supported
- Verify file is not corrupted
- Check logs for specific error

---

## 📈 What You Get

✅ **Upload to S3**: Files stored in AWS S3 with proper content types
✅ **Database Storage**: Full metadata + extracted chunks in PostgreSQL
✅ **Duplicate Detection**: SHA-256 hashing prevents duplicate uploads
✅ **Chunk Extraction**: Intelligent text extraction per format
✅ **Clean Architecture**: Service layer, handlers, models separated
✅ **Minimal Code**: ~500 LOC total with best practices
✅ **Production Ready**: Async/await, error handling, type hints

---

**Status**: ✅ Production Ready
**LOC Added**: ~200 lines (S3 service + DB models + updates)
**Dependencies**: aioboto3, asyncpg, sqlalchemy
