#!/bin/bash
# session-start.sh — 开工检查（项目阶段检测 + 档位 + 损坏 + 待处理反馈 + 脏树提醒）。
# 出处：本仓自写。
# 退役条件：主 Agent 连续一季不消费其输出则删（以真实调用为准）。
# 用法：bash scripts/session-start.sh [--help]
# 退出码恒 0（只读报告）。建议：新会话开工先跑一次；可作 Muse SessionStart hook 命令。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
[ "${1:-}" = "--help" ] && { sed -n '2,5p' "$0"; exit 0; }
[ $# -gt 0 ] && { echo "session-start: no arguments expected" >&2; exit 2; }

echo "## 项目阶段检测"
has_req="$(ls docs/REQ-*.md 2>/dev/null | head -n 1 || true)"
has_plan="$(ls docs/PLAN-*.md 2>/dev/null | head -n 1 || true)"
has_code=""; [ -n "$(find src -type f -not -name '.gitkeep' 2>/dev/null | head -n 1)" ] && has_code=1
echo "- REQ：$([ -n "$has_req" ] && echo 有 || echo 无)"
echo "- PLAN：$([ -n "$has_plan" ] && echo 有 || echo 无)"
echo "- 代码：$([ -n "$has_code" ] && echo 有 || echo 无)"
if [ -z "$has_req" ]; then echo "=> 全新项目：描述想法，或走 product-spec-builder"; echo "   下一步：cp docs/REQUIREMENTS_TEMPLATE.md docs/REQ-<slug>.md";
elif [ -z "$has_plan" ] && [ -z "$has_code" ]; then echo "=> Spec 已完成：走 dev-planner 出计划";
elif [ -n "$has_plan" ] && [ -z "$has_code" ]; then echo "=> Plan 已完成：走 dev-builder 开工";
elif [ -z "$has_plan" ]; then echo "=> 缺计划：建议补 dev-planner";
else echo "=> 开发中：继续开发、审查、修复或发布"; fi

echo "## 档位"
bash scripts/tier.sh status 2>/dev/null || echo "tier: unknown"

echo "## 待处理反馈"
if [ -f .agents/feedback/FEEDBACK-INDEX.md ]; then
  pending="$(grep -rl "applied_to:.*pending" .agents/feedback/*.md 2>/dev/null | wc -l | tr -d ' ')"
  echo "- pending 纠正：${pending:-0} 条（>0 时本任务先遵守）"
else echo "- 无 feedback 索引"; fi

echo "## 脏树"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  n="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  [ "${n:-0}" -gt 0 ] && echo "- 工作树有 ${n} 处改动：先读 progress.md + REQ + CHANGELOG 恢复处境（recap-on-dirty）" \
    || echo "- 工作树干净"
else echo "- 非 git 仓"; fi
exit 0
