#!/bin/sh
set -e
set -u

# Usage: deploy.sh <host> [version]
#
# Downloads, installs, and registers Memos as a systemd service.
# Requires: provision.sh + setup-app.sh already run.
#
# Examples:
#   ./deploy.sh app@memos.example.com
#   ./deploy.sh app@memos.example.com 0.29.1

fn_main() {
   g_host="${1:-}"
   g_version="${2:-}"
   if test -z "${g_host}"; then
      echo "Usage: $(basename "$0") <host> [version]" >&2
      exit 1
   fi

   # Download binary locally
   if test -z "${g_version}"; then
      g_version=$(curl -sL 'https://api.github.com/repos/usememos/memos/releases/latest' \
         | grep '"tag_name"' \
         | sed -E 's/.*"([^"]+)".*/\1/' \
         | tr -d 'v')
   fi
   g_url="https://github.com/usememos/memos/releases/download/v${g_version}/memos_${g_version}_linux_amd64.tar.gz"
   echo "Downloading Memos ${g_version}..."
   curl -LO "${g_url}"
   tar xzf "memos_${g_version}_linux_amd64.tar.gz"

   # Atomic rename + scp
   ssh "${g_host}" 'mv ~/bin/memos ~/bin/memos.old 2>/dev/null; true'
   scp ./memos "${g_host}:~/bin/memos"
   ssh "${g_host}" 'chmod +x ~/bin/memos && ~/bin/memos --version'

   # Register service
   ssh "${g_host}" '. ~/.config/envman/PATH.env && serviceman add --name memos --workdir ~/srv/memos -- ~/bin/memos --data ~/srv/memos/data --port 3080 --addr 0.0.0.0'

   # Verify
   ssh "${g_host}" 'systemctl status memos --no-pager'

   # Cleanup local artifacts
   rm -f "memos_${g_version}_linux_amd64.tar.gz"
}

fn_main "${@:-}"
