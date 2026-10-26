#!/usr/bin/env python3
"""Inspect and back up the Linux learning worktree without committing user edits."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
WORKTREE = ROOT / "output-mosaico/build/linux-custom"
GITDIR = ROOT / ".linux-dev-git"


def git(*args):
    return subprocess.check_output(["git", "-C", str(WORKTREE), *args])


def attach():
    if not (GITDIR / "HEAD").is_file():
        raise RuntimeError("Linux Git history is missing; stop and inspect.")
    if not (WORKTREE / "Makefile").is_file() or not (WORKTREE / "drivers/spi/spi-esp32s31.c").is_file():
        raise RuntimeError("Expected patched Linux tree is missing. Build and inspect it first.")
    pointer = WORKTREE / ".git"
    expected = "gitdir: " + str(GITDIR) + "\n"
    if pointer.exists():
        if not pointer.is_file() or pointer.read_text() != expected:
            raise RuntimeError("An unexpected .git entry exists; nothing was changed.")
    else:
        pointer.write_text(expected)
    actual = Path(git("rev-parse", "--absolute-git-dir").decode().strip())
    if actual != GITDIR:
        raise RuntimeError("Git metadata path mismatch.")
    return WORKTREE


def backup():
    attach()
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    dest = ROOT / "backups" / ("linux-dev-" + stamp)
    dest.mkdir(parents=True)
    patch = git("diff", "--binary", "--full-index", "HEAD", "--")
    (dest / "working-tree.patch").write_bytes(patch)
    (dest / "status.txt").write_bytes(git("status", "--short"))
    extra = git("ls-files", "--others", "--exclude-standard", "-z").split(b"\0")
    names = [p.decode("utf-8") for p in extra if p]
    for name in names:
        src = WORKTREE / name
        dst = dest / "untracked" / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        if src.is_symlink():
            dst.symlink_to(src.readlink())
        else:
            shutil.copy2(src, dst)
    manifest = {
        "worktree": str(WORKTREE),
        "gitdir": str(GITDIR),
        "head": git("rev-parse", "HEAD").decode().strip(),
        "patch_sha256": hashlib.sha256(patch).hexdigest(),
        "untracked_paths": names,
        "note": "Includes tracked differences versus HEAD and nonignored untracked files. Ignored files, build outputs and editor-unsaved buffers are not backed up.",
    }
    (dest / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(dest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", "backup", "attach"])
    args = parser.parse_args()
    if args.action == "backup":
        backup()
    else:
        attach()
        if args.action == "status":
            sys.stdout.buffer.write(git("status", "--short"))
        else:
            print("Attached existing history to " + str(WORKTREE))


if __name__ == "__main__":
    main()
