#!/bin/bash
# evidence.sh — red-blue-review 证据包：范围/改动清单/删除审计/新文件/完整 diff。
# 出处：本仓自写（行为对齐 cc-base 同名脚本）。
# 退役条件：red-blue-review 退役时同步删。
# 用法：bash evidence.sh [BASE] [HEAD|--working]
#   BASE 默认最近 tag（无 tag 则 HEAD~5），HEAD 默认 HEAD；--working 审未提交工作树。
# 退出码：0 产出证据包 / 2 ref 无效或用法错（失败响亮，不产空包）。
set -uo pipefail

BASE=""; HEAD="HEAD"; WORKING=0
usage() { sed -n '2,6p' "$0"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --working) WORKING=1; shift ;;
    -*) echo "evidence: unknown flag $1" >&2; usage >&2; exit 2 ;;
    *) if [ -z "$BASE" ]; then BASE="$1"; else HEAD="$1"; fi; shift ;;
  esac
done
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "evidence: not a git repository" >&2; exit 2; }

if [ "$WORKING" -eq 1 ]; then
  RANGE="WORKING TREE (unstaged + staged, untracked listed)"
  DIFF_CMD="git diff HEAD --"
  STAT_CMD="git diff HEAD --stat --"
else
  if [ -z "$BASE" ]; then BASE="$(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~5)"; fi
  git rev-parse --verify "$BASE" >/dev/null 2>&1 || { echo "evidence: invalid BASE ref: $BASE" >&2; exit 2; }
  git rev-parse --verify "$HEAD" >/dev/null 2>&1 || { echo "evidence: invalid HEAD ref: $HEAD" >&2; exit 2; }
  RANGE="$BASE..$HEAD"
  DIFF_CMD="git diff $BASE $HEAD --"
  STAT_CMD="git diff $BASE $HEAD --stat --"
fi

echo "# Red-Blue Evidence Pack"
echo "- 范围：$RANGE"
echo "- 生成：$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
echo
echo "## 改动清单"
$STAT_CMD || { echo "evidence: diff failed" >&2; exit 2; }
echo
echo "## 删除审计（重点：规则/skill/门禁/配置是否误删）"
if [ "$WORKING" -eq 1 ]; then git diff HEAD --name-status -- | awk '$1=="D"' || true
else git diff "$BASE" "$HEAD" --name-status -- | awk '$1=="D"' || true; fi
echo "(空 = 无删除)"
echo
echo "## 新文件"
if [ "$WORKING" -eq 1 ]; then { git diff HEAD --name-status -- | awk '$1=="A"' || true; git ls-files --others --exclude-standard || true; }
else git diff "$BASE" "$HEAD" --name-status -- | awk '$1=="A"' || true; fi
echo "(空 = 无新文件)"
echo
echo "## 完整 diff"
$DIFF_CMD
