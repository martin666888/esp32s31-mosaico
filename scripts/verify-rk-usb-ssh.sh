set -euo pipefail
cd /userdata/esp32s31
awk '/^ssh-ed25519 / { print "192.168.7.2 " $1 " " $2 }' private/mosaico-host-public.txt > private/mosaico-known-hosts
chmod 0600 private/mosaico-known-hosts
timeout 30 ssh -i private/mosaico-rk-ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=private/mosaico-known-hosts -o ConnectTimeout=15 root@192.168.7.2 'uname -a; cat /proc/device-tree/model; echo; head -n 6 /proc/meminfo; printf "usb-ssh-ok\n" > /tmp/usb-ssh-smoke; cat /tmp/usb-ssh-smoke; rm /tmp/usb-ssh-smoke; df -h / /tmp'
python3 -u - <<'PY'
import os, subprocess
env = os.environ.copy()
env['TERM'] = 'xterm'
command = ['ssh', '-tt', '-i', 'private/mosaico-rk-ed25519', '-o', 'IdentitiesOnly=yes', '-o', 'StrictHostKeyChecking=yes', '-o', 'UserKnownHostsFile=private/mosaico-known-hosts', '-o', 'ConnectTimeout=10', 'root@192.168.7.2', 'tty; echo interactive-pty-ok; exit']
p = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
try:
    p.wait(timeout=20)
    output = p.stdout.read()
    print(output.decode(errors='replace'))
    assert p.returncode == 0 and b'interactive-pty-ok' in output
except subprocess.TimeoutExpired:
    p.kill()
    p.communicate()
    raise
finally:
    p.stdin.close()
PY
