# ESP-Mosaico V1.2 USB SSH

2026-10-19: RK3588 and Windows USB networking, DHCP and SSH verified on hardware.

## Connect

Connect the Mosaico Type-C port to the host with a USB data cable. Boot normally without BOOT. UART is optional for SSH and remains useful for boot diagnostics.

Board address: `192.168.7.2/30`. Host DHCP address: `192.168.7.1`. No default gateway or DNS is advertised. SSH accepts dedicated client keys; password login is disabled.

RK3588:

```sh
bash /userdata/esp32s31/scripts/ssh-mosaico.sh
```

Windows launcher:

```powershell
& 'D:\rk3588-debian12-deploy-20260917\esp32s31-mosaico\Connect-Mosaico.cmd'
```

Exit with `exit`. The root filesystem is read-only; `/tmp` is writable RAM storage cleared on power loss.

## Verified on RK3588

- Full flash digest matched the frozen candidate.
- Linux `6.18.0-mosaico-v1.2-usb`, build #3, boots successfully.
- RK3588 binds `cdc_ncm` to `enx022904d0a419`.
- DHCP automatically assigns `192.168.7.1/30`; ping passes.
- Pinned host-key verification and client public-key authentication pass.
- Remote commands, temporary-file read/write and interactive `/dev/pts/0` pass.
- 65,549 random bytes returned through SSH match byte for byte.
- TCP and UDP checksum error counters remain zero after testing.
- Approximately 11.2 MiB available RAM during SSH operation.

## Verified on Windows

- Native `UsbNcm Host Device` driver loads automatically; no additional driver package was installed.
- DHCP automatically assigns `192.168.7.1/30`; ping passes.
- Windows OpenSSH verifies the pinned device host key and authenticates with its dedicated client key.
- Commands and interactive `/dev/pts/0` pass.
- 65,549 random bytes returned through SSH match byte for byte.
- The same firmware was used for both host tests.

## Firmware

Image SHA256: `3212a0c4e87a3ac50ff3e8c612841b243949c2d51cafcc4a866dbdd06b5f42df`.

| Component | NOR offset | Bytes |
| --- | --- | --- |
| SPL | `0x2000` | 38,032 |
| U-Boot FIT | `0x100000` | 259,208 |
| USB board DTB | `0x300000` | 6,067 |
| Linux XIP image | `0x500000` | 2,844,325 |
| cramfs root | `0xC00000` | 3,678,208 |

Full image: 16,261,120 bytes including erased padding; 516,096 bytes remain at the end of NOR. SPI NAND is untouched.

USB configuration: `/userdata/esp32s31/mosaico-usb-external/`. Build: `bash /userdata/esp32s31/scripts/build-mosaico-usb.sh`. Dependencies use cache and domestic mirrors. Original UART configuration remains at `/userdata/esp32s31/mosaico-external/`.

Local evidence: `usb-image-manifest.json`, `usb-hardware-result.json`, `usb-rk-boot-20261019.txt`. Local firmware: `s31_usb_ssh_flash.bin`. The archive `mosaico-usb-config.tar.gz` excludes private host keys. Firmware contains this device's host private key and belongs with private backups.

## USB fixes

The original BSP supplies host FIFO sizes but no usable device layout. Hardware reported RX 1,024 words and EP0 TX 512 words despite only 896 total words. The ESP peripheral layout now uses RX 256, EP0 TX 64, two TX FIFOs of 128, and five of 64 words. USB enumeration then succeeds.

Descriptor DMA caused reproducible corruption of received frame bytes. The host sent a correct SSH version packet, but a byte changed on receipt. A byte-copy self-check passed. Conventional buffer DMA resolved SSH and DHCP; the binary roundtrip passed. This bring-up kernel retains a rate-limited NCM receive-copy consistency check; no mismatches were reported.

RK3588 NetworkManager originally excluded Ethernet devices. `/etc/NetworkManager/conf.d/90-mosaico-usb.conf` adds an exception for MAC `02:29:04:d0:a4:19`. Connection `mosaico-usb` uses DHCP, with default routing and automatic DNS disabled.

## Recovery

Original NOR backup remains verified: SHA256 `fc4aa95dd3483e68d2cf06729e72eba7d906fdffd81de06dc5ae767b66fc9a83`. See `FACTORY-RECOVERY.md`. UART-only Linux remains in `/userdata/esp32s31/backups/uart-linux-20261019/` and locally as `s31_full_flash.bin`.

Use frozen candidate files for subsequent flashes. `/userdata/esp32s31/checks/usb-flash-plan.json` currently selects `/userdata/esp32s31/checks/usb-candidate-3212a0c4e87a/`. `flash-usb-update.py` updates kernel and DTB, then compares the complete image. A fresh physical ROM download-mode entry is required.
