# ESP32-S31 / ESP-Mosaico V1.2 Linux 学习工程

GitHub：[martin666888/esp32s31-mosaico](https://github.com/martin666888/esp32s31-mosaico)

本项目基于乐鑫官方 BSP，在 ESP-Mosaico V1.2 上学习和开发 ESP32-S31 Linux 系统及驱动。RK3588 ARM64 是编译与调试主机，ESP32-S31 是 Linux 运行目标。

硬件环境：16 MiB PSRAM、16 MiB NOR；系统采用 Linux 6.18、Buildroot 2025.02、XIP 内核、只读 cramfs 与可写 tmpfs。已实现串口 Shell、USB NCM 网络、DHCP 和 Dropbear 公钥 SSH，GPSPI2 正在分阶段开发。仓库保存板级配置、内核补丁、构建辅助脚本和学习说明。

当前是开发中的学习工程。GPIO 路由、SPI 数据传输、Quad 和屏幕驱动仍待实现；GPSPI2 初始化成功不代表屏幕已可使用。

**第一阶段 GPSPI2 硬件初始化已完成上板验证；下一步是最小单线 PIO 发送。** 先读下方当前进度，再按 [学习路线](docs/学习路线.md) 继续。源码版本管理方法见 [Linux 源码 Git](docs/LINUX-DEVELOPMENT.md)。

根仓库第一笔提交是 2026-10-26 接手时的现状快照，不代表此前工作在这一天完成，也不是过去开发历史的重建。

## 获取与构建前提

本机已验证的工程位置为 `/userdata/esp32s31`；现有脚本、锁文件和 defconfig 含此绝对路径，暂未适配任意目录。源码下载位置和版本见 [sources.lock.json](sources.lock.json)，官方源码重建依据见 [official-patches/source-reconstruction.json](official-patches/source-reconstruction.json)。

从 GitHub 克隆后仍需准备以下本机输入：

- 按锁文件准备 `sources/`、`archives/`，并核对归档摘要；仓库不包含上游完整源码或下载缓存。
- 准备对应 ARM64 工具链、Buildroot 依赖及支持 ESP32-S31 的 esptool/Python 环境；现有构建脚本使用 `.venv/bin/esptool`。
- 使用 USB 变体 `mosaico-usb-external` 的 defconfig；两套变体共用输出目录，文件名不会自动切换配置。
- 自行生成设备 SSH 主机密钥与客户端密钥，按自己的设备配置授权公钥和主机指纹；这些身份材料不随仓库发布。现有烧录辅助脚本还依赖本机候选、设备身份和恢复备份，不能当作通用刷写入口直接运行。

完整 NOR 镜像、工具链、缓存、私钥及本机备份均不在仓库中；现阶段没有承诺从空目录执行单条命令即可完成构建。增量开发与构建命令见下文，USB 操作记录见 [USB SSH 说明](USB-SSH-STATUS.md)。

## 当前进度（2026-10-31）

| 内容 | 已确认的进度 | 验证边界 |
| --- | --- | --- |
| Linux 启动、UART Shell、cramfs / tmpfs | 已有实机记录 | 根文件系统只读，临时文件在 RAM 中，断电丢失 |
| USB NCM、DHCP、Dropbear SSH | 10 月 19 日版本已验证 RK3588、Windows、交互 PTY 和二进制回传 | 旧版本测试结果不自动覆盖后续候选 |
| GPSPI2 设备树匹配和 MMIO 映射 | 用户已烧录候选 `08ccdef01198`，整片摘要匹配，并提供 `register window mapped` 启动日志 | 证明驱动绑定及 MMIO 资源映射通过，尚不证明 SPI 收发 |
| 第一阶段：时钟与复位初始化 | 用户完成编译及上板启动，提供 `hardware init ready: core=20000000 Hz, CMD=0x00000000` 日志，并通过 USB 网络 SSH 登录 | 验证初始化路径；尚不证明 SPI 收发或引脚波形，20 MHz 是根据时钟寄存器计算的频率 |
| 第一阶段学习注释 | 六个文件已补中文注释；与加注释前相比，去掉注释后的代码逐行一致，`git diff --check` 通过 | 只增加说明，不改变驱动逻辑 |
| SPI 传输、引脚、Quad、显示 | 后续阶段 | 当前不具备 SPI 收发、屏幕或触摸功能 |

第一阶段源码已包含：保存私有数据、申请 MMIO/时钟/复位资源、开启 BUS 时钟、置于复位、配置并开启 CORE 时钟、解除复位、读取 CMD、登记失败/解绑清理动作。当前策略为 40 MHz XTAL / 2 / 1 = 20 MHz；这是控制器工作时钟，不是外部 SCK 的实测频率。

当前烧录计划指向 `/userdata/esp32s31/checks/usb-candidate-7ee1702fe290/`：

- 计划记录的完整镜像 SHA256：`7ee1702fe29072c9b87c69bd9631bd1115f4c191dbaa63d9f121b00c95a746d2`。此处记录计划内容，不作为本轮整片刷写校验的独立证据。
- 用户在本次教学对话提供初始化日志：`[    0.392869] esp32s31-spi 2038f000.spi: hardware init ready: core=20000000 Hz, CMD=0x00000000`，并通过 `scripts/ssh-mosaico.sh` 登录板子。
- 旧候选 `08ccdef01198` 的整片校验及 MMIO 映射记录保留为历史依据，不替代新候选的校验。
- `logs/build-usb.status` / `build-usb.exit` 是完整构建脚本留下的状态；单独执行 `linux-rebuild` 不会刷新它们。判断新固件时必须对应实际执行的那一轮构建。


## 目录与职责

| 目录或文件 | 用途 | 根仓库是否跟踪 |
| --- | --- | --- |
| `mosaico-external/` | UART 启动变体的配置与补丁 | 是，密钥除外 |
| `mosaico-usb-external/` | 当前 USB NCM / SSH 变体；补丁 0001～0008 已覆盖 GPSPI2 第一阶段初始化 | 是，密钥除外 |
| `scripts/` | 配置、构建、候选生成、烧录与验证辅助脚本 | 是；脚本入库不代表授权运行烧录 |
| `sources.lock.json`、`archives.lock.json` 等锁文件 | 固定上游版本、下载位置和摘要 | 是 |
| `official-patches/` | 重建官方源码版本的补丁及来源记录 | 是 |
| `docs/` | 阶段、证据位置和学习记录 | 是 |
| `sources/` | 官方源码基线，部分目录另有自己的 `.git` | 否，保持现状 |
| `output-mosaico/` | Buildroot 构建树、主机工具链和镜像；其中 Linux 源码由独立 Git 跟踪 | 根仓库不跟踪，清理前保存源码工作 |
| `.linux-dev-git/` | Linux 源码仓库历史，位于输出目录之外 | 根仓库不跟踪 |
| `archives/`、`dl/`、`.venv/` | 源码归档、依赖缓存和 Python 环境 | 否 |
| `checks/`、`logs/`、`tmp/` | 本机候选固件、测试证据、日志和临时文件 | 否 |
| `private/`、`backups/`、外部树中的 SSH 身份文件 | 本机身份与恢复资料；固件也可能含设备私钥 | 否，单独保管 |

`.gitignore` 使用根目录允许清单，并额外排除两套外部树中的 SSH 身份目录。保留在本机的忽略文件没有被搬移或删除。

## 改动如何进入固件

```text
sources.lock.json / archives.lock.json
              ↓ 固定官方基线
mosaico-usb-external/patches/linux/000N-*.patch
              ↓ Buildroot 解包并应用补丁
output-mosaico/build/linux-custom/
              ↓ 编译、链接及打包
output-mosaico/images/
              ↓ scripts/stage-usb-candidate.py
checks/usb-candidate-<摘要>/ + checks/usb-flash-plan.json
              ↓ 单独授权后才刷写与实机验证
ESP-Mosaico V1.2
```

`sources/linux` 当前用于官方基线对照，不在这里直接开发本地驱动。构建树已配置独立源码 Git，可以直接查看驱动修改；历史位于 `.linux-dev-git/`，但 `linux-dirclean` 仍会删除未提交的工作区内容，清理前按 [源码 Git 说明](docs/LINUX-DEVELOPMENT.md) 备份。需要保留的改动必须生成补丁并检查能否从基线重新构建。

两套变体共用 `output-mosaico`，构建脚本主要复用现有配置；脚本名称不会自动切换完整配置。运行 `configure-mosaico.sh` 会重新生成 UART 配置和设备树原料，先检查差异，不要把它当作无副作用的通用构建命令。

当前外部树中的板级 DTS 主要是生成补丁的原料。只改 `board/.../*.dts` 不等于它进入内核构建树，必须同步实际补丁并检查生成的 DTB。

## 使用 Git 查看与保存学习进度

在 RK3588 上执行：

```sh
cd /userdata/esp32s31
git status --short
git diff
git log --oneline --decorate -10
git show --stat HEAD
```

每个学习步骤尽量对应一个可解释的小改动，提交说明记录：做了什么、依据是什么、验证到了哪一层、还没有验证什么。只有 `.o` 编译通过，不能写成硬件功能已经通过。

本地 Git 负责版本对比和回退，不代替磁盘备份。项目仓库已配置 GitHub 远端 `origin`，默认分支为 `main`；Linux 源码仓库仍独立保存在本机。新机器恢复构建还需要按锁文件准备源码、工具链及本机私有 SSH 输入；本仓库不是包含全部缓存和设备身份的一键恢复包。

## 第一阶段代码阅读位置

以下路径相对于 `/userdata/esp32s31/output-mosaico/build/linux-custom/`。中文注释统一用“阶段一”标识，建议先看 SPI probe，再沿时钟和复位句柄追到 provider。

| 文件 | 本阶段作用 |
| --- | --- |
| `drivers/spi/spi-esp32s31.c` | 私有数据、资源获取、初始化顺序、频率检查、CMD 读取和错误回收 |
| `drivers/clk/clk-esp32s31.c` | BUS 门控、CORE 选源和两级分频、频率计算、专用 ops 与缓存处理 |
| `drivers/reset/reset-esp32s31.c` | GPSPI2 复位位描述，复用共享 regmap 的 assert/deassert 操作 |
| `include/dt-bindings/clock/esp32s31.h` | 追加 BUS/CORE 两个 ABI 编号，时钟总数从 11 变为 13 |
| `include/dt-bindings/reset/esp32s31.h` | 追加 GPSPI2 复位 ABI 编号，复位总数从 5 变为 6 |
| `arch/riscv/boot/dts/espressif/esp32s31.dts` | 将 SPI 设备与两个时钟及一个复位资源关联 |

硬件依据的阅读顺序：官方 ESP-IDF SPI LL 动作 → 对应寄存器头文件的偏移/位域 → Linux provider 的实现 → SPI 消费者的调用。GPSPI2 时钟/复位控制位在 HP_SYS_CLKRST 的 `0x06c` 偏移，不能套用 I2C 位布局，也不能加到 SPI 自身 MMIO 基址上。

加注释前的六个文件和已有源码差异保存在 `/userdata/esp32s31/backups/stage1-comments-20261031-120844-265128/`。六文件的最新逻辑和注释已保存为源码提交 `37b5e36b3`，并导出为 external 构建补丁 `0008`；前置的设备树和 MMIO 映射提交 `c50958427` 已导出为 `0007`。

## 构建与下一步验收

学习方式：用户阅读资料、修改代码并执行编译/烧录；协作者解释、核对 diff 和日志。新增实现的编译、链接、打包、刷写与实机功能验收分别记录。

修改内核源码后，增量构建先执行：

```sh
cd /userdata/esp32s31
make -C sources/buildroot O=/userdata/esp32s31/output-mosaico BR2_JLEVEL=6 linux-rebuild
```

它重新编译/链接内核和 DTB，并复制到 `output-mosaico/images/`，不代表完整 NOR 镜像已经重新打包。第一阶段代码的这一步已由用户完成；仅增加注释后不需要为了运行行为重复刷写。

后续每次产生新版本时，由用户依次完成完整构建、检查和候选冻结；前一步成功后再执行下一步：

```sh
bash scripts/build-mosaico-usb.sh
cat logs/build-usb.status logs/build-usb.exit
sha256sum -c output-mosaico/images/SHA256SUMS
python3 scripts/stage-usb-candidate.py
```

完整构建预期为 `complete`、退出码 `0`；校验预期为 `OK`。候选脚本核对打包组件、复制独立候选并更新 `checks/usb-flash-plan.json`，不会执行烧录。随后核对新候选，再单独进行物理下载模式操作、烧录和正常启动。

第一阶段已收到 `hardware init ready: core=20000000 Hz, CMD=0x00000000` 启动日志及 USB/SSH 登录记录；后续版本上板仍需检查时钟 provider、初始化日志和 USB/SSH。时钟注册数量只证明软件资源注册；频率是根据寄存器计算的值；初始化日志不能代替实际 SPI 波形和收发测试。

下一步按学习路线进入最小单线 PIO 发送，逐步实现 Mode、时钟分频、长度、缓冲区、UPDATE、启动与有超时的完成等待。

## 源码提交与可重建输入

源码提交 `c50958427` 保存设备树节点和 MMIO 映射；提交 `37b5e36b3` 保存第一阶段六文件硬件初始化实现及学习注释，提交说明记录用户提供的启动日志。

```sh
cd /userdata/esp32s31/output-mosaico/build/linux-custom
git status --short
git diff --check
git diff
```

源码提交不会自动更新构建补丁。本阶段已将两个源码提交导出到 `/userdata/esp32s31/mosaico-usb-external/patches/linux/`：

- `0007-esp32s31-gpspi2-dt-mmio.patch`：设备树节点、板级启用及 MMIO 映射。
- `0008-esp32s31-gpspi2-hardware-init.patch`：时钟/复位资源、初始化实现及学习注释。

已在独立 Git 索引中从 `baseline/espressif-linux` 顺序应用 `0001`～`0008`，所得完整源码树与 `37b5e36b3` 完全一致；另用 Buildroot 自身的 `support/scripts/apply-patches.sh` 在临时目录应用八份补丁，13 个涉及文件与当前源码逐字节一致，无 fuzz 或 offset。USB 板级 DTS 原料已同步，UART 原料原本一致。验证证据位于 `/userdata/esp32s31/checks/stage1-patch-export-6hwzcmmm/`。

本次验证了补丁链和源码一致性，没有重新编译整套系统或烧录。现有工作树和固件保持原状。后续新增实现仍需重新导出对应补丁。

执行 `linux-dirclean` 或从基线重新解包之前，必须完成所需版本保存和补丁整理。否则即便源码 Git 历史仍在，Buildroot 也不会自动把最新实现重新加入固件。

## 日常开发与 GitHub 同步

源码 Git 与项目 Git 是两个独立仓库。先在 `output-mosaico/build/linux-custom` 保存并验证源码，再将新增提交导出为后续编号的补丁，最后在项目仓库提交补丁、配置或文档并推送。仅提交 Linux 源码不会自动同步项目仓库；源码仓库历史也不随本项目一同发布。

```sh
cd /userdata/esp32s31
git status --short
git diff
# 审阅后只暂存本次相关文件，再提交
git add -- <本次修改的文件>
git commit -m "说明本次修改与验证结果"
git push origin main
```

2026-11-01 已创建公开仓库并完成首次推送。RK3588 已通过仓库专用 Deploy Key 实测 `git fetch` 和 `git push`；使用 SSH 443 端口及经 GitHub 官方接口核对的主机公钥。密钥保存在本机 `private/github/`，由忽略规则排除，不随 Git 同步；这把密钥只获得本仓库的读写权限。新机器需要自行配置认证。

后续提交已配置为当前账号的 GitHub 隐私邮箱，并核对首笔新提交关联到 `martin666888`。保留历史提交的原始作者、时间与验证边界，不为贡献图修改历史。历史 Gmail 地址是否关联账号需由账号所有者在 GitHub 邮箱设置中核对。

## 上游来源与许可证

本仓库的原创新增脚本、配置修改和学习文档采用 GPL-2.0-only，许可证正文见 [LICENSE](LICENSE)。文件已有的 SPDX 标识、版权和上游许可证优先；本仓库的许可证不改写第三方代码的授权。

- Linux 与 Linux 补丁保留 Linux 上游及文件级许可；U-Boot 补丁保留对应上游和文件级许可。
- 两套 `mosaico-*-external` 树基于乐鑫 `esp-buildroot-external` 的锁定版本进行适配；该版本未附根许可证文件，本项目不将继承内容另行声明为原创或替其指定许可。版本与仓库地址见 `sources.lock.json`。
- Buildroot、OpenSBI、工具链、esp-linux-bsp 等外部依赖分别保留其原有许可；依赖并未作为完整源码或二进制随本仓库发布。

本项目是个人学习与适配工程，与乐鑫官方 BSP 保持来源区分，不代表官方维护或完整外设支持。
