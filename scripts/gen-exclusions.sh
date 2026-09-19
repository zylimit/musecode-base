#!/bin/bash
# gen-exclusions.sh — 校验三处 SKIP 口径与 exclusions.json 一致（防手写漂移）。
# 用法：bash scripts/gen-exclusions.sh --check [--help]
# 退出码：0 一致 / 1 漂移 / 2 用法错。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
[ "${1:-}" = "--check" ] || { sed -n '2,5p' "$0" >&2; exit 2; }

EXCL=".agents/harness/exclusions.json"
[ -f "$EXCL" ] || { echo "gen-exclusions: $EXCL 缺失" >&2; exit 1; }

missing=0
# 反斜杠是正则转义：比较前两边都去掉反斜杠再做字面包含检查
while IFS= read -r token; do
  [ -n "$token" ] || continue
  bare_token="$(printf '%s' "$token" | tr -d '\\')"
  for f in setup.sh setup.ps1 scripts/manifest.sh; do
    tr -d '\\' < "$f" 2>/dev/null | grep -qF -- "$bare_token" \
      || { echo "DRIFT: $f 缺排除项 $token"; missing=1; }
  done
done < <(python3 -c "
import json
for t in json.load(open('$EXCL', encoding='utf-8'))['exclusions']:
    print(t)
" 2>/dev/null)

[ "$missing" -eq 0 ] && echo "gen-exclusions: OK" || exit 1
