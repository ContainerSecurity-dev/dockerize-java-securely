#!/usr/bin/env bash
set -euo pipefail
image=${1:?Usage: scripts/smoke-test.sh IMAGE}
container=$(docker run --detach --rm --read-only --tmpfs /tmp --cap-drop ALL \
  --security-opt no-new-privileges:true -p 127.0.0.1::8080 "$image")
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
port=$(docker port "$container" 8080/tcp | sed 's/.*://')
for attempt in {1..60}; do
  if response=$(curl -fsS "http://127.0.0.1:$port/" 2>/dev/null); then
    test "$response" = 'Hello, Docker Security!'
    printf '%s\n' "$response"
    docker inspect --format 'Runtime user: {{.Config.User}}' "$container"
    exit 0
  fi
  sleep 1
done
docker logs "$container"
exit 1
