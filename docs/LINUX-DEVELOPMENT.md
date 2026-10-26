# Linux 源码 Git 使用说明

本说明对应 /userdata/esp32s31。2026-10-26 补充源码 Git，保留现有构建方式和所有用户源码内容。

## 两个仓库各管什么

| 仓库工作目录 | 管理内容 |
| --- | --- |
| /userdata/esp32s31 | 补丁、配置、工程脚本和说明 |
| /userdata/esp32s31/output-mosaico/build/linux-custom | Linux 源码；编辑驱动、Kconfig、Makefile 后可直接看 diff |

Linux 仓库分支：codex/linux-learning。Git 数据实际保存在 /userdata/esp32s31/.linux-dev-git；构建目录中的 .git 是指向该目录的文本文件。两套仓库都未配置远端，不会自动推送。

初始化时从现有 sources/linux 暂存的官方基线复制 Git 对象及索引，再只在新仓库索引中依次应用 0001～0006。产生的是今天重建的基线快照及六笔补丁提交，不是找回了前任真实开发历史，也不是原始官方 commit。设置过程没有把源码切换回旧版本，没有修改用户代码。

标签 baseline/espressif-linux 对应现有官方源码快照，baseline/spi-stage1 对应应用六个补丁后的基线。用户已写的六行注释保留为未提交改动。

## 查看当前修改

在 RK3588 终端执行：

```sh
cd /userdata/esp32s31/output-mosaico/build/linux-custom
git status --short
git diff -- drivers/spi/spi-esp32s31.c
git log --oneline -8
```

编辑器没有自动发现新仓库时，命令面板选择 Git: Open Repository，打开上述 Linux 工作目录。原始 sources/linux 的无提交仓库可继续关闭显示；不删除其 .git。

Git 不保存编辑器尚未写入磁盘的内容。保存文件后 diff 才能显示。

## 备份未提交工作

```sh
python3 /userdata/esp32s31/scripts/linux-dev-git.py backup
```

命令会在 /userdata/esp32s31/backups/linux-dev-<时间>/ 保存：

- working-tree.patch：工作区相对 HEAD 的全部已跟踪改动，含已暂存和未暂存的最终内容，包含二进制差异。
- untracked/：未被忽略的新文件。
- status.txt、manifest.json：状态和基线提交号。

此备份不包含被忽略的文件、编译输出和编辑器未保存内容，也不保留暂存/未暂存的划分。脚本不会替用户提交。

初始化前另外备份了驱动、Kconfig、Makefile 三个文件，位置为 /userdata/esp32s31/backups/linux-git-setup-20261026-220118/；该目录还保存设置完成后的工作区补丁。

## 清理与重建的边界

Git 历史在构建目录之外，linux-dirclean 不会删除这些历史。但该命令仍会删除 Linux 工作树及其中未提交的代码；放在外面的 Git 历史不等于工作区自动备份。

执行 linux-dirclean、make clean 或删除输出目录之前，先备份并保存所需版本，确认源码改动已整理到补丁。不要用 git clean 清理当前混合源码与构建产物目录。

重建完成、六个补丁已应用后，可重新连接现有 Git 历史：

```sh
python3 /userdata/esp32s31/scripts/linux-dev-git.py attach
```

attach 只恢复 .git 指针，不覆盖源码、不自动恢复改动。恢复备份需核对 manifest 的 HEAD 与当前源码状态后，再用 git apply --check 检查相应 working-tree.patch；如果补丁已进入重建源码，不要重复应用。

## 源码 Git 与构建补丁的关系

源码 Git 解决每天写代码、看差异、保存阶段版本的问题；external 树补丁决定清理之后 Buildroot 能否重现这些改动。提交源码不会自动更新 external 补丁。内核配置片段仍由工程根仓库管理。

每个阶段先查看源码 diff，检查和编译必要内容，再把需要交付的源码变化整理成补丁并复验；更新阶段记录。提交按用户指令进行，刷写另需明确授权。
