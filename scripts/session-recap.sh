#!/bin/bash
# session-recap.sh — 从 progress.md 派生预算内摘要（Pinned + Decisions 现存 + 待办 + 断点）。
# 出处：本仓自写。
# 退役条件：主 Agent 连续一季不消费其输出则删（以真实调用为准）。
# 用途：/recap 恢复、压缩后回注、交接。只读 progress.md 与 REQ CHANGELOG，不读归档。
# 用法：bash scripts/session-recap.sh [--max-lines N] [--help]
# 退出码：0 / 2 用法错。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
usage() { sed -n '2,5p' "$0"; }
MAX=60
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --max-lines) MAX="$2"; shift 2 ;;
    --max-lines=*) MAX="${1#--max-lines=}"; shift ;;
    -*) echo "session-recap: unknown flag $1" >&2; usage >&2; exit 2 ;;
    *) echo "session-recap: unexpected positional $1" >&2; usage >&2; exit 2 ;;
  esac
done
[ -f progress.md ] || { echo "session-recap: 无 progress.md"; exit 0; }

out="$(mktemp)"
{
  echo "# Recap（派生自 progress.md，不含归档）"
  echo "## Pinned（前 12 条）"
  awk '/^## Pinned/{f=1;next} /^## /{f=0} f' progress.md | head -n 12
  echo "## Decisions（现存，撇去被取代）"
  awk '/^## Decisions/{f=1;next} /^## /{f=0} f' progress.md | grep -v "→ 被" | head -n 20
  echo "## 待办（未勾选）"
  grep -E "^- \[ \]" progress.md | head -n 15 || true
  echo "## 断点（In Progress / Risks）"
  awk '/^## (In Progress|Risks)/{f=1;next} /^## /{f=0} f' progress.md | head -n 10
} > "$out"
head -n "$MAX" "$out"
echo "(budget: 最多 $MAX 行，完整读 progress.md + REQ + CHANGELOG)"
rm -f "$out"
exit 0
