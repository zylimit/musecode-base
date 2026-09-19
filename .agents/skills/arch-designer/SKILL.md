---
name: arch-designer
description: 当需求已定、要做技术方案/架构设计/写ADR，或争论该用什么方案时使用。产出架构决策与 ADR。
---

# arch-designer

- 版本：1.0.0
- 适用：新系统/新模块/跨模块变更的技术方案。S 级小改（单文件、错误文案）直接写代码，不开本 skill。
- 输入：`docs/REQ-*.md` + DFX 目标（如有）+ 现有代码与 ADR。
- 输出：架构方案（写入 `ARCHITECTURE.md` 相关节或设计文档）+ `docs/adr/NNNN-*.md`。

## 步骤

1. 定规模：S（实现细节式记录）/M（模块内多文件）/L（跨模块/公共契约/数据归属）。L 级必须 ADR。
2. 业务事件检验边界：列 3–5 个核心事件追演，给每个数据定"事实归属"（谁产生/谁是唯一真相源/其余是缓存还是投影），所有权不明先定归属再定责。
3. 方案比较：先找驱动因素（不变量/质量目标/现实约束/关键未知），再写可区分方案的质量场景（触发/刺激/环境/对象/期望响应/判据），2–3 个候选 × 同一场景同断点比较（不给推荐方案开小灶）；找敏感假设及跨属性代价（重试↔流量放大、缓存↔越权可见等）；先写推翻条件再选最小验证。拒绝"列优缺点打分"。
4. 定分层与依赖方向：只许同层或向内；跨模块边写进 catalog（`docs/LARGE-REPO.md` §2），禁边在 decision 里点名。
5. 写 ADR：九字段齐（背景/决策/备选/后果/实施/Enforced-by/revisit-if/reversal），Enforced-by 必须指向真实执法点（脚本 id/fitness 规则/`manual:`+评审人），revisit-if 写条件不写日期。
6. 三文件同步：新决策进 `progress.md` Decisions；"既定不可碰"进 Pinned；后果里的实施清单进计划。
7. 跑 `bash scripts/check.sh`（ADR 幽灵引用校验）与 `bash scripts/arch-check.sh`（有 catalog 时）。

## 约束与红线

- 契约来自仓内：类型/调用方/现有测试即真实契约（`ARCHITECTURE.md` 红线 1）；最小改动，不引入未被要求的接口与依赖（红线 2）。
- 成对边界（start/end）用同一约定并写明 inclusive/exclusive 依据。
- 未知库/协议先查官方资料，不凭记忆定技术选型。

## 验收

- ADR 九字段齐且 `check.sh` 无 ADR_GHOST_REF；L 级有方案比较记录与被否方案的反例。
- 包络完整：成功路径 + 异常（超时/冲突/降级）+ 回滚/补偿，每条 DFX 目标有落在架构上的承接点。

## 示例

争论"订单状态放订单服务还是履约服务"：列"退款后显示什么"事件追演 → 事实归属定履约 → 订单侧只存投影 → ADR 记录 + catalog 加边 + `arch-check.sh` 验证无环。

## Donor 出处

- `cc-base/.claude/skills/arch-designer/SKILL.md`（S/M/L、事件检验、ADR 九字段、包络）
- `codex-base/.agents/skills/arch-designer/SKILL.md`（事实归属、反证优先、状态归属、压力场景）
