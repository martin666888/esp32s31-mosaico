#!/bin/bash
set -euo pipefail
cd /userdata/esp32s31
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
export ESP_ESPTOOL=/userdata/esp32s31/.venv/bin/esptool
printf 'running\n' > logs/build-usb.status
trap 'result=$?; printf "%s\n" "$result" > logs/build-usb.exit; if [ "$result" = 0 ]; then printf "complete\n" > logs/build-usb.status; else printf "failed\n" > logs/build-usb.status; fi' EXIT
make -C sources/buildroot O=/userdata/esp32s31/output-mosaico BR2_JLEVEL=6 BR2_WGET='wget --passive-ftp -nd -t 2 --timeout=30'
sha256sum output-mosaico/images/s31_full_flash.bin > output-mosaico/images/SHA256SUMS
