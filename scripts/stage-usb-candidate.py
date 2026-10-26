"""Stage the current build into a flash candidate directory.

The flash helpers read a candidate directory plus checks/usb-flash-plan.json
and only verify that the candidate matches its own recorded hashes. Nothing
ties them back to the build that produced it, so without this step a stale
candidate flashes happily and passes verification.

Run after scripts/build-mosaico-usb.sh, before any flash helper.
"""

import hashlib
import json
import pathlib
import shutil

root = pathlib.Path('/userdata/esp32s31')
images = root / 'output-mosaico/images'
flash = images / 's31_full_flash.bin'

# Must match sources/esp-linux-bsp/configs/esp32s31-layout.cfg.
slots = {
    'spl_app.bin': 0x2000,
    'u-boot.itb': 0x100000,
    'esp32s31-mosaico-v1.2-usb.dtb': 0x300000,
    'xipImage': 0x500000,
    'rootfs.cramfs': 0xC00000,
}
# What flash-usb-update.py writes incrementally instead of the whole image.
parts = ['esp32s31-mosaico-v1.2-usb.dtb', 'xipImage']

assert (root / 'logs/build-usb.status').read_text().strip() == 'complete', \
    'build-usb.status is not complete; refusing to stage a partial build'

blob = flash.read_bytes()
assert len(blob) <= 16 * 1024 * 1024, \
    'flash image is %d bytes, exceeds the 16 MB NOR' % len(blob)

manifest = {}
for name, offset in slots.items():
    content = (images / name).read_bytes()
    # The slot content must appear verbatim at its offset in the packed image,
    # otherwise the candidate would not describe what actually gets flashed.
    assert blob[offset:offset + len(content)] == content, \
        '%s does not match the packed image at %s' % (name, hex(offset))
    manifest[name] = {
        'offset': hex(offset),
        'size': len(content),
        'sha256': hashlib.sha256(content).hexdigest(),
    }

full_sha256 = hashlib.sha256(blob).hexdigest()
manifest['s31_full_flash.bin'] = {
    'size': len(blob),
    'sha256': full_sha256,
    'hardware_boot_verified': False,
}

candidate = root / ('checks/usb-candidate-' + full_sha256[:12])
assert not candidate.exists(), 'candidate %s already exists' % candidate
candidate.mkdir(parents=True)
for name in list(slots) + ['s31_full_flash.bin']:
    shutil.copy2(images / name, candidate / name)
(candidate / 'usb-image-manifest.json').write_text(
    json.dumps(manifest, indent=2) + '\n')

plan = {
    'directory': str(candidate),
    'full_sha256': full_sha256,
    'parts': [[name, slots[name]] for name in parts],
}
(root / 'checks/usb-flash-plan.json').write_text(json.dumps(plan) + '\n')

for name, entry in manifest.items():
    print('%-32s %-9s %9d  %s' % (
        name, entry.get('offset', '-'), entry['size'], entry['sha256'][:16]))
print('staged', candidate)
print('plan ->', root / 'checks/usb-flash-plan.json')
