#!/bin/bash
# check.sh — H5 需求→ADR→交付链检查：REQ 静态闸 + ADR 执法校验 + 三件套存在性。
# 用法：bash scripts/check.sh [--req FILE] [--help]
# 退出码：0 全绿 / 2 有 error 级 finding / 3 降级（无 REQ/ADR 可查）/ 1 用法错
# 规则（error 拦，warn 只报）：PLACEHOLDER / PENDING_IN_REQUIREMENT / NO_SOURCE_MARK /
#   PENDING_ROW_INCOMPLETE / ADR_GHOST_REF / ADR_ENFORCEMENT_MISSING(warn)。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
usage() { sed -n '2,7p' "$0"; }

REQ_ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --req) [ $# -ge 2 ] || { echo "check: --req needs a value" >&2; exit 1; }; REQ_ONLY="$2"; shift 2 ;;
    --req=*) REQ_ONLY="${1#--req=}"; shift ;;
    -*) echo "check: unknown flag $1" >&2; usage >&2; exit 1 ;;
    *) echo "check: unexpected positional $1" >&2; usage >&2; exit 1 ;;
  esac
done

ERR=0; WARN=0; CHECKED=0
err() { ERR=$((ERR+1)); echo "ERROR[$1]: $2"; }
warn() { WARN=$((WARN+1)); echo "WARN[$1]: $2"; }
info() { echo "INFO: $1"; }

check_req() { # check_req <file>
  local f="$1"; CHECKED=$((CHECKED+1))
  [ -f "$f" ] || { err "REQ_MISSING" "$f not found"; return; }
  # PLACEHOLDER（待定表内的“待定”二字放过：先删待定表节再扫）
  local body; body="$(awk '/^## .*待定/{flag=1} /^## /{if ($0 !~ /待定/) flag=0} !flag' "$f")"
  if printf '%s' "$body" | grep -qE 'NNNN|YYYY-MM-DD|<slug>|TBD|待补|TODO\(req\)'; then # musecode-fitness:ignore (this line is the placeholder pattern, not a deferral)
    err "PLACEHOLDER" "$f 含占位残留"
  fi
  # PENDING_IN_REQUIREMENT：功能需求节内出现 [待定]
  local func; func="$(awk '/^## .*(功能需求|FR)/{flag=1} flag&&/^## /{c++; if (c>1) exit} flag' "$f")"
  if printf '%s' "$func" | grep -q '\[待定\]'; then
    err "PENDING_IN_REQUIREMENT" "$f 功能条目挂 [待定]（待定只许在待定表）"
  fi
  # NO_SOURCE_MARK：FR 编号行无四标记
  local nomark; nomark="$(printf '%s' "$func" | grep -E 'FR-[0-9]+' | grep -vE '\[确认\]|\[推断\]|\[默认\]|\[待定\]' || true)"
  if [ -n "$nomark" ]; then err "NO_SOURCE_MARK" "$f 有 FR 行无来源标记"; fi
  # PENDING_ROW_INCOMPLETE：待定表行非五格
  local pending; pending="$(awk '/^## .*待定/{flag=1} flag&&/^## /{c++; if (c>1) exit} flag' "$f" | grep -E '^\|' | tail -n +3 || true)"
  if [ -n "$pending" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      cells="$(printf '%s' "$line" | awk -F'|' '{print NF-2}')"
      if [ "$cells" -lt 5 ] 2>/dev/null; then err "PENDING_ROW_INCOMPLETE" "$f 待定表行不足五格: $line"; fi
    done <<< "$pending"
  fi
}

check_adr() { # check_adr <file>
  local f="$1"; CHECKED=$((CHECKED+1))
  local enf; enf="$(grep -iE 'Enforced-by|执法方式' "$f" | head -n 3 || true)"
  if [ -z "$enf" ]; then warn "ADR_ENFORCEMENT_MISSING" "$f 缺 Enforced-by/执法方式"; return; fi
  # 幽灵引用：Enforced-by 提到 scripts/ 路径必须存在；manual: 显式留痕即过
  if printf '%s' "$enf" | grep -qE 'manual:'; then return; fi
  local refs; refs="$(printf '%s' "$enf" | grep -oE 'scripts/[A-Za-z0-9_.-]+\.(sh|mjs|js|py)' || true)"
  for r in $refs; do
    [ -f "$r" ] || err "ADR_GHOST_REF" "$f Enforced-by 指向不存在的 $r"
  done
  grep -qiE 'revisit-if|复评|revisit' "$f" || warn "ADR_REVISIT_MISSING" "$f 缺 revisit-if（写条件不写日期）"
  grep -qiE 'reversal|撤回|回滚' "$f" || warn "ADR_REVERSAL_MISSING" "$f 缺 reversal/撤回代价"
}

if [ -n "$REQ_ONLY" ]; then
  check_req "$REQ_ONLY"
else
  found=0
  for f in docs/REQ-*.md; do [ -e "$f" ] || continue; found=1; check_req "$f"; done
  for f in docs/adr/[0-9]*-*.md; do [ -e "$f" ] || continue; found=1; check_adr "$f"; done
  if [ "$found" -eq 0 ]; then info "no REQ/ADR docs present (scaffold without active requirements)"; fi
  # 三件套存在性（报告级）：src 有改而无 REQ/测试同改则 warn
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git diff --name-only HEAD 2>/dev/null | grep -qE '^src/'; then
      git diff --name-only HEAD 2>/dev/null | grep -qE '^(docs/REQ-|tests/)' \
        || warn "TRIO_INCOMPLETE" "src 有改但本次 diff 无 REQ/测试同改"
    fi
  fi
fi

echo "---"
echo "check: files=$CHECKED errors=$ERR warnings=$WARN"
if [ "$ERR" -gt 0 ]; then echo "CHECK FAILED"; exit 2; fi
if [ "$CHECKED" -eq 0 ]; then echo "CHECK DEGRADED (nothing to check)"; exit 3; fi
echo "CHECK PASSED"
exit 0
