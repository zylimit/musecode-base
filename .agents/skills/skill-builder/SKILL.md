---
name: skill-builder
description: 当用户说要创建新技能，或进化提议新增技能时使用。按交互模式参照现有 skill。
---

# skill-builder

- 版本：1.0.0
- 适用：新建/大改项目 skill。不适用：改 skill 触发词以外的路由（改 AGENTS.md）。
- 输入：新 skill 的目标/触发/输入/产出 + 参照 skill（1–2 个）。
- 输出：`.agents/skills/<name>/SKILL.md`（+模板/脚本按需）+ SPEC 索引行。

## 步骤

1. 需求收集：解决什么问题、何时触发、输入/产出各是什么；来自进化提议的先读原始 feedback。
2. 按交互模式找参照（不按领域）：对话采集型→product-spec-builder；自主分析型→dev-planner/code-review；执行操作型→dev-builder/release-builder；诊断修复型→bug-fixer。
3. 定结构：读 `_template/SKILL.md` 骨架；必填（版本/适用/输入/输出/步骤≤7/约束/验收/示例）全留；领域节按需加。
4. 填充：任务一句话；原则 3–5 条只写本阶段特有判断（AGENTS.md 已有铁律不重复）；维度名写成可执行方法（含适用条件/动作/分支/收敛，不只列名词）；步骤可独立验证；约束引用条款编号；验收可执行（命令+期望退出码）。大改前列 2–3 个代表性场景做新旧对照：只给当轮输入，不预给期望答案；只有原版真失败且改版同断言通过才称改进，原版对的记保留。
5. 不熟悉的领域先联网查最佳实践；从外部吸收内容记来源（URL/路径/ref/日期/许可）+ 复制处理（原样/改写/综合/仅引用/排除），许可证未知或涉密钥的不复制。
6. 落盘自检：frontmatter 只有 name/description；description 只写触发条件不写流程；`bash scripts/smoke.sh` 过；新 skill 有验收命令。
7. 注册：SPEC 索引加行；有架构影响补 ADR；在 AGENTS.md 工作流中补触发入口（如需）。

## 约束与红线

- 最小必要：只建需要的节，不为"看起来完整"加空内容（`ARCHITECTURE.md` 红线 2）。
- skill 间不循环依赖；通用逻辑上浮 `src/`，skill 只做编排。
- skill 目录只放稳定可版本化能力；任务/进度/日志/凭证不得写入。

## 验收

- 契约测试 `test_skills_structure` 通过；smoke 全绿；有 1 个可跑的验收命令。
- 交接测试：没参与编写的人能照 SKILL.md 走通一次。

## 示例

新建 `api-linter`：参照 code-review（自主分析型）→ 骨架填充（触发/三维清单/流程）→ 自检 → SPEC 加行 → ADR（新增门禁能力）。

## Donor 出处

- `cc-base/.claude/skills/skill-builder/SKILL.md`（三层模块化、交互模式参照、注册三步）
- `codex-base/.agents/skills/skill-builder/SKILL.md`（场景对照、来源清单、复制处理、证据分工）
