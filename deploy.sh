#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_PORT=$(grep -E '^APP_PORT=' .env 2>/dev/null | cut -d= -f2- || true)
APP_PORT=${APP_PORT:-2002}
URL="http://127.0.0.1:${APP_PORT}/"

echo "==> pull"
BEFORE=$(git rev-parse --short HEAD)
git pull --ff-only
AFTER=$(git rev-parse --short HEAD)

if [ "$BEFORE" = "$AFTER" ]; then
  echo "    already at $AFTER"
else
  echo "    $BEFORE -> $AFTER"
  git --no-pager log --oneline "$BEFORE..$AFTER" | sed 's/^/    /'
  if ! git diff --quiet "$BEFORE" "$AFTER" -- docker-compose.yml; then
    echo "    NOTE: docker-compose.yml changed"
  fi
fi

echo "==> tag rollback point"
if docker image inspect memory-game:latest >/dev/null 2>&1; then
  docker image tag memory-game:latest memory-game:previous
  echo "    memory-game:previous"
else
  echo "    no existing image, skipping"
fi

echo "==> build"
docker compose build app

echo "==> swap"
docker compose up -d --no-deps app

echo "==> health"
CODE=""
for i in $(seq 1 30); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "$URL" || true)
  if [ "$CODE" = "200" ]; then
    echo "    200 after ${i}s"
    docker compose ps
    echo
    echo "deployed $AFTER"
    exit 0
  fi
  sleep 1
done

echo "    FAILED - last status: ${CODE:-no response}"
echo
docker compose logs --tail=40 app
echo
echo "roll back with:"
echo "    docker image tag memory-game:previous memory-game:latest"
echo "    docker compose up -d --no-deps app"
exit 1
