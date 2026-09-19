#!/bin/bash
# staged-check.sh — 暂存区分栈语法检查（pre-commit 调用；也可手动跑）。
# 出处：本仓自写。
# 退役条件：pre-commit 改直调各栈工具时删。
# 规则：py 只拦 SyntaxError（缩进/语法），其余告警；js/mjs/cjs/ts 用 node --check；
#   sh 用 bash -n；只读 git index 字节（git show :path），不读工作树。
# 用法：bash scripts/staged-check.sh [--help]
# 退出码：0 通过 / 1 有 error / 2 用法错或非 git 仓。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
[ "${1:-}" = "--help" ] && { sed -n '2,7p' "$0"; exit 0; }
[ $# -gt 0 ] && { echo "staged-check: no arguments expected" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "staged-check: 非 git 仓" >&2; exit 2; }

ERR=0
staged="$(git diff --cached --name-only --diff-filter=ACMR -z 2>/dev/null | tr '\0' '\n' || true)"
[ -z "$staged" ] && { echo "staged-check: 暂存区无文件"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in *.py|*.js|*.mjs|*.cjs|*.ts|*.tsx|*.sh) ;; *) continue;; esac
  tmpf="$tmp/$(printf '%s' "$f" | tr '/' '_')"
  git show ":$f" > "$tmpf" 2>/dev/null || continue
  case "$f" in
    *.py)
      if ! python3 -m py_compile "$tmpf" 2>"$tmp/err"; then
        if grep -qiE "SyntaxError|IndentationError|TabError" "$tmp/err"; then
          echo "ERROR: $f 语法错"; head -n 3 "$tmp/err" | sed 's/^/  /'; ERR=1
        else echo "WARN: $f 编译告警（非语法错，不阻断）"; fi
      fi
      ;;
    *.js|*.mjs|*.cjs)
      if command -v node >/dev/null 2>&1; then
        node --check "$tmpf" 2>"$tmp/err" || { echo "ERROR: $f node --check 不过"; head -n 3 "$tmp/err" | sed 's/^/  /'; ERR=1; }
      else echo "WARN: node 缺席，跳过 $f"; fi
      ;;
    *.ts|*.tsx) echo "WARN: $f 入暂存（ts 全量检查走 verify tsc，不过 pre-commit 重闸）" ;;
    *.sh)
      bash -n "$tmpf" 2>"$tmp/err" || { echo "ERROR: $f bash -n 不过"; head -n 3 "$tmp/err" | sed 's/^/  /'; ERR=1; }
      ;;
  esac
done <<< "$staged"

[ "$ERR" -eq 0 ] && echo "staged-check: 通过" || echo "staged-check: 有 error"
exit "$ERR"
