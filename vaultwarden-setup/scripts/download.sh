#!/bin/sh
set -e
set -u

fn_main() {
   mkdir -p ./vw-image
   (
      cd ./vw-image
      curl -LO 'https://raw.githubusercontent.com/jjlin/docker-image-extract/main/docker-image-extract'
      chmod +x ./docker-image-extract
      ./docker-image-extract vaultwarden/server:latest-alpine

      ls -ld ./output/vaultwarden ./output/web-vault
   )
}

fn_main "${@:-}"
