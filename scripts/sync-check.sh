#!/bin/bash
# sync-check.sh — 三文件同步检查（three-file-sync 的可执行版，可作 Muse Stop hook 命令）。
# 出处：本仓自写。
# 退役条件：三文件连续两季零漂移则删（或并入 check.sh）。
# 规则：工作树有未提交代码改动但 progress.md 没动 → 提醒记账；
#   REQ 脏了 → 提醒检查 §变更记录 是否追加。
# 用法：bash scripts/sync-check.sh [--help]
# 退出码：0 同步/无需提醒 / 1 有提醒（提醒即目的，会话内不阻断；CI 内可作 warn）/ 2 用法错。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
[ "${1:-}" = "--help" ] && { sed -n '2,6p' "$0"; exit 0; }
[ $# -gt 0 ] && { echo "sync-check: no arguments expected" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "sync-check: 非 git 仓，跳过"; exit 0; }

REMIND=0
dirty="$(git status --porcelain 2>/dev/null | awk '{print $2}' || true)"
[ -z "$dirty" ] && { echo "sync-check: 工作树干净"; exit 0; }

code_dirty="$(printf '%s' "$dirty" | grep -vE '^(progress\.md|progress\.archive\.md|docs/REQ-.*\.md)$' || true)"
if [ -n "$code_dirty" ] && ! printf '%s' "$dirty" | grep -qx "progress.md"; then
  echo "REMIND[progress]: 有代码改动但 progress.md 未动——决策/约束/完成请记账"
  REMIND=1
fi
if printf '%s' "$dirty" | grep -qE '^docs/REQ-.*\.md$'; then
  echo "REMIND[changelog]: REQ 脏了——检查 §变更记录 是否追加（只改其一不算）"
  REMIND=1
fi
[ "$REMIND" -eq 0 ] && echo "sync-check: 同步"
exit "$REMIND"
