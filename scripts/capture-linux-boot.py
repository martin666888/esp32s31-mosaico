import datetime
import pathlib
import re
import sys
import time
import serial

root = pathlib.Path('/userdata/esp32s31')
stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
log = root / 'logs' / f'linux-boot-{stamp}.bin'
port = serial.Serial(port=None, baudrate=115200, timeout=0.25, exclusive=True)
port.dtr = False
port.rts = False
port.port = '/dev/serial/by-id/usb-1a86_USB_Single_Serial_5CE6060430-if00'
print(f'Capturing UART for 120 seconds; log: {log}', flush=True)
received = bytearray()
probe_sent = False
probe = b"printf '\\n__LINUX_PROBE_BEGIN__\\n'; uname -a; cat /proc/device-tree/model; printf '\\n'; head -n 6 /proc/meminfo; mount; printf 'mosaico-linux-ok\\n' > /tmp/mosaico-smoke; cat /tmp/mosaico-smoke; rm /tmp/mosaico-smoke; printf '__LINUX_PROBE_END__\\n'\n"
with port, log.open('wb') as output:
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        chunk = port.read(min(max(port.in_waiting, 1), 4096))
        if chunk:
            received.extend(chunk)
            output.write(chunk)
            output.flush()
            sys.stdout.write(chunk.decode('utf-8', errors='backslashreplace'))
            sys.stdout.flush()
            if not probe_sent and b'Linux version' in received and re.search(rb'(?:^|\n)(?:/ )?# $', received[-200:]):
                port.write(probe)
                port.flush()
                probe_sent = True
            if probe_sent and re.search(rb'\n__LINUX_PROBE_END__\r?\n', received):
                print('\nLinux shell probe completed.', flush=True)
                break
print(f'\nCapture complete: {log}', flush=True)
