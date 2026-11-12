#!/bin/sh
# Single-node SeaweedFS with the S3 gateway. The S3 identity comes from the environment (teia-staging.env)
# and is written to a file only inside the container's tmpfs-like /tmp; it is never logged.
set -eu
umask 077
: "${S3_ACCESS_KEY:?S3_ACCESS_KEY is required}"
: "${S3_SECRET_KEY:?S3_SECRET_KEY is required}"
cat > /tmp/s3.json <<JSON
{"identities": [{"name": "teia-staging-api",
  "credentials": [{"accessKey": "${S3_ACCESS_KEY}", "secretKey": "${S3_SECRET_KEY}"}],
  "actions": ["Admin", "Read", "List", "Tagging", "Write"]}]}
JSON
exec weed server -dir=/data -ip.bind=0.0.0.0 -master.volumeSizeLimitMB=1024 -volume.max=0 \
  -s3 -s3.port=8333 -s3.config=/tmp/s3.json
