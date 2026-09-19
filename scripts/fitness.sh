#!/bin/bash
# fitness.sh — 五性反模式扫描（规则语义对齐 codex fitness.mjs；零依赖 grep 版）。
# 规则：no-secret-literal(error) / no-pii-in-logs(error) / no-silent-failure(error) /
#       no-unbounded-retry(warning) / todo-without-owner(warning)。
# 用法：bash scripts/fitness.sh [--all] [--staged] [--paths a,b] [--help]
#   默认扫 git 触及面（工作树字节）；--staged 读 index 字节（与提交内容一致）。
# 退出码：0 通过（含仅 warning）/ 1 有 error / 2 用法错。
# 抑制：命中行或其上一行含 musecode-fitness:ignore <rule> reason="..."；
#   裸标记（无规则无理由）计 invalid-suppression error。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
usage() { sed -n '2,10p' "$0"; }

MODE="changed"; PATHS=""; STAGED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --all) MODE="all"; shift ;;
    --staged) STAGED=1; shift ;;
    --paths) [ $# -ge 2 ] || { echo "fitness: --paths needs a value" >&2; exit 2; }; MODE="list"; PATHS="$2"; shift 2 ;;
    --paths=*) MODE="list"; PATHS="${1#--paths=}"; shift ;;
    -*) echo "fitness: unknown flag $1" >&2; usage >&2; exit 2 ;;
    *) echo "fitness: unexpected positional $1" >&2; usage >&2; exit 2 ;;
  esac
done

FILES=""
case "$MODE" in
  all) FILES="$(find src scripts tests docs .agents .muse -type f 2>/dev/null)" ;;
  list) FILES="$(printf '%s' "$PATHS" | tr ',' '\n')" ;;
  *) if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
       FILES="$( { git diff --name-only HEAD 2>/dev/null; git diff --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | LC_ALL=C sort -u)"
     else FILES="$(find src scripts tests -type f 2>/dev/null)"; fi ;;
esac

ERR=0; WARNC=0; FINDINGS=0
MAX_FINDINGS=200
MARK='musecode-fitness:ignore'
VALID_RULES="no-secret-literal no-pii-in-logs no-silent-failure no-unbounded-retry todo-without-owner"

tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
# file_bytes <path> -> stdout bytes path (staged: index bytes; else worktree)
file_bytes() {
  local f="$1"
  local out
  out="$tmpdir/$(printf '%s' "$1" | tr '/' '_' | head -c 120)"
  if [ "$STAGED" -eq 1 ]; then
    git show ":$f" > "$out" 2>/dev/null || return 1
  else
    [ -f "$f" ] || return 1
    cp "$f" "$out" 2>/dev/null || return 1
  fi
  printf '%s' "$out"
}

report() { # report <level> <rule> <origfile> <line> <text> <bytefile>
  local level="$1" rule="$2" orig="$3" line="$4" text="$5" bytes="$6"
  FINDINGS=$((FINDINGS+1))
  if [ "$FINDINGS" -gt "$MAX_FINDINGS" ]; then return 0; fi
  local cur="" prev=""
  cur="$(sed -n "${line}p" "$bytes" 2>/dev/null || true)" # musecode-fitness:ignore no-silent-failure reason="unreadable line means skip hit, counted below"
  if [ "$line" -gt 1 ] 2>/dev/null; then prev="$(sed -n "$((line-1))p" "$bytes" 2>/dev/null || true)"; fi # musecode-fitness:ignore no-silent-failure reason="missing line means empty context"
  local markline=""
  [[ "$cur" == *"$MARK"* ]] && markline="$cur"
  [[ -z "$markline" && "$prev" == *"$MARK"* ]] && markline="$prev"
  if [ -n "$markline" ]; then
    # 抑制语法：ignore <rule> reason="..."；裸标记或未知规则计 error
    local rest="${markline#*$MARK}"
    local mrule mreason
    mrule="$(printf '%s' "$rest" | grep -oE '^[[:space:]]+[a-z][a-z0-9-]*' | tr -d ' ' || true)"
    mreason="$(printf '%s' "$rest" | grep -oE 'reason="[^"]+"' || true)"
    if [ -z "$mrule" ] || [ -z "$mreason" ]; then
      ERR=$((ERR+1)); echo "ERROR[invalid-suppression]: $orig:$line 抑制缺规则或理由（写法：$MARK <rule> reason=\"...\"）"
      return 0
    fi
    case " $VALID_RULES " in *" $mrule "*) ;; *)
      ERR=$((ERR+1)); echo "ERROR[invalid-suppression]: $orig:$line 未知规则 $mrule"; return 0;; esac
    [ "$mrule" = "$rule" ] && return 0  # 对号才抑制；不对号落空，继续报原 finding
  fi
  if [ "$level" = "error" ]; then ERR=$((ERR+1)); echo "ERROR[$rule]: $orig:$line $text";
  else WARNC=$((WARNC+1)); echo "WARN[$rule]: $orig:$line $text"; fi
}

scan() { # scan <rule> <level> <grep-E-pattern> [code-only:1] [not-pattern]
  local rule="$1" level="$2" pat="$3" codeonly="${4:-0}" notpat="${5:-}"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in *.png|*.jpg|*.jpeg|*.ico|*.woff*|*.mp4|*.pdf|*.zip|*.tar.gz) continue;; esac
    case "$f" in *.env*|*credentials*|*.pem|*.key) continue;; esac  # 敏感路径不扫内容（存在性由 smoke/审计管）
    if [ "$codeonly" -eq 1 ]; then
      case "$f" in *.py|*.js|*.mjs|*.cjs|*.ts|*.tsx|*.sh|*.ps1|*.go|*.java|*.rs) ;; *) continue;; esac
    fi
    # 自指排除：smoke/fitness 自身的密钥正则不扫 no-secret-literal
    if [ "$rule" = "no-secret-literal" ]; then
      case "$f" in scripts/smoke.sh|scripts/fitness.sh) continue;; esac
    fi
    local bytes; bytes="$(file_bytes "$f")" || continue
    if ! grep -qI . "$bytes" 2>/dev/null; then continue; fi  # 非文本跳过
    if [ "$(wc -c < "$bytes" | tr -d ' ')" -gt 1048576 ]; then continue; fi  # >1MB 跳过
    while IFS= read -r hit; do
      ln="${hit%%:*}"; tx="${hit#*:}"
      if [ -n "$notpat" ] && printf '%s' "$tx" | grep -qE "$notpat" 2>/dev/null; then continue; fi
      report "$level" "$rule" "$f" "$ln" "$(printf '%s' "$tx" | head -c 120)" "$bytes"
    done < <(grep -nE "$pat" "$bytes" 2>/dev/null || true) # musecode-fitness:ignore no-silent-failure reason="grep no-match exit 1 means zero hits"
  done <<< "$FILES"
}

scan "no-secret-literal" "error" '(AKIA[0-9A-Z]{16}|ABIA[0-9A-Z]{16}|ACCA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|sk-live-[A-Za-z0-9]{8,}|ghp_[A-Za-z0-9]{8,}|gho_[A-Za-z0-9]{8,}|github_pat_[A-Za-z0-9_]{8,}|glpat-[A-Za-z0-9_-]{8,}|xox[baprs]-[A-Za-z0-9-]{8,}|AIza[0-9A-Za-z_-]{8,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}|BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY|password\s*=\s*["'"'"'][^"'"'"']{4,}|passwd\s*=\s*["'"'"'][^"'"'"']{4,}|[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^[:space:]"'"'"']+:[^[:space:]"'"'"']+@)'
# musecode-fitness:ignore no-pii-in-logs reason="this line is the rule pattern, not a log call"
scan "no-pii-in-logs" "error" '(log(g|ger)?\.(info|debug|warn|error|trace)|print\(|console\.log|echo ).*(email|ssn|passport|credit_card|phone_number|\bmobile\b|date_of_birth|\bdob\b)'
scan "no-silent-failure" "error" '(except(\s+[A-Za-z0-9_.]+)?\s*:\s*pass|catch\s*\([^)]*\)\s*\{\s*\}|2>/dev/null\s*\|\|\s*true)' 1
# musecode-fitness:ignore no-unbounded-retry reason="this line is the rule pattern, not a retry loop"
scan "no-unbounded-retry" "warning" '(while\s+true.*(curl|wget|fetch|request|retry)|for\s*\(\(\s*;\s*;\s*\)\).*(curl|wget)|retry.*(999|infinite|Infinity)|set\s+max[_-]?retries\s*=\s*0)' 1
# musecode-fitness:ignore todo-without-owner reason="this line is the rule pattern, not a deferral"
scan "todo-without-owner" "warning" '(TODO|FIXME|HACK|XXX)' 1 '\(@[^)]+\)'

echo "---"
echo "fitness: errors=$ERR warnings=$WARNC"
[ "$FINDINGS" -gt "$MAX_FINDINGS" ] && echo "fitness: findings capped at $MAX_FINDINGS (narrow scope)"
if [ "$ERR" -gt 0 ]; then echo "FITNESS FAILED"; exit 1; fi
echo "FITNESS PASSED"
exit 0
