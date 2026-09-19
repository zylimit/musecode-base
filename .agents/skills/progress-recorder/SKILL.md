---
name: progress-recorder
description: 当出现重要决策/硬约束/完成事项/明确新任务，或 /record /archive 触发时使用。不与用户交互，只做原子记录。
---

# progress-recorder

- 版本：1.0.0
- 适用：对话增量 → `progress.md` 的语义合并与归档。不适用：上下文恢复（主 Agent 读三份）、业务正文维护（回填 Spec）。
- 输入：对话增量 delta + mode（record/archive）+ 项目根路径。
- 输出：更新后的 `progress.md`（/archive 时 + `progress.archive.md`）+ 一行摘要。

## 步骤

1. 文件检查：progress.md 存在且含全部区块（Pinned/Decisions/TODO/In Progress/Done/Risks/Notes/Context Index），缺则按模板补；扫 TODO 最大 ID；记操作日期。
2. 语义抽取分类：Pinned 候选（长期约束）/Decisions（确定性决策+用户纠正，纠正最硬必须带取代）/TODO/Done/Risks/Assumptions/Notes；含弱化词（可能/也许/建议）→ 降级 Notes + "Needs-Confirmation"，宁降不误升。
3. 区块合并：Pinned 仅追加高置信（带依据与适用范围，封顶 15，满了先降级最弱）；Decisions 按时间追加三要素（依据/适用范围/取代），旧条标"→ 被取代"不改原文；TODO 语义去重+递增 ID（默认 P1）；Done 附证据指针（无则不虚构）。
4. 一致性验证：TODO ID 唯一单调；受保护区块未被意外改；更新时间戳；返回摘要（"记录到 progress.md：[区块] +N/更新 M"，无信号→"无新进度"）。
5. 归档（Notes+Done>100 或 Decisions>30 或显式触发）：各留最近 50/50/30 条，其余原文搬迁；Pinned/TODO 永不搬；archive 只增不删；Context Index 更新指针。
6. 冲突处理：与 Pinned/Decisions 潜在冲突→记 Notes（含建议与理由），不擅自覆盖；用户明确纠正→ Decisions 记替代关系后更新当前项，不让新决定只停在 Notes。
7. 交接：返回摘要；需回填 Spec/派单/验收的列清单交主 Agent；不代写业务正文。

## 约束与红线

- 只维护 progress.md/archive，不碰 Spec/skill/feedback 文件（各归其主）。
- 历史不可改：Decisions/archive 原文一字不动；取代只追加标记。
- 先读现有内容再最小修改；发现未知并发变化停手交主 Agent，不凭旧快照覆盖。

## 验收

- 模板区块齐、顺序对、时间戳当日；Decisions 三要素齐、取代链完整；TODO ID 单调。
- 自检 5 项（见 donor）：区块/置信/ID/证据/归档。

## 示例

delta："决定用 Postgres（MySQL 分库hold不住），P0 先迁订单表" → Decisions +1（含否掉 MySQL 的依据）→ TODO +1 [#9] → 摘要"记录到 progress.md：Decisions +1/TODO +1"。

## Donor 出处

- `cc-base/.claude/skills/progress-recorder/SKILL.md`（语义抽取/置信闸/取代检查/归档阈值）
- `codex-base/.agents/skills/progress-recorder/SKILL.md`（边界铁律、阶段事实、并发保护、Context Index）
