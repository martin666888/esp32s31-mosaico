set -euo pipefail
cd /userdata/esp32s31
exec > >(tee logs/configure-mosaico.log) 2>&1
python3 - <<'PY'
import difflib
import hashlib
import json
import pathlib
import shutil
import subprocess

root = pathlib.Path('/userdata/esp32s31')
archives = json.loads((root / 'archives.lock.json').read_text())
sources = json.loads((root / 'sources.lock.json').read_text())
external = root / 'mosaico-external'
if not external.exists():
    shutil.copytree(root / 'sources/esp-buildroot-external', external, ignore=shutil.ignore_patterns('.git'))
patches = external / 'patches/linux'
patches.mkdir(parents=True, exist_ok=True)
board = external / 'board/espressif/esp32s31-mosaico-v1.2'
board.mkdir(parents=True, exist_ok=True)
dt_name = 'esp32s31-mosaico-v1.2'
dts = '''// SPDX-License-Identifier: (GPL-2.0 OR MIT)
#include "esp32s31.dts"

/ {
    model = "Espressif ESP-Mosaico V1.2 (UART bring-up)";

    chosen {
        stdout-path = "serial0:115200n8";
    };
};

&emac {
    status = "disabled";
};

&i2c0 {
    status = "disabled";
};

&usb {
    status = "disabled";
};

&usb_phy {
    status = "disabled";
};
'''
(board / (dt_name + '.dts')).write_text(dts)
makefile = pathlib.Path('arch/riscv/boot/dts/espressif/Makefile')
old = (root / 'sources/linux' / makefile).read_text()
new = old + 'dtb-$(CONFIG_ARCH_ESPRESSIF) += ' + dt_name + '.dtb\n'
patch = ''.join(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True), fromfile='a/' + str(makefile), tofile='b/' + str(makefile)))
patch += ''.join(difflib.unified_diff([], dts.splitlines(keepends=True), fromfile='/dev/null', tofile='b/arch/riscv/boot/dts/espressif/' + dt_name + '.dts'))
patch_file = patches / '0001-add-mosaico-v1.2-uart-board.patch'
patch_file.write_text(patch)
subprocess.run(['git', '-C', str(root / 'sources/linux'), 'apply', '--check', str(patch_file)], check=True)
(board / 'linux.fragment').write_text('CONFIG_LOCALVERSION="-mosaico-v1.2"\nCONFIG_DEFAULT_HOSTNAME="esp-mosaico"\n# CONFIG_STMMAC_ETH is not set\n# CONFIG_I2C is not set\n# CONFIG_USB is not set\n# CONFIG_PHY_ESP32S31_USB is not set\n')
original_config = (external / 'configs/espressif_esp32s31_function_core_board_nor_defconfig').read_text()
drop = ('BR2_LINUX_KERNEL_CUSTOM_', 'BR2_TARGET_UBOOT_CUSTOM_', 'BR2_TARGET_OPENSBI_CUSTOM_', 'BR2_LINUX_KERNEL_INTREE_DTS_NAME=', 'BR2_TOOLCHAIN_EXTERNAL_URL=')
config = '\n'.join(line for line in original_config.splitlines() if not line.startswith(drop)) + '\n'
for prefix, name in [('BR2_LINUX_KERNEL', 'linux'), ('BR2_TARGET_UBOOT', 'u-boot'), ('BR2_TARGET_OPENSBI', 'opensbi')]:
    config += prefix + '_CUSTOM_TARBALL=y\n'
    config += prefix + '_CUSTOM_TARBALL_LOCATION="file://' + archives[name]['file'] + '"\n'
config += '''BR2_TOOLCHAIN_EXTERNAL_URL="https://dl.espressif.cn/dl/toolchains/preview/riscv64/14.1.1_20260922/riscv64-esp-linux-musl-14.1.1_20260922-$(HOSTARCH)-linux-gnu.tar.xz"
BR2_DL_DIR="/userdata/esp32s31/dl"
BR2_PRIMARY_SITE="https://mirrors.nju.edu.cn/buildroot"
BR2_PRIMARY_SITE_ONLY=y
BR2_BACKUP_SITE=""
BR2_KERNEL_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/kernel"
BR2_GLOBAL_PATCH_DIR="$(BR2_EXTERNAL_ESP_LINUX_BSP_PATH)/patches"
BR2_LINUX_KERNEL_INTREE_DTS_NAME="espressif/esp32s31-mosaico-v1.2"
BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES="$(BR2_EXTERNAL_ESP_LINUX_BSP_PATH)/board/espressif/esp32s31-mosaico-v1.2/linux.fragment"
BR2_TARGET_GENERIC_HOSTNAME="esp-mosaico"
'''
(external / 'configs/espressif_esp32s31_mosaico_v1_2_uart_defconfig').write_text(config)
bsp_mk = external / 'package/esp-linux-bsp/esp-linux-bsp.mk'
content = bsp_mk.read_text()
content = content.replace('ESP_LINUX_BSP_VERSION = integration/v1.0-esp32s31', 'ESP_LINUX_BSP_VERSION = ' + sources['esp-linux-bsp']['commit'])
content = content.replace('ESP_LINUX_BSP_SITE = https://github.com/espressif/esp-linux-bsp.git', 'ESP_LINUX_BSP_SITE = file:///userdata/esp32s31/archives\nESP_LINUX_BSP_SOURCE = ' + pathlib.Path(archives['esp-linux-bsp']['file']).name)
content = content.replace('ESP_LINUX_BSP_SITE_METHOD = git', 'ESP_LINUX_BSP_SITE_METHOD = file')
bsp_mk.write_text(content)
for package, name in [('linux', 'linux'), ('uboot', 'u-boot'), ('opensbi', 'opensbi')]:
    directory = external / 'patches' / package
    directory.mkdir(exist_ok=True)
    (directory / (package + '.hash')).write_text('sha256  ' + archives[name]['sha256'] + '  ' + pathlib.Path(archives[name]['file']).name + '\n')
(external / 'package/esp-linux-bsp/esp-linux-bsp.hash').write_text('sha256  ' + archives['esp-linux-bsp']['sha256'] + '  ' + pathlib.Path(archives['esp-linux-bsp']['file']).name + '\n')
post = external / 'board/espressif/esp32s31/post-image.sh'
content = post.read_text()
line = 'export BR2_LINUX_KERNEL_INTREE_DTS_NAME="espressif/esp32s31-mosaico-v1.2"'
if line not in content:
    if 'set -eu\n' not in content:
        raise RuntimeError('Unexpected upstream post-image script')
    post.write_text(content.replace('set -eu\n', 'set -eu\n' + line + '\n', 1))
print('Mosaico board patch applies cleanly; domestic mirrors and cached sources configured', flush=True)
PY
make -C sources/buildroot BR2_EXTERNAL=/userdata/esp32s31/mosaico-external O=/userdata/esp32s31/output-mosaico espressif_esp32s31_mosaico_v1_2_uart_defconfig
make -C sources/buildroot O=/userdata/esp32s31/output-mosaico BR2_DEFCONFIG=/userdata/esp32s31/mosaico-external/configs/espressif_esp32s31_mosaico_v1_2_uart_defconfig savedefconfig
