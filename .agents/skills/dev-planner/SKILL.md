---
name: dev-planner
description: 当需求/设计已定、要拆开发计划/排 Phase/估工作量，或争论先做哪个时使用。产出分阶段开发计划。
---

# dev-planner

- 版本：1.0.0
- 适用：M/L 级开发任务的 Phase 拆分与排序。不适用：S 级单点修改（直接做）、无 Spec 的探索（先补需求）。
- 输入：`docs/REQ-*.md` + ADR/设计 + 现有代码结构。
- 输出：开发计划（Phase 清单 + 每 Phase 验收 + 依赖图），落 `docs/PLAN-*.md` 或 REQ 附录。

## 步骤

1. 读全输入：REQ（含待定表/成功判据）、ADR、相关代码与测试；标出 `[推断]/[默认]/[待定]` 清单——计划先验证假设。
2. 按"核心价值先行 + 依赖拓扑"拆 Phase：每 Phase 一个可独立验收的行为切片；schema/迁移/公共契约/配置单列 Phase 且前置。
3. 每 Phase 写死：目标、范围（In/Out）、验收（命令+期望输出）、风险与回退；估算只给 T-shirt 号，不编人日。每条验收反推四问：在哪观察结果/哪段工作使它成立/谁用什么产生证据/验证前提是什么；无产生者的结果补工作或标未验证，缺业务口径先回来源冲突，不编 expected 充 ready。
4. 排冲突：目录不相交≠可并行——共享对象身份/单位/状态/错误语义的先核契约；mock 只支持本层开发，集成完成须真实连接。并行 Phase 必须 disjoint 路径，否则串行；标出 integration owner（多 writer 必备）。
5. 高风险项先排 spike（Class C 复杂交互/陌生技术），spike 只回答"能不能做"，不产出生产代码。
6. 计划评审：对照 Spec 逐条确认无遗漏、无镀金；待定项有"押后到 X，不答先按 Y 做"。
7. 落盘并同步 `progress.md` TODO（P0/P1/P2 + Owner + Context 指针）。

## 约束与红线

- 无验收标准的 Phase 不得开工；Phase 边界=可独立回退的边界（`ARCHITECTURE.md` 红线 2/5）。
- 不把"顺手重构"塞进 Phase；范围外事项进待办，不扩散。
- 计划变更走需求迭代分类回退（`docs/REQUIREMENTS_GUIDE.md` §5），不口头改计划。

## 验收

- 每个 Phase 有可执行验收；依赖图无环；风险项有 spike 或回退。
- 交接测试：dev-builder 能照计划逐 Phase 交付，无需反问"这个 Phase 到底要什么"。

## 示例

售后派单 v1：P1 数据模型+迁移 → P2 派单核心流（可验收：建单→派单→接单）→ P3 异常与通知 → P4 报表。报表 Phase 发现依赖 P2 的状态机，串行。

## Donor 出处

- `cc-base/.claude/skills/dev-planner/SKILL.md`（价值排序、切片、spike、并行 disjoint）
- `codex-base/.agents/skills/dev-planner/SKILL.md`（假设先行、验收绑定、回退边界）
