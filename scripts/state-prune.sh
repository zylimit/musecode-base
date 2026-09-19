#!/bin/bash
# state-prune.sh — 运行态保留与销毁（默认 dry-run，只报告；--apply 才动手）。
# 出处：本仓自写；方法来源见 docs/CROSS-POLLINATION.md（X13）。
# 退役条件：运行态目录一年无超限/残留则删（改人工看）。
# 策略见 docs/MEMORY_GUIDE.md §5：gate-block.log 留 2000 行、test-ledger.jsonl 留 5000 行、
# harness-state 总量超 50MB 告警、evidence 超 30 天列出；活动 task 引用的 evidence 永不删。
# 用法：bash scripts/state-prune.sh [--apply] [--help]
# 退出码：0（报告/执行成功）/ 2 用法错。销毁失败显式报告，不静默。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
usage() { sed -n '2,6p' "$0"; }
APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --apply) APPLY=1; shift ;;
    -*) echo "state-prune: unknown flag $1" >&2; usage >&2; exit 2 ;;
    *) echo "state-prune: unexpected positional $1" >&2; usage >&2; exit 2 ;;
  esac
done

STATE=".agents/harness-state"
EVID=".agents/evidence"
ACTIONS=0
say() { echo "$1"; }
do_prune_file() { # do_prune_file <file> <keep-lines>
  local f="$1" keep="$2" n
  [ -f "$f" ] || return 0
  n="$(wc -l < "$f" | tr -d ' ')"
  [ "$n" -gt "$keep" ] || return 0
  ACTIONS=$((ACTIONS+1))
  if [ "$APPLY" -eq 1 ]; then
    tail -n "$keep" "$f" > "$f.tmp" && mv "$f.tmp" "$f" \
      && say "PRUNED $f: $n -> $keep lines" || { echo "FAILED to prune $f" >&2; exit 1; }
  else
    say "WOULD-PRUNE $f: $n lines -> keep last $keep (run --apply)"
  fi
}

do_prune_file "$STATE/gate-block.log" 2000
do_prune_file "$STATE/test-ledger.jsonl" 5000

if [ -d "$STATE" ]; then
  size_kb="$(du -sk "$STATE" 2>/dev/null | awk '{print $1}')"
  if [ "${size_kb:-0}" -gt 51200 ] 2>/dev/null; then
    ACTIONS=$((ACTIONS+1)); say "ALERT $STATE size ${size_kb}KB > 50MB — inspect manually, never auto-deleted"
  fi
fi
if [ -d "$EVID" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    ACTIONS=$((ACTIONS+1)); say "STALE $f (>30d, review before delete)"
  done < <(find "$EVID" -type f -mtime +30 2>/dev/null || true) # musecode-fitness:ignore no-silent-failure reason="missing dir means no stale files"
fi

# 损坏 JSON 只报不修（修之前先 quarantine 人工看）
for f in "$STATE/tier.json" "$STATE/arch-trend.jsonl"; do
  [ -f "$f" ] || continue
  case "$f" in *.json) python3 -c "import json,sys;json.load(open('$f'))" 2>/dev/null || say "CORRUPT $f (quarantine: inspect before delete)";; esac
done

[ "$ACTIONS" -eq 0 ] && say "state-prune: nothing to do"
[ "$APPLY" -eq 0 ] && [ "$ACTIONS" -gt 0 ] && say "(dry-run: nothing changed)"
exit 0
