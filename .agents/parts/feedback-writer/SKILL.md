---
name: feedback-writer
description: 当用户修正了 AI 行为、提出改进意见，或 skill 执行后需记效能反馈时使用。只记真实信号。
---

# feedback-writer

- 版本：1.0.0
- 适用：行为教训的去重记录。不适用：业务知识（走 progress/Spec）、领域口径（走 domain-rulings）。
- 输入：用户原话 + AI 行为 + 适用任务/skill。
- 输出：回执（完整条目正文 + 目标路径 + 索引补丁行），由人或有写权限者落盘；或"无新 feedback"。
- 平台约束：本 skill 不写 `.agents/` 下任何文件（agent 不能改自己的记忆/配置，见 `docs/MUSE-NATIVE.md` §4）。进化的产物是交给人审的补丁，不是 agent 自己落盘的改动——这比"agent 改自己规则"更安全。

## 步骤

1. 判信号（五类）：用户修正 / 未覆盖场景 / 重复操作（3 次+同一类）/ 质量问题（多 Phase 同类）/ skill 效能评估。无信号回"无新 feedback"，宁漏记不滥记。
2. 判去向：业务术语/规则→主 Agent 回填 Spec；AI 行为教训→本 skill；无关→不写。同一事件两类信息分别提炼互指，不复全文。
3. 去重（只读）：读 `FEEDBACK-INDEX.md` 查同主题——已有则拟出"更新后的条目全文+补的触发场景"；冲突则拟新条（含 supersedes 声明）+ 旧条追加"被修正"注；无则拟新条（kebab-case 文件名）。
4. 拟条目：按模板（问题/场景/教训/范围/本次落地）；scope/exceptions/supersedes 判不出写"未说明"不编；applied_to 无落地写 pending 并点明"纠正尚未生效"。只出文本，不落盘。
5. 效能评分（仅执行后、有依据）：精准/覆盖/效率/满意四维 1–5 + 一句话依据；反膨胀（有修正精准≤3 等）；无依据写"未评分/未知"，不填 0 不编分；沉默≠满意，改意见≠不满意。
6. 当前任务立即遵守已知纠正，不等"毕业"；改稳定规则/skill 仍须授权，由主 Agent 派发。
7. 回执：摘要行（新增/更新/pending/无信号）+ 完整条目正文 + 目标路径 + 索引补丁行 + 落点建议（哪个 skill/rule 哪段该改，或"当前产物已够不动本体"）。人确认后由人落盘。

## 约束与红线

- 只存脱敏片段与路径，不存秘密与长会话原文（PRI，`AGENTS.md` §5）。
- 不把正常需求补充/业务教学/用户沉默制造成评分。
- occurrences 只计可辨认的新发生；重读/转述/引用不计数。

## 验收

- 回执含完整正文 + 目标路径 + 索引补丁行；条目有来源、有范围、有落地状态。
- 去重结论明确（新增/更新全文/supersedes 关系）；pending 项主 Agent 可见。

## 示例

用户："别用 rm -rf，用 git clean -nd 先看" → 查索引无同主题 → 回执含 `prefer-safe-delete.md` 全文（scope shell 操作，applied_to pending）+ 索引补丁行 + 落点建议（fitness.sh 加规则或 AGENTS.md §5 补一句）→ 人确认后落盘。

## Donor 出处

- `cc-base/.claude/skills/feedback-writer/SKILL.md`（五维/反膨胀/去重/supersedes/pending）
- `codex-base/.agents/skills/feedback-writer/SKILL.md`（路由规则、当前应用、无依据不评分、判断例子）
