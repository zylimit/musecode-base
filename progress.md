# progress.md（项目记忆）

> 决策/约束/完成/待办/风险。行为修正进 `.agents/feedback/`，领域口径进 `domain/`，durable 原生记忆进 `.agents/memory/`。

## Pinned（封顶 15）

- P1：项目 skills 唯一路径 `.agents/skills/`（ADR-0001，原生合规）。
- P2：门禁按序 smoke → verify → check（+ arch-check）；禁 `--no-verify`。
- P3：`rc=3` 降级永不读作绿；空计划 = BLOCKED。
- P4：security/safety/privacy 类检查永不可豁免、不可 fast 跳过。
- P5：不经要求不 commit/push；2026-09-19 用户明确要求首推后已 push（本条约束继续有效）。

## Decisions

- D1（2026-09-19）：脚手架布局对齐 Muse 原生加载规则（`.agents/skills|memory|workflows` + `.muse/hooks.json`），出处 `docs/MUSE-NATIVE.md`。替代：初版 `.muse/skills/`（违规，已迁）。
- D2（2026-09-19）：工程档位用静态表（fast/standard/strict + floor + raise），不做 codex 式 policy resolver 代码——无 runtime 支撑时不做伪状态机。
- D3（2026-09-19）：fast 取 cc 的 8h 上限（非 codex 48h），无 loan 状态机时人工记账。
- D4（2026-09-19）：证据链 = git 历史 + 测试输出，不做本地哈希链账本（不造伪信任根）。
- D5（2026-09-19）：manifest 口径恒用 find，不用 git ls-files（unborn/部分暂存/未跟踪三种漏口）。
- D6（2026-09-19）：拒绝 auto-push、kill 端口、全局 marker、TDD 硬闸、daemon/多模型 fan-out（理由见 `docs/CROSS-POLLINATION.md` §4）。

## Done

- 2026-09-19：Workflow 12 智能体深度分析（codex/cc/muse-docs/治理/质量/效率七路 + critic + 跟进 + 综合 + 两步落地），产出初版骨架。
- 2026-09-19：原生合规修正（ADR-0001）+ `MUSE-NATIVE.md`（官方 5 页正文抓取对齐）。
- 2026-09-19：`CROSS-POLLINATION.md`（X1–X15/C1–C14/R1–R11）+ 需求/大仓/记忆三指南 + 示例 ADR。
- 2026-09-19：门禁脚本全落地（verify/check/fitness/arch-check/install-githooks/manifest）+ 契约测试 12 项 + 安装器双平台 + git init + hooks 安装。全绿：smoke 57/0、verify PASS、pytest 12/12、shellcheck clean。
- 2026-09-19：首推 `github.com/zylimit/musecode-base`（空仓检视确认后 `main` 首 commit + push；P5 关闭）。

## 待办

- [ ] P0：`gate-audit.sh`（死闸审计）与 `state-prune.sh`（保留销毁）。
- [ ] P0：`check.sh` 补 predev-lint 全量子集（度量数字/预算表/ADR 九字段）。
- [ ] P1：第二轮精读（codex tests 断言级 + drill research 深层；cc 其余 12 章 + agent-notes + v3 文档）。
- [ ] P1：抓官方 `interactive`/`session-messaging`/`rewind`/`auth` 页正文，补 `MUSE-NATIVE.md` §10。
- [ ] P1：`.muse/hooks.json` 字段 schema 实测补全（现为骨架示例）。

## Risks

- R1：donor 仓无运行面源码（`.codex/runtime`、`.claude/harness` 均不在仓内），吸收止于文档+脚本+测试层——已在台账 §1 声明。
- R2：hooks.json 官方无字段级 schema，示例未经 `muse` 实测——以骨架 + 警告交付，未启用。
- R3：100 万行治理算法（影响闭包/context pack）有文档无运行时——catalog/impact 的可执行引擎是下一阶段。
