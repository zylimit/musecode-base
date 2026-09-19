---
name: evolution-engine
description: 当 session 初始化时自动检查，或用户说"看看有没有该升级的规则"、"检查进化建议"时使用。只读扫描，提议须人确认。
---

# evolution-engine

- 版本：1.0.0
- 适用：feedback 积累的进化扫描。不适用：单条纠正的即时应用（feedback-writer 已做）。
- 输入：`.agents/feedback/` 全量。
- 输出：结构化进化提议（规则毕业/Skill 优化/新 Skill），或"无进化建议"。

## 步骤

1. 建候选集：读索引定位文件，按路径去重读 frontmatter；只消费 `graduated == false && skipped != true`；读正文原始事件与依据，不凭标题/分数推断。
2. 毕业扫描：occurrences ≥ 3 的主题；先做**现状核查**（grep 目标 skill/AGENTS.md/ARCHITECTURE.md，判已成文/部分成文/压根没有）；再过**实证门槛**（正文有真代价：返工/空转/冻结功能/重复争议；只有"当场纠正"无代价→判暂不成文并注理由）。
3. Skill 优化扫描：某 skill 连续 3 次同维 ≤2，或近 5 次均值 ≤3，或 ≥3 条未毕业 feedback 指向同一环节；排除不可靠样本（沉默当满意、按轮数机械扣分），报告有效/排除数。
4. 新 Skill 扫描：同族主题跨 3 条+反复出现且无 skill 覆盖 → 新 Skill 候选。
5. 生成提议：每条含标题/次数/目标位置/一句话摘要/依据；同一主题命中多类合并一条；用户逐条确认/跳过——毕业写目标文件并标 graduated，优化改 skill，新 skill 走原生 create-skill + 本仓 SKILLS_SPEC §6 约定，跳过标 skipped 不再提。
6. 本角色只读：不改任何规则/skill 文件；实施由主 Agent 按授权派发；业务定义（如"验收后才计完成"）交项目来源维护，不毕业成通用规则。
7. 回执："N 条进化建议待处理"+全文，或"无进化建议"。

## 约束与红线

- 次数阈值只用于发现候选，不是遵守纠正的等待期——明确纠正当前任务立即用。
- 闸靠数据留：无实证的规则不毕业（`ARCHITECTURE.md` 红线：可验证性）。
- 保护属性/秘密/权限/远端授权的规则，进化建议不得提议删除或豁免。

## 验收

- 每条提议可追溯到 feedback 事件与代价；现状核查结论明确。
- skipped/graduated 标记同步到 frontmatter 与索引；无重复提议。

## 示例

扫出"删分支必须用 -d"出现 4 次且有 1 次丢工作代价 → 核查 AGENTS.md 未成文 → 提议写入 branch-finisher 约束节 → 用户确认 → 落地并标毕业。

## 参考（`references/`，按触发条件读，不预读）

- `learning-adoption-and-retirement.md`："已写下"被当"已解决"、重复问题/规则冲突或考虑减规则时读。

## Donor 出处

- `cc-base/.claude/skills/evolution-engine/SKILL.md`（现状核查、实证门槛、提议格式）
- `codex-base/.agents/skills/evolution-engine/SKILL.md`（候选集去重、样本排除、只读边界、退役判断）
