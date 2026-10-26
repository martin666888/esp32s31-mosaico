set -euo pipefail
cd /userdata/esp32s31
test "$(cat logs/build.status)" = complete
mkdir -p checks
exec > >(tee checks/image-validation.log) 2>&1
python3 - <<'PY'
import hashlib
import json
import pathlib

root = pathlib.Path('/userdata/esp32s31')
images = root / 'output-mosaico/images'
flash = (images / 's31_full_flash.bin').read_bytes()
if len(flash) > 16 * 1024 * 1024:
    raise RuntimeError('Flash image exceeds the 16 MB NOR capacity')
slots = {
    'spl_app.bin': 0x2000,
    'u-boot.itb': 0x100000,
    'esp32s31-mosaico-v1.2.dtb': 0x300000,
    'xipImage': 0x500000,
    'rootfs.cramfs': 0xC00000,
}
manifest = {}
for name, offset in slots.items():
    content = (images / name).read_bytes()
    if flash[offset:offset + len(content)] != content:
        raise RuntimeError('Packed image does not match component ' + name)
    manifest[name] = {'offset': hex(offset), 'size': len(content), 'sha256': hashlib.sha256(content).hexdigest()}
    print(name, hex(offset), len(content), flush=True)
manifest['s31_full_flash.bin'] = {'size': len(flash), 'sha256': hashlib.sha256(flash).hexdigest(), 'hardware_boot_verified': False}
(images / 'image-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Flash slot consistency verified; total bytes', len(flash), flush=True)
PY
fdtget output-mosaico/images/esp32s31-mosaico-v1.2.dtb / model
fdtget output-mosaico/images/esp32s31-mosaico-v1.2.dtb /chosen bootargs
for node in /soc/ethernet@20350000 /soc/i2c@20385000 /soc/usb@20300000; do
    fdtget output-mosaico/images/esp32s31-mosaico-v1.2.dtb "$node" status
done
output-mosaico/host/bin/riscv64-esp-linux-musl-readelf -h output-mosaico/build/linux-custom/vmlinux | head -n 15
file output-mosaico/target/bin/busybox
.venv/bin/esptool --chip esp32s31 image-info output-mosaico/images/spl_app.bin
sha256sum -c output-mosaico/images/SHA256SUMS
