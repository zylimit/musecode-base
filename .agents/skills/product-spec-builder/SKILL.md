---
name: product-spec-builder
description: 当用户说要做/规划/改新产品新功能，或手上资料是一句话想法/语音/截图/竞品链接时使用。产出可验收的需求文档。
---

# product-spec-builder

- 版本：1.0.0
- 适用：0-1 新需求（从想法到 `docs/REQ-*.md`）与迭代（改需求 + CHANGELOG 成对）。不适用：纯修 bug（走 bug-fixer）、已定需求直接开工。
- 输入：用户的想法/资料 + 项目上下文（已有 REQ、代码、竞品）。
- 输出：`docs/REQ-<slug>.md`（条目全部可验收）+ 复述签字记录。

## 步骤

1. 依赖检测：读已有 REQ/ADR/progress.md；竞品/陌生库先联网查，不凭记忆定规则。
2. 判档（直推/确认/探索/委托，见 `docs/REQUIREMENTS_GUIDE.md` §2），探索档进访谈。
3. 访谈四线并进：业务（目标/链路/量级/角色/例外）、规则（判据+例子；听到"一般/通常"要例子）、需求（用户语言→接收语言翻译）、查旧（旧规则适用性有条件继承）。遵循向人学业务五铁律与四把刀：听重于问、问过去不问未来假设、查得到的自己查、一句一定、矛盾当场并排选；对比后给推荐+理由（用户可单选、可组合折中，可逆细节按推荐直接推进）、回放验证 vs 挑错、锚定三连、沉默留白。
4. 每条打来源标记 `[确认]/[推断]/[默认]/[待定]`（待定只许在待定表）；矛盾逼排序，不许"都要"。
5. 收敛检查（`bash scripts/check.sh --req` 先过机器闸）+ 成功判据四问（可数/技术无关/有基线/有反向指标）。
6. 复述签字：用用户给的案例讲一遍上线后那次会怎么发生，逐段确认；挑错改条目，挑不出通过。
7. 迭代：改 Spec 必追加 CHANGELOG（为什么改/原判断哪里错/影响/分类回退），被推翻条目标"→ 被取代"不删号。

## 约束与红线

- 没标来源的条目按 `[推断]` 对待；功能条目挂 `[待定]` 即 fail（`AGENTS.md` §3 需求 checklist）。
- 形容词不进 Spec（"简洁/高级"翻成可观察属性），无验收路径的条目不写。
- 用户原话与 AI 推断分区存放，禁止把 AI 摘要伪装成用户确认。

## 验收

- `bash scripts/check.sh --req docs/REQ-<slug>.md` 通过（占位符/待定/标记三规则）。
- 待定表清零或每条有"谁能答/押后到/不答先按什么做"；复述通过。
- 交接测试：没参与对话的工程师能照文档开工。

## 示例

用户："做个售后派单，要简洁。"
AI（先判探索档，不问"要什么风格"）："上次派单一共几步？单子最多同时多少？组长在车间还是工位操作？"→ 逐条打标 → 复述："组长手机点人（3 秒内），客服桌面派单（打断可续），对吗？"

## 参考（`references/`，按触发条件读，不预读；题库是反含糊约束，不是顺序问卷）

- `workflow-0-1.md`：0-1 模式启动时读（初次表达到 Spec 的顺序与出口判据）。
- `workflow-iteration.md`：已有 Spec 提变更时读（分类/追问/冲突检测/影响矩阵/阶段回退）。
- `question-bank.md`：采访选题时读（13 维度五段约束）。
- `interview-principles.md`：采集访谈时读（与 design-brief-builder 共用）。
- `discovery-methods.md`：主入口识别到缺口时读相关分支（专业取证方法，非必问题库）。
- `discovery-examples.md`：仅隐性规则/术语歧义/纠正传播确实影响当前需求时读（规则不移植）。
- `elicitation-menu.md`：风险档对外或涉钱涉规、复述前读（深挖菜单点了才跑）。
- `spec-self-review.md`：生成 Spec 前与复述前读（需求的单元测试）。
- `reservation-case.md`：需完整教学追演时读（各例共用事实源，非项目真相）。
- `example-after-sales-dispatch.md`：范例（售后 Spec 全文），首次写 Spec 或定标记粒度时对照。

## Donor 出处

- `cc-base/.claude/skills/product-spec-builder/SKILL.md`（四线/五铁律/四把刀/问题库/复述/下一步判定）
- `codex-base/.agents/skills/product-spec-builder/SKILL.md`（纠正传播、第一性原则、四问、信息充足度）
- 本仓：`docs/REQUIREMENTS_GUIDE.md`、`docs/REQUIREMENTS_TEMPLATE.md`
