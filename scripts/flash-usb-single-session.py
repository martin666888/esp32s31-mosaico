import hashlib
import json
import pathlib

from esptool import cmds
from esptool.targets.esp32s31 import ESP32S31ROM

root = pathlib.Path('/userdata/esp32s31')
backup_dir = root / 'backups/mosaico-v1.2-20261019'
backup = backup_dir / 'factory-nor.bin'
images = root / 'checks/usb-candidate-2f5898b7'
image = images / 's31_full_flash.bin'
manifest = json.loads((images / 'usb-image-manifest.json').read_text())
assert (backup_dir / 'backup.status').read_text().strip() == 'verified'
assert backup.stat().st_size == 16777216
assert hashlib.sha256(backup.read_bytes()).hexdigest() == 'fc4aa95dd3483e68d2cf06729e72eba7d906fdffd81de06dc5ae767b66fc9a83'
assert hashlib.sha256(image.read_bytes()).hexdigest() == manifest['s31_full_flash.bin']['sha256']
assert image.stat().st_size <= 16777216
assert (root / 'logs/build-usb.status').read_text().strip() == 'complete'


def stage(name):
    (root / 'logs/flash-usb.status.json').write_text(json.dumps({'stage': name}) + '\n')
    print('\nSTAGE: ' + name, flush=True)


stage('connecting')
esp = ESP32S31ROM('/dev/serial/by-id/usb-Espressif_ESP32-S31_1c:29:04:d0:a4:18-if00', baud=115200)
try:
    esp.connect(mode='no-reset')
    print(esp.get_chip_description(), flush=True)
    security = esp.get_security_info()
    if security['flags'] != 0 or security['flash_crypt_cnt'] != 0:
        raise RuntimeError('Unexpected security configuration')
    esp = esp.run_stub()
    esp.change_baud(460800)
    cmds.attach_flash(esp)
    stage('writing_usb_linux')
    cmds.write_flash(esp, [(0, str(image))], no_progress=True)
    stage('verifying_usb_linux')
    cmds.verify_flash(esp, [(0, str(image))])
    stage('verified_waiting_for_normal_power_cycle')
finally:
    esp._port.close()
