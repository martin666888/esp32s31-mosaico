# ESP32-S31 / ESP-Mosaico V1.2 Linux 学习工程

本仓库管理 Mosaico 的板级配置、内核补丁、构建辅助脚本和阶段说明。RK3588 是构建与调试主机，ESP32-S31 是 Linux 运行目标。工程当前路径为 `/userdata/esp32s31`。

**接续开发前先读 [当前状态](docs/PROJECT-STATUS.md)。** 第一笔提交是 2026-10-26 接手时的现状快照，不代表此前工作在这一天完成，也不是过去开发历史的重建。

## 目录与职责

| 目录或文件 | 用途 | 根仓库是否跟踪 |
| --- | --- | --- |
| `mosaico-external/` | UART 启动变体的配置与补丁 | 是，密钥除外 |
| `mosaico-usb-external/` | 当前 USB NCM / SSH 变体及 SPI 骨架 | 是，密钥除外 |
| `scripts/` | 配置、构建、候选生成、烧录与验证辅助脚本 | 是；脚本入库不代表授权运行烧录 |
| `sources.lock.json`、`archives.lock.json` 等锁文件 | 固定上游版本、下载位置和摘要 | 是 |
| `official-patches/` | 重建官方源码版本的补丁及来源记录 | 是 |
| `docs/` | 阶段、证据位置和学习记录 | 是 |
| `sources/` | 官方源码基线，部分目录另有自己的 `.git` | 否，保持现状 |
| `output-mosaico/` | Buildroot 构建树、主机工具链和镜像 | 否，可重新生成 |
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

`sources/linux` 当前用于官方基线对照，不在这里直接开发本地驱动。构建树可以用于快速编译试验，但 `linux-dirclean` 会删除它。需要保留的改动必须生成补丁并检查能否从基线重新构建。

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

本地 Git 负责版本对比和回退，不代替磁盘备份。当前没有配置 Git 远端。新机器恢复构建还需要按锁文件准备源码、工具链及本机私有 SSH 输入；本仓库不是包含全部缓存和设备身份的一键恢复包。

## 继续学习的位置

现阶段先验收 SPI 骨架新候选的启动、USB 和 SSH 无回归；随后再让设备树匹配触发 `probe()`，并区分设备树资源声明与真实硬件地址证据。时钟、复位、寄存器和 SPI 收发属于后续阶段，当前尚未实现。

原有 [USB SSH 说明](USB-SSH-STATUS.md) 保留为 2026-10-19 已验证版本的操作记录。当前候选与验收状态以 [当前状态](docs/PROJECT-STATUS.md) 为准。
