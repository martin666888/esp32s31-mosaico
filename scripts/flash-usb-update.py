import hashlib
import json
import pathlib

from esptool import cmds
from esptool.targets.esp32s31 import ESP32S31ROM

root = pathlib.Path('/userdata/esp32s31')
plan = json.loads((root / 'checks/usb-flash-plan.json').read_text())
candidate = pathlib.Path(plan['directory'])
image = candidate / 's31_full_flash.bin'
manifest = json.loads((candidate / 'usb-image-manifest.json').read_text())
assert hashlib.sha256(image.read_bytes()).hexdigest() == plan['full_sha256']
backup = root / 'backups/mosaico-v1.2-20261019/factory-nor.bin'
assert hashlib.sha256(backup.read_bytes()).hexdigest() == 'fc4aa95dd3483e68d2cf06729e72eba7d906fdffd81de06dc5ae767b66fc9a83'
parts = []
for name, offset in plan['parts']:
    assert name in ['xipImage', 'esp32s31-mosaico-v1.2-usb.dtb']
    assert offset == int(manifest[name]['offset'], 16)
    assert hashlib.sha256((candidate / name).read_bytes()).hexdigest() == manifest[name]['sha256']
    parts.append((offset, str(candidate / name)))
esp = ESP32S31ROM('/dev/serial/by-id/usb-Espressif_ESP32-S31_1c:29:04:d0:a4:18-if00', baud=115200)
try:
    esp.connect(mode='no-reset')
    security = esp.get_security_info()
    assert security['flags'] == 0 and security['flash_crypt_cnt'] == 0
    esp = esp.run_stub()
    esp.change_baud(460800)
    cmds.attach_flash(esp)
    cmds.write_flash(esp, parts, no_progress=True)
    cmds.verify_flash(esp, [(0, str(image))])
    (root / 'logs/flash-usb-update-verified.json').write_text(json.dumps(plan) + '\n')
    print('USB update and full image verification passed', flush=True)
finally:
    esp._port.close()
