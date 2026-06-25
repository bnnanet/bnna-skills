#!/bin/sh
set -e
set -u

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

fn_usage() {
   echo "Usage: $(basename "$0") <name> <email> <master_password_hash>"
}

fn_main() {
   g_name="${1:-}"
   g_email="${2:-}"
   g_hash="${3:-}"

   if test -z "${g_name}" || test -z "${g_email}" || test -z "${g_hash}"; then
      fn_usage >&2
      exit 1
   fi

   # Load .env if present
   b_script_dir="$(cd "$(dirname "$0")" && pwd)"
   if test -f "${b_script_dir}/.env"; then
      . "${b_script_dir}/.env"
   fi

   if test -z "${VAULTWARDEN_URL:-}"; then
      echo "Error: VAULTWARDEN_URL not set" >&2
      echo "  Set it in .env or export it" >&2
      exit 1
   fi

   if test -z "${VAULTWARDEN_ADMIN_TOKEN:-}"; then
      echo "Error: VAULTWARDEN_ADMIN_TOKEN not set" >&2
      echo "  Set it in .env or export it" >&2
      exit 1
   fi

   export VAULTWARDEN_URL
   export VAULTWARDEN_ADMIN_TOKEN

   b_cookie_file="$(mktemp)"
   trap 'rm -f "${b_cookie_file}"' EXIT

   # Step 1: Login to get session cookie
   curl -s -c "${b_cookie_file}" -X POST "${VAULTWARDEN_URL}/admin" \
      -d "token=${VAULTWARDEN_ADMIN_TOKEN}&redirect=/admin/users" > /dev/null

   # Step 2: Create user via invite endpoint
   curl -s -b "${b_cookie_file}" -X POST "${VAULTWARDEN_URL}/admin/invite" \
      -H 'Content-Type: application/json' \
      -d "{\"email\":\"${g_email}\",\"name\":\"${g_name}\",\"masterPasswordHash\":\"${g_hash}\"}"
}

fn_main "${@:-}"
