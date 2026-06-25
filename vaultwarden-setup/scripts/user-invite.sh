#!/bin/sh
set -eu

# Usage: user-invite.sh <name> <email> <master_password_hash>
#
# The master password hash should be generated with:
#   bw hash --hashmethod pbkdf2 --masterpassword "plaintext_password"
#
# This script logs into the Vaultwarden admin API (cookie-based auth)
# and creates a user via the /admin/invite endpoint.
#
# Requires:
#   VAULTWARDEN_URL    — base URL, e.g. https://warden.example.com
#   VAULTWARDEN_ADMIN_TOKEN — admin token (loaded from .env or exported)

if [ $# -ne 3 ]; then
  echo "Usage: $0 <name> <email> <master_password_hash>"
  exit 1
fi

# Load .env if present
if [ -f "$(dirname "$0")/.env" ]; then
  . "$(dirname "$0")/.env"
fi

if [ -z "${VAULTWARDEN_URL:-}" ]; then
  echo "Error: VAULTWARDEN_URL not set"
  echo "  Set it in .env or export it"
  exit 1
fi

NAME="$1"
EMAIL="$2"
HASH="$3"

if [ -z "${VAULTWARDEN_ADMIN_TOKEN:-}" ]; then
  echo "Error: VAULTWARDEN_ADMIN_TOKEN not set"
  echo "  Set it in .env or export it"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COOKIE_FILE=$(mktemp)
trap 'rm -f "$COOKIE_FILE"' EXIT

# Step 1: Login to get session cookie
curl -s -c "$COOKIE_FILE" -X POST "$VAULTWARDEN_URL/admin" \
  -d "token=$VAULTWARDEN_ADMIN_TOKEN&redirect=/admin/users" > /dev/null

# Step 2: Create user via invite endpoint
curl -s -b "$COOKIE_FILE" -X POST "$VAULTWARDEN_URL/admin/invite" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"name\":\"$NAME\",\"masterPasswordHash\":\"$HASH\"}"
