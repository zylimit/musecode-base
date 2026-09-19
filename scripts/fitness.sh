#!/bin/bash
# fitness.sh — 五性反模式扫描（零依赖 grep 版）：密钥字面量 / 日志 PII / 静默吞错 / 无界重试 / 无主遗留标记。
# 用法：bash scripts/fitness.sh [--all] [--paths a,b] [--help]
#   默认扫 git 触及面（staged+unstaged+untracked）；非 git 仓默认扫 src/ scripts/ tests/。
# 退出码：0 通过（含仅 warning）/ 1 有 error / 2 用法错。
# 抑制：命中行或其上一行含 musecode-fitness:ignore 即跳过该条（须同行可见）。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
usage() { sed -n '2,7p' "$0"; }

MODE="changed"; PATHS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --all) MODE="all"; shift ;;
    --paths) [ $# -ge 2 ] || { echo "fitness: --paths needs a value" >&2; exit 2; }; MODE="list"; PATHS="$2"; shift 2 ;;
    --paths=*) MODE="list"; PATHS="${1#--paths=}"; shift ;;
    -*) echo "fitness: unknown flag $1" >&2; usage >&2; exit 2 ;;
    *) echo "fitness: unexpected positional $1" >&2; usage >&2; exit 2 ;;
  esac
done

FILES=""
case "$MODE" in
  all) FILES="$(git ls-files 2>/dev/null || find src scripts tests docs .agents .muse -type f 2>/dev/null)" ;;
  list) FILES="$(printf '%s' "$PATHS" | tr ',' '\n')" ;;
  *) if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
       FILES="$(git diff --name-only HEAD 2>/dev/null; git diff --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)"
     else FILES="$(find src scripts tests -type f 2>/dev/null)"; fi ;;
esac

ERR=0; WARNC=0
SUPPRESS='musecode-fitness:ignore'
report() { # report <level> <rule> <file:line> <text>
  local file="$3" line="${3##*:}" prev=""
  file="${3%%:*}"
  if [ "$line" -gt 1 ] 2>/dev/null; then prev="$(sed -n "$((line-1))p" "$file" 2>/dev/null || true)"; fi # musecode-fitness:ignore (missing line = empty context, handled by caller)
  cur="$(sed -n "${line}p" "$file" 2>/dev/null || true)" # musecode-fitness:ignore (unreadable line = skip hit, not silent pass)
  if [[ "$cur" == *"$SUPPRESS"* || "$prev" == *"$SUPPRESS"* ]]; then return 0; fi
  if [ "$1" = "error" ]; then ERR=$((ERR+1)); echo "ERROR[$2]: $3 $4";
  else WARNC=$((WARNC+1)); echo "WARN[$2]: $3 $4"; fi
}

scan() { # scan <rule> <level> <grep-E-pattern> [code-only:1]
  local rule="$1" level="$2" pat="$3" codeonly="${4:-0}"
  while IFS= read -r f; do
    [ -n "$f" ] || continue; [ -f "$f" ] || continue
    case "$f" in *.png|*.jpg|*.ico|*.woff*|*.mp4|*.pdf) continue;; esac
    if [ "$codeonly" -eq 1 ]; then
      case "$f" in *.py|*.js|*.mjs|*.cjs|*.ts|*.tsx|*.sh|*.ps1|*.go|*.java|*.rs) ;; *) continue;; esac
    fi
    # 自指排除：smoke/fitness 自身的密钥正则不扫 no-secret-literal
    if [ "$rule" = "no-secret-literal" ]; then
      case "$f" in scripts/smoke.sh|scripts/fitness.sh) continue;; esac
    fi
    while IFS= read -r hit; do
      ln="${hit%%:*}"; tx="${hit#*:}"
      report "$level" "$rule" "$f:$ln" "$(printf '%s' "$tx" | head -c 120)"
    done < <(grep -nE "$pat" "$f" 2>/dev/null || true) # musecode-fitness:ignore (grep no-match exit 1 = zero hits, counted below)
  done <<< "$FILES"
}

scan "no-secret-literal" "error" '(AKIA[0-9A-Z]{16}|sk-live-[A-Za-z0-9]{8,}|ghp_[A-Za-z0-9]{8,}|gho_[A-Za-z0-9]{8,}|xox[bap]-[A-Za-z0-9-]{8,}|BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|password\s*=\s*["'"'"'][^"'"'"']{4,}|passwd\s*=\s*["'"'"'][^"'"'"']{4,})'
scan "no-pii-in-logs" "error" '(log(g|ger)?\.(info|debug|warn|error)|print\(|console\.log|echo ).*([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|1[3-9][0-9]{9}|[0-9]{15,19})'
scan "no-silent-failure" "error" '(except(\s+[A-Za-z0-9_.]+)?\s*:\s*pass|catch\s*\([^)]*\)\s*\{\s*\}|2>/dev/null\s*\|\|\s*true)' 1
scan "no-unbounded-retry" "warning" '(while\s+true.*(curl|wget|fetch|request|retry)|for\s*\(\(\s*;\s*;\s*\)\).*(curl|wget)|retry.*(999|infinite|Infinity)|set\s+max[_-]?retries\s*=\s*0)' 1 # musecode-fitness:ignore (this line is the rule pattern, not a retry loop)
# musecode-fitness:ignore (next line is this rule's own pattern, not a real deferral)
scan "no-unreferenced-deferral" "warning" '(TODO|FIXME|HACK|XXX)([^:]*:)?[^#]*$' 1

# no-unreferenced-deferral 降噪：带 issue 编号（#123 / ABC-123）的不报
# （实现：上式全报太吵，改为二次过滤——此处简化为仅当 TODO 行无 #/编号时 report 已在上式；接受 warn 级噪音）

echo "---"
echo "fitness: errors=$ERR warnings=$WARNC"
if [ "$ERR" -gt 0 ]; then echo "FITNESS FAILED"; exit 1; fi
echo "FITNESS PASSED"
exit 0
