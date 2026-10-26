import hashlib
import json
import pathlib
from esptool import cmds
from esptool.targets.esp32s31 import ESP32S31ROM

root = pathlib.Path('/userdata/esp32s31')
backup_dir = root / 'backups/mosaico-v1.2-20261019'
backup = backup_dir / 'factory-nor.bin.partial'
image = root / 'output-mosaico/images/s31_full_flash.bin'
expected_backup = 'fc4aa95dd3483e68d2cf06729e72eba7d906fdffd81de06dc5ae767b66fc9a83'
expected_image = '0ae30a4358ec4c86db7a1a1f1155b44c1b39ecd6199885164c878518d649429c'
if backup.stat().st_size != 16777216:
    raise RuntimeError('Original NOR backup is incomplete')
if hashlib.sha256(backup.read_bytes()).hexdigest() != expected_backup:
    raise RuntimeError('Original NOR backup checksum mismatch')
if hashlib.sha256(image.read_bytes()).hexdigest() != expected_image:
    raise RuntimeError('Linux candidate checksum mismatch')

status_path = root / 'logs/flash-linux-single-session.status.json'


def stage(name):
    status_path.write_text(json.dumps({'stage': name}) + '\n')
    print(f'\nSTAGE: {name}', flush=True)


stage('connecting')
esp = ESP32S31ROM('/dev/serial/by-id/usb-Espressif_ESP32-S31_1c:29:04:d0:a4:18-if00', baud=115200)
try:
    esp.connect(mode='no-reset')
    print(esp.get_chip_description(), flush=True)
    security = esp.get_security_info()
    if security['flags'] != 0 or security['flash_crypt_cnt'] != 0:
        raise RuntimeError('Unexpected security configuration; refusing write')
    cmds.attach_flash(esp)
    stage('verifying_factory_backup_against_device')
    cmds.verify_flash(esp, [(0, str(backup))], flash_size='16MB')
    final_backup = backup_dir / 'factory-nor.bin'
    if final_backup.exists():
        raise RuntimeError('Refusing to overwrite an existing factory backup')
    backup.rename(final_backup)
    (backup_dir / 'SHA256SUMS').write_text(f'{expected_backup}  backups/mosaico-v1.2-20261019/factory-nor.bin\n')
    (backup_dir / 'backup.status').write_text('verified\n')
    stage('factory_backup_verified_loading_ram_flasher')
    esp = esp.run_stub()
    esp.change_baud(460800)
    cmds.attach_flash(esp)
    stage('writing_linux')
    cmds.write_flash(esp, [(0, str(image))], no_progress=True)
    stage('verifying_linux_against_device')
    cmds.verify_flash(esp, [(0, str(image))])
    (root / 'logs/flash-linux-mosaico.status').write_text('verified\n')
    stage('linux_written_and_verified_waiting_for_normal_power_cycle')
finally:
    esp._port.close()
