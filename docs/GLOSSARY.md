# 术语表（GLOSSARY）

> 来源：cc `docs/guide/15-glossary.md`（适配本仓路径与命名）。

| 术语 | 含义 |
|---|---|
| REQ | 需求文档（`docs/REQ-*.md`），下游唯一需求来源 |
| 四标记 | `[确认]/[推断]/[默认]/[待定]`，每条需求的来源标记 |
| 复述签字 | 用用户案例讲一遍上线行为、逐段确认的交付闸 |
| ADR | 架构决策记录（`docs/adr/NNNN-*.md`），九字段 |
| Phase/Task | 计划的两级：Phase 可独立验收，Task 是执行单元 |
| 派单包 | 七字段（Goal/Scope/Out-of-Scope/Existing-Pattern/Business-Context/Verification/Escalation） |
| 交接信封 | 九段回执（Status/Changed/Verified/Not-verified/Needs-review-by/Evidence/假设/反例/口径发现） |
| skill | 可复用能力（`.agents/skills/<id>/SKILL.md`），slash 调用或派单引用 |
| 门禁链 | smoke → verify → check（+ arch-check / predev-lint / plan-lint 按需） |
| 四态 | PASS / FAIL / BLOCKED / SKIPPED；空计划 = BLOCKED |
| 降级 rc=3 | 什么都没建立的结论，永不读作绿 |
| 档位 | fast（8h+reason+记账）/ standard / strict（改家底自动升） |
| 地板闸 | 任何档位都 block 的五闸（密钥/危险删除/发布/记忆/通知） |
| catalog | 模块目录（`.agents/harness/module-catalog.json`），大仓治理开关 |
| 胶囊 | 模块摘要单元（context-pack 用），见 capsule-template |
| 口径 | 领域里"怎么算"（`domain/`），跟领域走 |
| feedback | AI 行为教训（`.agents/feedback/`），进化引擎的输入 |
| 毕业 | feedback 命中实证门槛后升为正式规则 |
| 红锁 | 修复前必先有的失败测试（红在预期原因上） |
| 三次熔断 | 同一根因连修三次不好即停手上报 |
| 三件套 | 需求/ADR/测试同改；pre-commit 校验 |
| worktree | 并行写的隔离区；读留在共享区 |
| 棘轮 | arch 基线：新边零容忍，老债慢慢还 |
| 账本 | gate-block.log（拦截记录）/ test-ledger.jsonl（测试运行记录） |
