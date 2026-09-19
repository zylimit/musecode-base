# 记忆指南（四系统分工 + 保留销毁）

> 吸收 cc `ARCHITECTURE.md` §8（C11），对齐 Muse 原生 memory 三域（`docs/MUSE-NATIVE.md` §7）。

## 1. 四系统分工（一句话判去向）

| 系统 | 载体 | 记什么 | 不记什么 |
|---|---|---|---|
| 项目记忆 | `progress.md`（根）+ `progress.archive.md` | 决策/约束/完成/待办/风险（Decisions/Todo/Done/Risks） | AI 行为修正、领域口径 |
| 反馈进化 | `.agents/feedback/<topic>.md` + 索引 | 用户对 AI 行为的修正、进化建议 | 项目进度、业务事实 |
| 领域口径 | `domain/<域>.md`（可选） | “事情怎么算”（跟领域走，不跟项目走） | 项目决策、AI 方法 |
| 原生 memory | `.agents/memory/`（随仓）+ 机内个人域 | durable 事实：部署步骤、workaround 成因、服务怪癖 | 临时进度、猜测、密钥 |

判据：换一个八竿子打不着的项目还成立吗？成立且描述某域 → 口径；成立且与业务无关 → 反馈；不成立 → 项目记忆/Spec。

## 2. 项目记忆纪律

- 决策/硬约束/待办/完成/风险**出现即记**，随下一个有代码的提交入库，不为记账单独提交。
- Notes + Done > 100 或 Decisions > 30 即归档到 `progress.archive.md`；Pinned 封顶 15 条。
- 明确纠正可更新当前有效约束，同时保留旧决定与替代关系；不把新规则埋进会归档的 Notes。
- `/recap` 恢复：读 `progress.md` + Spec + CHANGELOG + 计划，再看 active task 与 impact；缺文件明确说明并降级，不猜补。

## 3. 反馈进化纪律

- 用户修正 AI 行为 → 记 feedback（去重）；本任务立即遵守已知纠正。
- 进化只提建议；正式改规则/skill 需用户授权覆盖该范围，已有授权不重复申请。
- 有效教学/多轮探索/修改意见 ≠ 低效；无依据不评分、不入进化统计。

## 4. 原生 memory 纪律

- 索引 `MEMORY.md` 一主题一行；每主题一 md；官方索引上限 48 文件（路径非正文），按需读正文。
- 只记“通用知识会猜错”的 durable 事实；临时进度、猜测、密钥禁止入内。
- 红线：project memory 在**未信任 workspace 也会被读入**（注入面）。uncontrolled checkout 先审 `MEMORY.md` 再信。

## 5. 保留与销毁

- 运行态（`.agents/harness-state/`、evidence、session log、gate 账本）git 忽略；按“数量/天数/字节”三上限保留，超限先报告再销毁（`state-prune.sh` 未实现前人工执行，见 `CROSS-POLLINATION.md` §5）。
- 活动 task 引用的 evidence 与新鲜 receipt 引用的 evidence 永不删（删了等于销毁证明）。
- 敏感会话可一键清理对应 session log；销毁失败显式报告，不静默。
