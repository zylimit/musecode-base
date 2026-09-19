#!/bin/bash
# smoke.sh — 最小冒烟验证（零依赖，仅 bash + coreutils）
# 出处：本仓自写。
# 退役条件：安装器与 CI 不再消费时删（它是存在性探针，无消费者即死）。
# 用法：bash scripts/smoke.sh（仓根执行）。退出码 0=全绿，非0=有 FAIL。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "PASS: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1"; }

# 1. 必备文件存在性
for f in AGENTS.md ARCHITECTURE.md HARNESS.md README.md \
         docs/ADR_TEMPLATE.md docs/REQUIREMENTS_TEMPLATE.md \
         docs/HOOKS.md docs/QUALITY_CHECKLIST.md docs/MUSE-NATIVE.md SCALING.md \
         scripts/SMOKE.md .agents/skills/SKILLS_SPEC.md .agents/parts/_template/SKILL.md; do
  if [ -f "$f" ]; then ok "exists $f"; else bad "missing $f"; fi
done

# 1b. 扩展必备文件（增减须有理由并同步台账，禁止静默删）
for f in scripts/verify.sh scripts/check.sh scripts/fitness.sh scripts/arch-check.sh \
         scripts/install-githooks.sh scripts/manifest.sh setup.sh setup.ps1 .gitignore \
         FRAMEWORK-MANIFEST.json tests/test_contract.py \
         docs/CROSS-POLLINATION.md docs/REQUIREMENTS_GUIDE.md docs/LARGE-REPO.md \
         docs/MEMORY_GUIDE.md docs/adr/0001-skills-official-path.md \
         .agents/skills/code-review/SKILL.md .agents/memory/MEMORY.md \
         .agents/workflows/review-change.js .agents/harness/module-catalog.example.json \
         .muse/hooks.json.example; do
  if [ -f "$f" ]; then ok "exists $f"; else bad "missing $f"; fi
done

# 1c. skill 必备文件（增减须有理由并同步 SPEC §7，禁止静默删）
for f in scripts/skill-lint.sh docs/PLAN_TEMPLATE.md docs/UI-QUALITY-FLOOR.md \
         docs/DESIGN_VOCABULARY.md .agents/rules/domain-rulings.md \
         .agents/feedback/FEEDBACK-INDEX.md \
         .agents/feedback/templates/feedback-topic-template.md \
         .agents/parts/red-blue-review/scripts/evidence.sh; do
  if [ -f "$f" ]; then ok "exists $f"; else bad "missing $f"; fi
done
# 装机 skill 只有需求→开发→审查一条线（Fable #2，2026-09-19）；余下在 .agents/parts/ 作零件库
for s in product-spec-builder dev-builder code-review; do
  if [ -f ".agents/skills/$s/SKILL.md" ]; then ok "skill $s"; else bad "missing skill $s"; fi
done

# 2. 模板非空
for f in docs/ADR_TEMPLATE.md docs/REQUIREMENTS_TEMPLATE.md docs/PLAN_TEMPLATE.md .agents/parts/_template/SKILL.md .agents/feedback/templates/feedback-topic-template.md; do
  if [ -s "$f" ]; then ok "non-empty $f"; else bad "empty $f"; fi
done

# 3. shell 语法（scripts/ + 根 setup.sh）
for s in scripts/*.sh setup.sh .agents/skills/*/scripts/*.sh .agents/parts/*/scripts/*.sh; do
  [ -e "$s" ] || continue
  if bash -n "$s"; then ok "bash -n $s"; else bad "syntax $s"; fi
done

# 4. 目录结构（tests/docs/adr 等不可删；本仓无 src，见 README 定位）
for d in tests docs/adr scripts .agents/skills .agents/parts .agents/memory .agents/workflows; do
  if [ -d "$d" ]; then ok "dir $d"; else bad "missing dir $d"; fi
done

# 5. 解释器可用
if command -v python3 >/dev/null 2>&1; then ok "python3 $(python3 --version 2>&1)"; else bad "python3 not found"; fi
if command -v bash >/dev/null 2>&1; then ok "bash available"; else bad "bash not found"; fi

# 6. 泄露初检（粗粒度，误报则白名单化而非删检查）
if [ -e .secrets ]; then bad ".secrets must not exist"; else ok "no .secrets"; fi
if grep -rIn --exclude-dir=.git -E 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|AKIA[0-9A-Z]{16}|sk-(live|test)-[A-Za-z0-9]{8,}|ghp_[A-Za-z0-9]{8,}|gho_[A-Za-z0-9]{8,}|xox[bap]-[A-Za-z0-9-]{8,}' . >/tmp/smoke_leak.txt 2>&1; then
  if [ -s /tmp/smoke_leak.txt ]; then bad "possible secret match (see /tmp/smoke_leak.txt)"; else ok "no secret pattern"; fi
else
  ok "no secret pattern"
fi
rm -f /tmp/smoke_leak.txt

# 7. 可执行位
if [ -x scripts/smoke.sh ]; then ok "executable scripts/smoke.sh"; else bad "scripts/smoke.sh not executable (chmod +x)"; fi

echo "---"
echo "smoke: PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "ALL SMOKE CHECKS PASSED"
  exit 0
else
  echo "SMOKE FAILED"
  exit 1
fi
