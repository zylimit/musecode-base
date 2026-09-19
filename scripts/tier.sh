#!/bin/bash
# tier.sh — 工程档位状态（fast/standard/strict）最小实现。
# 出处：本仓自写。
# 退役条件：人工档位连续两季无人设置（tier.json 从未出现）则删。
# 语义见 docs/LARGE-REPO.md §7：fast 必带 reason、8h 硬上限、到期自回；改家底建议 strict（显示规则，无机器强制）。
# 用法：bash scripts/tier.sh on [hours] [reason]|off|status
#   on:   进 fast（hours 默认 8，上限 8；reason 必填，无 reason 拒绝）
#   off:  回 standard（需 reason？否：回落是安全方向，直接回）
#   status: 显示当前档 + 来源（raise/expired/manual）
# 状态文件：.agents/harness-state/tier.json（git 忽略）。退出码：0 / 2 用法错。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
STATE=".agents/harness-state/tier.json"
HOUSE_DIRS=(AGENTS.md ARCHITECTURE.md docs/ scripts/ .agents/skills/ .muse/hooks.json)

usage() { sed -n '2,9p' "$0"; }
cmd="${1:-status}"
case "$cmd" in on|off|status) ;; *) usage >&2; exit 2;; esac

now_epoch() { date +%s 2>/dev/null || python3 -c 'import time;print(int(time.time()))'; }

# raise 检测：工作树相对 HEAD 改了家底路径 → 本轮 strict
is_house() { # $1=file -> 0 家底内（目录项按前缀，文件项按全等）
  local f="$1" h
  for h in "${HOUSE_DIRS[@]}"; do
    case "$h" in
      */) case "$f" in "$h"*) return 0;; esac ;;
      *) [ "$f" = "$h" ] && return 0 ;;
    esac
  done
  return 1
}
raised_by() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  local changed; changed="$(git status --porcelain 2>/dev/null | awk '{print $2}' || true)"
  [ -z "$changed" ] && return 1
  local hit=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if is_house "$f"; then hit="$f"; break; fi
  done <<< "$changed"
  [ -n "$hit" ] && { printf '%s' "$hit"; return 0; }
  return 1
}

read_state() { # -> "tier|expires|reason" or empty
  [ -f "$STATE" ] || return 1
  python3 - "$STATE" 2>/dev/null <<'PY' || return 1
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
    print(f"{d.get('tier','')}|{d.get('expires',0)}|{d.get('reason','')}")
except Exception:
    sys.exit(1)
PY
}

case "$cmd" in
  status)
    if r="$(raised_by)"; then echo "tier: strict (source: raise, file: $r)"; exit 0; fi
    if s="$(read_state)" && [ -n "$s" ]; then
      tier="${s%%|*}"; rest="${s#*|}"; exp="${rest%%|*}"; reason="${rest#*|}"
      now="$(now_epoch)"
      if [ "$tier" = "fast" ] && [ "$now" -ge "$exp" ] 2>/dev/null; then
        echo "tier: standard (source: expired, fast lapsed)"; exit 0
      fi
      echo "tier: $tier (source: manual, reason: ${reason:-none})"; exit 0
    fi
    echo "tier: standard (source: default)"; exit 0
    ;;
  off)
    mkdir -p "$(dirname "$STATE")" 2>/dev/null || { echo "tier: 状态不可写：$STATE（sandbox 只读？）" >&2; exit 2; }
    printf '{"tier":"standard","reason":"tier off"}\n' > "$STATE" 2>/dev/null || { echo "tier: 状态不可写：$STATE（sandbox 只读？）" >&2; exit 2; }
    echo "tier: standard"; exit 0
    ;;
  on)
    hours="${2:-8}"; reason="${3:-}"
    case "$hours" in ''|*[!0-9]*|0) echo "tier: hours 必须是正整数" >&2; exit 2;; esac
    [ "$hours" -gt 8 ] && { echo "tier: hours 上限 8（截断为 8）" >&2; hours=8; }
    [ -z "$reason" ] && { echo "tier: fast 必带 reason（用法：tier.sh on [hours] <reason>）" >&2; exit 2; }
    mkdir -p "$(dirname "$STATE")" 2>/dev/null || { echo "tier: 状态不可写：$STATE（sandbox 只读？）" >&2; exit 2; }
    exp=$(( $(now_epoch) + hours * 3600 ))
    printf '{"tier":"fast","hours":%s,"expires":%s,"reason":%s}\n' "$hours" "$exp" \
      "$(printf '%s' "$reason" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')" > "$STATE" 2>/dev/null || { echo "tier: 状态不可写：$STATE（sandbox 只读？）" >&2; exit 2; }
    echo "tier: fast (${hours}h, reason: $reason)"; exit 0
    ;;
esac
