#!/bin/bash
# setup.sh — 把 musecode-base 框架资产注入式安装到目标项目（Mac/Linux）。
# 用法：./setup.sh [--dry-run] [target_dir]   不给 target 默认当前目录 "."
# 安装契约（最小）：只创建不修改。目标缺失→create；相同→skip；不同→conflict，
#   新版本落旁边的 <file>.framework-new（已有 sidecar 永不覆盖）。无 update 语义，
#   无 staging/backup/rollback：dry-run 零写只出计划。
# 私产边界：反馈历史/索引、角色战术笔记、本仓 catalog 与基线不分发；
#   只发公共模板与约定，目标索引缺失时初始化空表头。
# 退出码：0 成功；1 有复制失败（逐个 ERROR 行报告）；2 用法错。
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
# 公共：规则/角色/反馈模板/战术笔记约定随框架走；
# 私有：反馈索引与历史、角色 MEMORY、.example 之外的本仓 catalog/基线不发。
PAYLOAD="AGENTS.md ARCHITECTURE.md HARNESS.md README.md SCALING.md .gitignore FRAMEWORK-MANIFEST.json setup.sh setup.ps1 .agents/agent-memory/README.md"
PAYLOAD_DIRS="docs .agents/skills .agents/memory .agents/workflows .agents/harness .agents/rules .agents/agents .agents/feedback/templates scripts src tests .muse"
SKIP_RX='harness-state/|\.framework-new$|\.bak$|/evidence/|__pycache__|\.pyc$|\.pytest_cache|/\.git/|node_modules|\.DS_Store|\.mypy_cache|\.ruff_cache|module-catalog\.json$|arch-baseline\.json$'
FEEDBACK_INDEX=".agents/feedback/FEEDBACK-INDEX.md"

C_CREATE=0; C_CONFLICT=0; C_SKIP=0; C_FAIL=0
fail() { echo "ERROR: $1" >&2; C_FAIL=$((C_FAIL+1)); }
plan_file() { # plan_file <rel>
  local rel="$1"; local s="$SRC/$rel" t="$TARGET/$rel"
  if [ ! -f "$s" ]; then return 0; fi
  if [ ! -e "$t" ]; then echo "create   $rel"; C_CREATE=$((C_CREATE+1));
  elif cmp -s "$s" "$t"; then echo "skip     $rel (identical)"; C_SKIP=$((C_SKIP+1));
  elif [ -e "$t.framework-new" ]; then echo "conflict $rel (keep existing sidecar)"; C_CONFLICT=$((C_CONFLICT+1));
  else echo "conflict $rel -> $rel.framework-new"; C_CONFLICT=$((C_CONFLICT+1)); fi
}
do_file() {
  local rel="$1"; local s="$SRC/$rel" t="$TARGET/$rel"
  [ -f "$s" ] || return 0
  mkdir -p "$(dirname "$t")" || { fail "mkdir $(dirname "$t")"; return 0; }
  if [ ! -e "$t" ]; then cp "$s" "$t" || { fail "copy $rel"; return 0; }; C_CREATE=$((C_CREATE+1));
  elif cmp -s "$s" "$t"; then C_SKIP=$((C_SKIP+1));
  elif [ -e "$t.framework-new" ] && cmp -s "$s" "$t.framework-new"; then C_SKIP=$((C_SKIP+1));
  elif [ -e "$t.framework-new" ]; then echo "keep     $rel.framework-new (已有 sidecar，不覆盖)" >&2; C_CONFLICT=$((C_CONFLICT+1));
  else cp "$s" "$t.framework-new" || { fail "copy $rel.framework-new"; return 0; }; C_CONFLICT=$((C_CONFLICT+1)); fi
}
init_feedback_index() { # 缺失才初始化空表头，永不覆盖
  local t="$TARGET/$FEEDBACK_INDEX"
  [ -e "$t" ] && return 0
  mkdir -p "$(dirname "$t")" || { fail "mkdir $(dirname "$t")"; return 0; }
  cat > "$t" <<'EOF' || { fail "init $FEEDBACK_INDEX"; return 0; }
# Feedback Index

> 经验教训索引。新建或更新 feedback 文件后，同步更新此索引。
> 格式：每条一行，`- [标题](文件名.md) — 一句话描述`
> 模板：templates/feedback-topic-template.md
> 毕业/跳过状态看各文件 frontmatter（graduated/skipped），供 evolution-engine 扫描。
EOF
  C_CREATE=$((C_CREATE+1))
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
  [ -e "$TARGET/$FEEDBACK_INDEX" ] || echo "init     $FEEDBACK_INDEX (absent)"
  echo "plan: create=$C_CREATE conflict=$C_CONFLICT skip=$C_SKIP"
  exit 0
fi

mkdir -p "$TARGET" || { echo "ERROR: mkdir $TARGET" >&2; exit 1; }
each_payload do_file
init_feedback_index
echo "installed: $SRC -> $TARGET"
echo "result: create=$C_CREATE conflict=$C_CONFLICT skip=$C_SKIP fail=$C_FAIL"
[ "$C_CONFLICT" -gt 0 ] && echo "note: *.framework-new 需手工合并（你的定制未被覆盖）"
[ "$C_FAIL" -gt 0 ] && { echo "setup: $C_FAIL 个文件复制失败" >&2; exit 1; }
exit 0
