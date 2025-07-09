#!/bin/bash
# local build script, not reusable
set -e

BUCKET="583168578067-heart-app"
DISTRIBUTION_ID="E2QX06VIJT572Y"

flutter build web --release --dart-define-from-file="env/new-dev.json"
aws s3 sync build/web "s3://$BUCKET" --delete --profile personal

echo "Invalidating CloudFront cache..."
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID \
  --paths "/*" \
  --profile personal \
  >/dev/null

echo "Deployment complete!"