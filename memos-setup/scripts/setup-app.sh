#!/bin/sh
set -e
set -u

# Usage: setup-app.sh <host> <app_name>
#
# Sets up a generic app on a remote host:
#   - Installs serviceman via webi
#   - Adds ~/bin to PATH.env
#   - Creates ~/bin, ~/srv/<app>, ~/.config/<app>
#
# Examples:
#   ./setup-app.sh app@memos.example.com memos
#   ./setup-app.sh app@warden.example.com vaultwarden

fn_main() {
   g_host="${1:-}"
   g_app="${2:-}"
   if test -z "${g_host}" || test -z "${g_app}"; then
      echo "Usage: $(basename "$0") <host> <app_name>" >&2
      exit 1
   fi

   # Install serviceman if not present
   ssh "${g_host}" '. ~/.config/envman/PATH.env && webi serviceman@stable'

   # Ensure ~/bin is on PATH
   ssh "${g_host}" 'grep -q "$HOME/bin" ~/.config/envman/PATH.env || echo "export PATH=\"$HOME/bin:\$PATH\"" >> ~/.config/envman/PATH.env'

   # Create directory layout
   ssh "${g_host}" "mkdir -p ~/bin ~/srv/${g_app} ~/.config/${g_app}"
}

fn_main "${@:-}"
