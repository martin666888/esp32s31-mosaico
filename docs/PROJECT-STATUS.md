# 工程阶段与接手基线

核查日期：2026-10-26。目标板为 ESP32-S31 / ESP-Mosaico V1.2，RK3588 为构建与调试主机。本说明依据现有源码、配置、镜像清单和历史实机记录，不代表本次重新构建或刷写。

## 已有成果

| 层次 | 状态与证据 |
| --- | --- |
| 启动与根文件系统 | UART 启动版已有实机记录；启动链包含 SPL、OpenSBI、U-Boot、Linux 6.18 XIP、cramfs |
| USB NCM / DHCP / SSH | 10 月 19 日候选已有 RK3588 和 Windows 实机验证记录；包括密钥登录、PTY、65,549 字节数据回传一致性 |
| SPI 第一阶段 | 新增 platform driver 骨架、Kconfig、Makefile 和配置片段；补丁已应用，编译链接和镜像生成完成 |
| 新 SPI 候选的上板验证 | 尚未记录通过，清单为 `hardware_boot_verified: false` |
| SPI 实际传输 | 尚未实现 |

## 六个内核补丁

位置：`mosaico-usb-external/patches/linux/`。

| 补丁 | 作用 |
| --- | --- |
| `0001-add-mosaico-v1.2-uart-board.patch` | UART 变体的设备树和 DTB 构建入口 |
| `0002-add-mosaico-usb-ncm.patch` | USB NCM 变体的设备树和 DTB 构建入口 |
| `0003-esp-dwc2-device-fifo.patch` | 修正 USB device 模式 FIFO 布局 |
| `0004-esp-gadget-buffer-dma.patch` | 禁用 descriptor DMA，使用 buffer DMA |
| `0005-ncm-rx-copy-diagnostic.patch` | NCM 接收数据复制诊断 |
| `0006-add-esp32s31-gpspi-skeleton.patch` | SPI 驱动骨架及构建入口 |

前五项与 10 月 19 日保留的已验证配置归档一致。第六项是之后新增的工作。SPI 驱动本体 39 行，只注册 platform driver、匹配 `esp,esp32s31-spi2` 并打印“hardware support not implemented yet”。当前没有寄存器访问、时钟/复位控制、SPI controller 注册或收发实现。

当前 DTB 中没有 `spi@` 节点，因此新驱动尚不会匹配设备并执行 `probe()`。内核中的 probe、匹配表与 initcall 符号证明代码已链接，不能代替实机运行验证。

## 新旧候选必须分开看

### 旧 USB 候选：已有实机记录

- 目录：`checks/usb-candidate-3212a0c4e87a/`。
- 完整镜像 SHA256：`3212a0c4e87a3ac50ff3e8c612841b243949c2d51cafcc4a866dbdd06b5f42df`。
- 记录：`checks/usb-hardware-result.json`、`logs/flash-usb-update-verified.json`、`checks/usb-rk-boot-20261019.txt`。
- 这些记录对应旧候选，不能套用到后续镜像。

### 当前 SPI 骨架候选：已构建、待上板

- 目录：`checks/usb-candidate-85812012cd26/`。
- 完整镜像 SHA256：`85812012cd26324ff93b81ad236f0746fd525ff5032da8c793505b7e076f09bf`。
- 当前 `checks/usb-flash-plan.json` 已指向这个新候选。
- 生成时间：2026-10-25；构建状态 `complete`，退出码 0。
- 与旧候选相比只有 `xipImage` 变化，增加 20,512 字节；SPL、U-Boot、DTB、rootfs 哈希相同。
- `usb-image-manifest.json` 明确标记 `hardware_boot_verified: false`。
- 证据：`logs/build-spi-stage1.log`、候选目录中的清单、内核 `vmlinux` 符号和 `.applied_patches_list`。

后续步骤是先确认新候选启动、USB 和 SSH 无回归，再增加设备树匹配及 probe 观察；真正访问寄存器和实现 SPI 传输属于后续阶段。本说明不构成刷写授权。

## 需要保留的现状差异

- `USB-SSH-STATUS.md` 是 10 月 19 日旧候选的历史操作说明；当前烧录计划已更新，不能仅依据该文档判定当前候选已验证。
- UART 外部树的 `board/.../esp32s31-mosaico-v1.2.dts` 有 `panel` GPIO 节点，但 `0001` 补丁没有该内容；当前 USB 变体也没有这些节点。该差异作为接手基线保留，没有擅自同步或删除。
- RK3588 当前可用 `/usr/bin/dtc`、`/usr/bin/fdtget`；旧交接报告中的 `output-mosaico/host/bin/fdtget` 路径不存在。

## 引入工程级 Git 前的状态

- 根目录和两套定制 external tree 没有 Git。
- `sources/buildroot`、`sources/esp-buildroot-external` 保留官方基线提交，工作区干净。
- `sources/linux` 的 `.git` 没有提交，91,191 个官方基线文件处于新增暂存状态。
- `sources/u-boot` 的 `.git` 没有提交，31,991 个官方基线文件处于新增暂存状态。
- `sources/opensbi`、`sources/esp-linux-bsp` 没有 `.git`。

引入根仓库时不改写这些目录，不伪造此前开发历史。首笔提交仅保存可复现定制输入及此处记录的接手状态。

## 2026-10-26 补充 Linux 源码 Git

- Linux 工作目录：`/userdata/esp32s31/output-mosaico/build/linux-custom`；分支 `codex/linux-learning`。
- Git 历史独立存放在 `/userdata/esp32s31/.linux-dev-git`，不纳入根仓库，不依赖原始源码仓库的对象文件。
- 从现有官方源码快照和六个现有补丁重建七笔基线提交，不冒充前任真实提交历史。标签 `baseline/espressif-linux`、`baseline/spi-stage1` 便于对照。
- 设置时用户驱动新增的六行注释保持原样，显示为未提交修改；共跟踪 91,194 个源码路径，编译产物被忽略。
- 新增 `scripts/linux-dev-git.py`，支持 status、backup 和 attach，详见 [源码 Git 使用说明](LINUX-DEVELOPMENT.md)。输出清理仍会删除未提交代码；清理前备份。
- 本次只设置版本管理，没有修改驱动逻辑、重新构建、推送或刷写。
