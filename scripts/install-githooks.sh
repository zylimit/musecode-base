#!/bin/bash
# install-githooks.sh — 安装/卸载本仓 git hooks（经 core.hooksPath 指向版本化的 scripts/githooks/）。
# 来源模型：cc-base githooks（版本化单源 + 占用拒绝）。
# 退役条件：改用原生 hooks 接线时删。
# 用法：bash scripts/install-githooks.sh on|off|status
#   on:     core.hooksPath -> scripts/githooks（已有非本仓值则拒绝，不覆盖 husky 等）
#   off:    仅当 core.hooksPath 指向本仓时才 unset
#   status: 报告安装态
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
TARGET="scripts/githooks"

cmd="${1:-status}"
case "$cmd" in on|off|status) ;; *) echo "usage: install-githooks.sh on|off|status" >&2; exit 2;; esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "install-githooks: 非 git 仓（先 git init）" >&2; exit 2; }
cur="$(git config --local core.hooksPath 2>/dev/null || true)" # musecode-fitness:ignore no-silent-failure reason="absent config means empty string, handled below"

if [ "$cmd" = "status" ]; then
  if [ "$cur" = "$TARGET" ]; then echo "githooks: installed (core.hooksPath=$TARGET)";
  elif [ -n "$cur" ]; then echo "githooks: occupied by $cur (refusing to touch)";
  else echo "githooks: absent"; fi
  exit 0
fi

if [ "$cmd" = "off" ]; then
  if [ "$cur" = "$TARGET" ]; then git config --local --unset core.hooksPath; echo "githooks: uninstalled";
  else echo "githooks: kept (not ours: ${cur:-absent})"; fi
  exit 0
fi

# on
if [ -n "$cur" ] && [ "$cur" != "$TARGET" ]; then
  echo "install-githooks: core.hooksPath 已被占用（$cur），拒绝覆盖。请手动合并后再 on。" >&2; exit 2
fi
for h in pre-commit pre-push commit-msg; do
  [ -x "$TARGET/$h" ] || { echo "install-githooks: $TARGET/$h 缺失或无执行位" >&2; exit 2; }
done
git config --local core.hooksPath "$TARGET"
echo "githooks: installed (core.hooksPath=$TARGET)"
echo "  pre-commit: smoke + staged-check + staged fitness"
echo "  pre-push:   smoke + verify（文档-only 快速通道）"
echo "  commit-msg: 首行宽度 + 无信息词"
