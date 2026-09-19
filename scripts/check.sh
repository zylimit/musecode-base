#!/bin/bash
# check.sh — H5 需求→ADR→交付链检查：REQ 静态闸 + ADR 执法校验 + 三件套存在性。
# 出处：本仓自写；方法来源见 docs/CROSS-POLLINATION.md（X7/C8）。
# 退役条件：REQ/ADR 模板停用则删对应段；全段无对象连续两季则删文件。
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
  if printf '%s' "$body" | grep -qE 'NNNN|YYYY-MM-DD|<slug>|TBD|待补|TODO\(req\)'; then # musecode-fitness:ignore todo-without-owner reason="this line is the placeholder pattern, not a deferral"
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

check_trace() { # check_trace: requirement-trace.json 存在即验（需求→路径+检查的追溯闭环）
  local t=".agents/harness/requirement-trace.json"
  [ -f "$t" ] || return 0
  CHECKED=$((CHECKED+1))
  python3 - "$t" <<'PY' || ERR=$((ERR+1))
import json, re, sys
from pathlib import Path
try:
    trace = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:
    print(f"ERROR[TRACE_PARSE]: {e}")
    sys.exit(1)
known_ids = set()
for req in Path("docs").glob("REQ-*.md"):
    known_ids.update(re.findall(r"\b(?:FR|R|SC|OUT|SCOPE|Q)-\d+\b", req.read_text(encoding="utf-8")))
known_checks = set()
try:
    cat = json.load(open(".agents/harness/module-catalog.json", encoding="utf-8"))
    known_checks = set((cat.get("checks") or {}).keys())
except Exception:
    pass
bad = 0
for entry in trace.get("trace", []):
    rid = entry.get("requirement", "")
    if rid and rid not in known_ids:
        print(f"ERROR[TRACE_GHOST_REQ]: {rid} 在 REQ 中不存在"); bad = 1
    for p in entry.get("paths", []):
        if not Path(p).exists():
            print(f"ERROR[TRACE_GHOST_PATH]: {rid} -> {p} 不存在"); bad = 1
    for c in entry.get("checks", []):
        if known_checks and c not in known_checks and not Path(f"scripts/{c}").exists():
            print(f"ERROR[TRACE_GHOST_CHECK]: {rid} -> {c} 未知检查"); bad = 1
sys.exit(bad)
PY
}

if [ -n "$REQ_ONLY" ]; then
  check_req "$REQ_ONLY"
else
  check_trace
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
