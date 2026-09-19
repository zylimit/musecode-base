#!/bin/bash
# risk-scan.sh — 只读风险扫描：过期档位/损坏状态/残留标记/超限目录/无主待办。
# 用法：bash scripts/risk-scan.sh [--help]
# 退出码：0 无风险 / 1 有发现（报告即目的，不阻断）/ 2 用法错。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
[ "${1:-}" = "--help" ] && { sed -n '2,5p' "$0"; exit 0; }
[ $# -gt 0 ] && { echo "risk-scan: no arguments expected" >&2; exit 2; }

FOUND=0
hit() { FOUND=$((FOUND+1)); echo "RISK[$1]: $2"; }
ok() { echo "OK[$1]: $2"; }

# 1. 档位过期残留
if [ -f .agents/harness-state/tier.json ]; then
  if bash scripts/tier.sh status 2>/dev/null | grep -q "expired"; then
    hit "TIER" "fast 已过期但状态文件仍在（tier.sh off 清理）"
  else ok "TIER" "档位状态正常"
  fi
else ok "TIER" "无档位状态（默认 standard）"; fi

# 2. 损坏的 JSON 状态
for f in .agents/harness-state/tier.json .agents/harness/module-catalog.json .muse/hooks.json; do
  [ -f "$f" ] || continue
  python3 -c "import json,sys;json.load(open('$f'))" 2>/dev/null \
    && ok "JSON" "$f 合法" || hit "CORRUPT" "$f 解析失败（quarantine 人工看）"
done

# 3. 残留标记与临时文件
for f in .needs-review .red-verified .tdd-exempt; do
  [ -e "$f" ] && hit "MARKER" "$f 残留（确认后删除）" || true
done
for f in $(find . -maxdepth 2 -name "*.framework-new" 2>/dev/null || true); do # musecode-fitness:ignore no-silent-failure reason="no matches means empty loop"
  hit "UNMERGED" "$f 未合并（安装器冲突产物）"
done

# 4. 超限目录
for d in .agents/harness-state .agents/evidence; do
  [ -d "$d" ] || continue
  kb="$(du -sk "$d" 2>/dev/null | awk '{print $1}')"
  [ "${kb:-0}" -gt 51200 ] 2>/dev/null && hit "SIZE" "$d ${kb}KB > 50MB" || ok "SIZE" "$d ${kb:-0}KB"
done

# 5. 无主待办（progress 待办无 Owner 行）
if [ -f progress.md ]; then
  if grep -qE "^- \[ \] #?[0-9]+" progress.md 2>/dev/null && ! grep -qE "Owner" progress.md 2>/dev/null; then
    hit "OWNER" "progress.md 有待办但无 Owner 字段"
  else ok "OWNER" "progress.md 待办有主或无待办"
  fi
fi

echo "---"
echo "risk-scan: findings=$FOUND"
[ "$FOUND" -gt 0 ] && exit 1 || exit 0
