#!/bin/sh
set -e
set -u

# Usage: provision.sh <host> [username] [timezone] [locale]
#
# Provisions a fresh Ubuntu container with:
#   - dist-upgrade
#   - basic tools (curl, fish, git, htop, less, screen, sudo, vim, wget, unzip, zstd)
#   - locale (default: en_US.UTF-8)
#   - timezone (default: UTC)
#   - ssh-utils via webi
#   - app user with sudo, password set, SSH key added, password login disabled
#
# Examples:
#   ./provision.sh root@memos.example.com
#   ./provision.sh root@10.11.2.32 myuser Europe/London en_GB.UTF-8

fn_main() {
   g_host="${1:-}"
   g_user="${2:-app}"
   g_tz="${3:-UTC}"
   g_locale="${4:-en_US.UTF-8}"
   if test -z "${g_host}"; then
      echo "Usage: $(basename "$0") <host> [username]" >&2
      exit 1
   fi

   ssh -t "${g_host}" <<EOF
apt-get update
apt-get dist-upgrade -y
apt-get install -y curl fish git htop less screen sudo vim wget unzip zstd

echo "${g_locale} UTF-8" > /etc/locale.gen
echo 'LANG=${g_locale}' > /etc/locale.conf
ln -sf /etc/locale.conf /etc/default/locale
source /etc/locale.conf
locale-gen

timedatectl set-timezone ${g_tz}

wget -O - https://webi.sh/ssh-utils | sh
. ~/.config/envman/PATH.env

ssh-adduser '${g_user}'
sshd-prohibit-password
systemctl restart sshd
EOF
}

fn_main "${@:-}"
