#!/bin/bash
# verify.sh — H4 验证门禁：smoke → 按栈 lint → 触及面测试（探测式，不硬依赖）。
# 用法：bash scripts/verify.sh [--base REV] [--all] [--help]
#   --base REV  触及面 diff 基线（默认 HEAD；非 git 仓则退化为全量静态检查）
#   --all       忽略触及面，全量跑（慢）
# 退出码：0 全绿 / 2 有 FAIL 或 BLOCKED（门阻断）/ 3 降级（无可跑检查，未建立结论）/ 1 用法错
# 单 check 四态：PASS / FAIL / BLOCKED（缺工具缺定义）/ SKIPPED（平台不适用）。
# 约定：BLOCKED/SKIPPED 永不读作 PASS；全 SKIPPED → rc 3。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

BASE="HEAD"
FULL=0
usage() { sed -n '2,9p' "$0"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --all) FULL=1; shift ;;
    --base) [ $# -ge 2 ] || { echo "verify: --base needs a value" >&2; exit 1; }; BASE="$2"; shift 2 ;;
    --base=*) BASE="${1#--base=}"; shift ;;
    -*) echo "verify: unknown flag $1" >&2; usage >&2; exit 1 ;;
    *) echo "verify: unexpected positional $1" >&2; usage >&2; exit 1 ;;
  esac
done

PASS=0; FAIL=0; BLOCKED=0; SKIPPED=0
gate_log() { mkdir -p .agents/harness-state; printf '%s\tverify\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$1" >> .agents/harness-state/gate-block.log 2>/dev/null || true; } # musecode-fitness:ignore (ledger is a side channel by design: must never change the verdict)
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $1"; gate_log "FAIL $1"; }
blocked() { BLOCKED=$((BLOCKED+1)); echo "BLOCKED: $1"; gate_log "BLOCKED $1"; }
skipped() { SKIPPED=$((SKIPPED+1)); echo "SKIPPED: $1"; }

# 0. 地基：smoke 必须先绿
if bash scripts/smoke.sh >/tmp/verify_smoke.log 2>&1; then pass "smoke.sh green"; else fail "smoke.sh red (see /tmp/verify_smoke.log)"; fi

# 触及面
CHANGED=""
if [ "$FULL" -eq 1 ]; then CHANGED="FULL";
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then CHANGED="$(git diff --name-only "$BASE" 2>/dev/null; git diff --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)" || CHANGED=""
else echo "NOTE: non-git checkout, static checks only (degraded diff scope)"; fi
touches() { # touches <ext-glob> : FULL 或命中后缀即真
  [ "$CHANGED" = "FULL" ] && return 0
  echo "$CHANGED" | grep -qE "$1" 2>/dev/null
}

# 1. shell 门禁（本仓脚本恒跑：scripts/ + 根 setup.sh）
if ls scripts/*.sh >/dev/null 2>&1; then
  ok=1; for s in scripts/*.sh setup.sh; do [ -f "$s" ] || continue; bash -n "$s" || { fail "bash -n $s"; ok=0; }; done
  [ "$ok" -eq 1 ] && pass "bash -n scripts/*.sh + setup.sh"
  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S warning scripts/*.sh setup.sh >/tmp/verify_shellcheck.log 2>&1; then pass "shellcheck scripts/*.sh + setup.sh"; else fail "shellcheck (see /tmp/verify_shellcheck.log)"; fi
  else skipped "shellcheck not installed"; fi
else skipped "no scripts/*.sh"; fi

# 2. python 栈
if touches '\.py$' || [ -f pytest.ini ] || [ -f pyproject.toml ] || ls tests/test_*.py >/dev/null 2>&1; then
  if command -v ruff >/dev/null 2>&1; then
    if ruff check src tests scripts 2>/tmp/verify_ruff.log; then pass "ruff check"; else fail "ruff check (see /tmp/verify_ruff.log)"; fi
  elif touches '\.py$'; then
    ok=1; while IFS= read -r f; do [ -n "$f" ] || continue
      python3 -m py_compile "$f" 2>/dev/null || { fail "py_compile $f"; ok=0; }
    done < <(echo "$CHANGED" | grep -E '\.py$' || true)
    [ "$ok" -eq 1 ] && pass "py_compile (changed .py, ruff absent)"
  else skipped "ruff not installed, no changed .py"; fi
  if ls tests/test_*.py >/dev/null 2>&1; then
    if command -v pytest >/dev/null 2>&1; then
      if pytest -q 2>/tmp/verify_pytest.log; then pass "pytest -q"; else fail "pytest -q (see /tmp/verify_pytest.log)"; fi
    else
      if python3 -m unittest discover -s tests 2>/tmp/verify_unittest.log; then pass "python3 -m unittest discover -s tests"; else fail "unittest discover (see /tmp/verify_unittest.log)"; fi
    fi
  else skipped "no tests/test_*.py"; fi
else skipped "python stack untouched"; fi

# 3. node 栈
if touches '\.(js|mjs|cjs|ts|tsx)$' || [ -f package.json ]; then
  if [ -f tsconfig.json ] && command -v npx >/dev/null 2>&1; then
    if npx --no-install tsc --noEmit 2>/tmp/verify_tsc.log; then pass "tsc --noEmit"; else fail "tsc --noEmit (see /tmp/verify_tsc.log)"; fi
  elif touches '\.(ts|tsx)$'; then blocked "tsc unavailable for changed .ts"; else skipped "no tsconfig/changed ts"; fi
  if command -v node >/dev/null 2>&1; then
    ok=1; while IFS= read -r f; do [ -n "$f" ] || continue; [ -f "$f" ] || continue
      node --check "$f" 2>/dev/null || { fail "node --check $f"; ok=0; }
    done < <(if [ "$CHANGED" = "FULL" ]; then find .agents/workflows scripts -name '*.js' 2>/dev/null; else echo "$CHANGED" | grep -E '\.(js|mjs|cjs)$' || true; fi)
    [ "$ok" -eq 1 ] && pass "node --check (js scope)"
    if ls tests/*.test.mjs tests/*.test.js >/dev/null 2>&1; then
      if node --test tests/*.test.mjs tests/*.test.js 2>/tmp/verify_nodetest.log; then pass "node --test"; else fail "node --test (see /tmp/verify_nodetest.log)"; fi
    else skipped "no node tests"; fi
  else blocked "node unavailable"; fi
else skipped "node stack untouched"; fi

# 4. fitness（五规则，有脚本即跑）
if [ -x scripts/fitness.sh ]; then
  if bash scripts/fitness.sh 2>/tmp/verify_fitness.log; then pass "fitness.sh"; else fail "fitness.sh (see /tmp/verify_fitness.log)"; fi
else skipped "scripts/fitness.sh absent"; fi

echo "---"
echo "verify: PASS=$PASS FAIL=$FAIL BLOCKED=$BLOCKED SKIPPED=$SKIPPED"
if [ "$FAIL" -gt 0 ] || [ "$BLOCKED" -gt 0 ]; then echo "VERIFY BLOCKED"; exit 2; fi
if [ "$PASS" -eq 0 ]; then echo "VERIFY DEGRADED (nothing established)"; exit 3; fi
echo "VERIFY PASSED"
exit 0
