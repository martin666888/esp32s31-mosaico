#!/bin/bash
set -eu
exec /userdata/esp32s31/.venv/bin/python -m serial.tools.miniterm --dtr 0 --rts 0 --eol LF /dev/serial/by-id/usb-1a86_USB_Single_Serial_5CE6060430-if00 115200
