#!/bin/sh
set -e
set -u

# Usage: download.sh [version]
#
# Downloads the Memos release binary for Linux amd64.
#
# Examples:
#   ./download.sh          # latest
#   ./download.sh 0.29.1   # specific version

fn_main() {
   g_version="${1:-}"

   if test -z "${g_version}"; then
      # Try to get latest version from GitHub API
      g_version=$(curl -sL 'https://api.github.com/repos/usememos/memos/releases/latest' \
         | grep '"tag_name"' \
         | sed -E 's/.*"([^"]+)".*/\1/' \
         | tr -d 'v')
      echo "Latest version: ${g_version}"
   fi

   g_url="https://github.com/usememos/memos/releases/download/v${g_version}/memos_${g_version}_linux_amd64.tar.gz"

   echo "Downloading Memos ${g_version}..."
   curl -LO "${g_url}"
   tar xzf "memos_${g_version}_linux_amd64.tar.gz"

   ls -lh memos
}

fn_main "${@:-}"
