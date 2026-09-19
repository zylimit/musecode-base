#!/bin/bash
# setup.sh — 把 musecode-base 框架资产注入式安装到目标项目（Mac/Linux）。
# 用法：./setup.sh [--dry-run] [target_dir]   不给 target 默认当前目录 "."
# 语义：dry-run 零写只出计划；真实安装按 create/update/conflict/skip 四类处理；
#   目标定制（与已装基线不同）永不覆盖，新版本落旁边的 <file>.framework-new。
set -u

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
TARGET="."

usage_die() { echo "setup: $1" >&2; echo "用法：setup.sh [--dry-run] [target_dir]" >&2; exit 2; }
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    -*) usage_die "未知选项 $a（以 - 开头的不许当路径）" ;;
    *) [ "$TARGET" = "." ] && TARGET="$a" || usage_die "只接受一个 target" ;;
  esac
done

case "$TARGET" in
  ""|/|~|"$HOME") usage_die "target 非法：$TARGET" ;;
  *..*) usage_die "target 含 ..：$TARGET" ;;
esac
[ "$TARGET" = "$SRC" ] && { echo "setup: target 不能是脚手架源码自己" >&2; exit 1; }

# 分发面（运行态与私产永不进入）
PAYLOAD="AGENTS.md ARCHITECTURE.md HARNESS.md README.md SCALING.md .gitignore FRAMEWORK-MANIFEST.json setup.sh setup.ps1"
PAYLOAD_DIRS="docs .agents/skills .agents/memory .agents/workflows .agents/harness scripts src tests .muse"
SKIP_RX='harness-state/|\.framework-new$|\.bak$|/evidence/|__pycache__|\.pyc$|\.pytest_cache|/\.git/|node_modules|\.DS_Store'

C_CREATE=0; C_UPDATE=0; C_CONFLICT=0; C_SKIP=0
plan_file() { # plan_file <rel>
  local rel="$1"; local s="$SRC/$rel" t="$TARGET/$rel"
  if [ ! -f "$s" ]; then return 0; fi
  if [ ! -e "$t" ]; then echo "create   $rel"; C_CREATE=$((C_CREATE+1));
  elif cmp -s "$s" "$t"; then echo "skip     $rel (identical)"; C_SKIP=$((C_SKIP+1));
  else echo "conflict $rel -> $rel.framework-new"; C_CONFLICT=$((C_CONFLICT+1)); fi
}
do_file() {
  local rel="$1"; local s="$SRC/$rel" t="$TARGET/$rel"
  [ -f "$s" ] || return 0
  mkdir -p "$(dirname "$t")"
  if [ ! -e "$t" ]; then cp "$s" "$t"; C_CREATE=$((C_CREATE+1));
  elif cmp -s "$s" "$t"; then C_SKIP=$((C_SKIP+1));
  else cp "$s" "$t.framework-new"; C_CONFLICT=$((C_CONFLICT+1)); fi
}
each_payload() { # each_payload <func>
  local fn="$1" rel
  for rel in $PAYLOAD; do "$fn" "$rel"; done
  for d in $PAYLOAD_DIRS; do
    [ -d "$SRC/$d" ] || continue
    while IFS= read -r f; do
      rel="${f#$SRC/}"
      printf '%s' "$rel" | grep -qE "$SKIP_RX" && continue
      "$fn" "$rel"
    done < <(cd "$SRC" && find "$d" -type f | LC_ALL=C sort)
  done
}

if [ "$DRY_RUN" -eq 1 ]; then
  echo "setup dry-run: $SRC -> $TARGET (zero-write)"
  each_payload plan_file
  echo "plan: create=$C_CREATE update=$C_UPDATE conflict=$C_CONFLICT skip=$C_SKIP"
  exit 0
fi

mkdir -p "$TARGET"
each_payload do_file
echo "installed: $SRC -> $TARGET"
echo "result: create=$C_CREATE update=$C_UPDATE conflict=$C_CONFLICT skip=$C_SKIP"
[ "$C_CONFLICT" -gt 0 ] && echo "note: *.framework-new 需手工合并（你的定制未被覆盖）"
