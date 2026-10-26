import pathlib
import re
import time

import serial

root = pathlib.Path('/userdata/esp32s31')
log = root / 'logs/usb-linux-boot.bin'
port = serial.Serial(port=None, baudrate=115200, timeout=0.2, exclusive=True)
port.dtr = False
port.rts = False
port.port = '/dev/serial/by-id/usb-1a86_USB_Single_Serial_5CE6060430-if00'
probe = b"printf '\\n__USB_BOOT_PROBE__\\n'; uname -a; cat /proc/cmdline; ifconfig -a; ls /sys/class/udc; cat /sys/class/udc/*/state; ps; head -n 6 /proc/meminfo; printf '__USB_BOOT_DONE__\\n'\n"
data = bytearray()
sent = False
print('UART capture active for 180 seconds', flush=True)
with port, log.open('wb') as output:
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        chunk = port.read(min(max(port.in_waiting, 1), 4096))
        if not chunk:
            continue
        data.extend(chunk)
        output.write(chunk)
        output.flush()
        clean = bytes(data).replace(b'\0', b'')
        if not sent and b'Linux version' in clean and re.search(rb'(?:^|\n)[^\n]{0,40}# $', clean[-200:]):
            port.write(probe)
            port.flush()
            sent = True
        if sent and re.search(rb'\n__USB_BOOT_DONE__\r?\n', clean):
            break
text = bytes(data).replace(b'\0', b'').decode(errors='backslashreplace')
(root/'logs/usb-linux-boot.txt').write_text(text)
print(text, flush=True)
