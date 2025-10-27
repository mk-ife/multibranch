#!/usr/bin/env bash
set -euo pipefail
NAME="${1:?Usage: put-ssh-key.sh <COMPOSE_PROJECT_NAME> [container=odoo] [user=root] [key=~/.ssh/id_ed25519_ife]}"
CTR="${2:-odoo}"
USR="${3:-root}"
KEY="${4:-$HOME/.ssh/id_ed25519_ife}"

if [ ! -s "$KEY" ]; then echo "Key not found: $KEY"; exit 1; fi

CID="$(docker compose -p "$NAME" ps -q "$CTR")"
[ -n "$CID" ] || { echo "Container not found: $NAME/$CTR"; exit 1; }

docker exec "$CID" sh -lc "mkdir -p /$USR/.ssh && chmod 700 /$USR/.ssh && chown -R $USR:$USR /$USR/.ssh"
docker cp "$KEY"        "$CID:/$USR/.ssh/id_ed25519"
docker cp "$KEY.pub"    "$CID:/$USR/.ssh/id_ed25519.pub"

docker exec "$CID" sh -lc "chmod 600 /$USR/.ssh/id_ed25519 && chown $USR:$USR /$USR/.ssh/id_ed25519 /$USR/.ssh/id_ed25519.pub"

# optional: SSH Config für GitHub
docker exec "$CID" sh -lc "cat > /$USR/.ssh/config <<CFG
Host github.com
  HostName github.com
  User git
  IdentityFile /$USR/.ssh/id_ed25519
  StrictHostKeyChecking accept-new
CFG
chmod 600 /$USR/.ssh/config && chown $USR:$USR /$USR/.ssh/config"
echo "OK: key deployed to $NAME/$CTR as $USR"
