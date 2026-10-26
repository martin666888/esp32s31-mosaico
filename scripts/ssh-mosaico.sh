#!/bin/sh
exec ssh -i /userdata/esp32s31/private/mosaico-rk-ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/userdata/esp32s31/private/mosaico-known-hosts root@192.168.7.2 "$@"
