# HARNESS.md — harness 复用清单

> 目标：沉淀可复用的执行脚手架能力，避免每个任务重复造轮子。
> 出处标注：`codex` = Codex 侧 harness 经验，`cc` = Claude Code 侧 harness 经验，`local` = 本仓原创。

## 1. 复用清单

| # | 能力 | 说明 | 出处 | 落点 |
|---|---|---|---|---|
| H4 | 验证门禁 | lint → 单测 → 触及面包 → 全量的可配置流水线 | cc | `scripts/verify.sh` |
| H5 | 需求→ADR→交付链 | 模板化需求与决策，交付自动校验 checklist | local | `docs/`, `scripts/check.sh` |
| H6 | 产物防伪 | 生成文件只由 sanctioned writer 写，手工冒充即失败 | cc | `scripts/verify.sh` |
| H8 | 反模式扫描 | 五规则 grep 版 + 行内抑制 | codex+cc | `scripts/fitness.sh` |
| H9 | 架构防腐 | 声明图 + 实边 + 棘轮，禁边永不可 baseline | codex+cc | `scripts/arch-check.sh` |
| H10 | 分发与自检 | 安装器 + manifest + 契约测试 | codex+cc | `setup.*`、`manifest.sh`、`tests/`（原生 `skills install` 只收本地单 skill、`import` 只收别家目录、plugin 只带 skills/commands/hooks；多资产分发+sidecar 升级语义无原生覆盖，安装器保留） |
| H11 | 可复用编排 | 只读 review workflow + code-review skill | cc+muse 原生 | `.agents/workflows/`、`.agents/skills/` |

## 2. 复用规则

- 先查本表，再决定自研；自研能力合入后回填本表。
- 引用时注明出处编号（如 `H4`），便于追溯 codex/cc 侧上游变更。
- 出处只代表经验来源，不代表代码拷贝；上游协议若有约束，以上游 LICENSE 为准。

## 3. 已落地（2026-09-19）

- [x] H4 `scripts/verify.sh`：smoke + shell/python/node 按栈探测 lint + 触及面测试，四态输出。
- [x] H5 `scripts/check.sh`：REQ 静态闸（占位符/待定/来源标记/待定表）+ ADR 执法校验 + 三件套存在性。
- [x] H8 `scripts/fitness.sh`：五规则反模式扫描（密钥/PII/静默吞错/无界重试/无主遗留标记）。
- [x] H9 `scripts/arch-check.sh`：catalog 声明图校验 + JS/TS/Python 实边对照 + `--record/--gate` 棘轮。
- [x] H10 `scripts/install-githooks.sh` + `setup.sh/setup.ps1` + `scripts/manifest.sh` + `tests/test_contract.py`。
- [x] H11 可复用 workflow 示例 `.agents/workflows/review-change.js` + skill `code-review`。

## 4. 待补（缺口，见 `docs/CROSS-POLLINATION.md` §5）

- [ ] `check.sh` 的 predev-lint 全量子集（度量数字/预算表/ADR 九字段全校）。
- [ ] harness-state 子目录规范：Muse session 日志由运行时管理，本仓只定 `.agents/harness-state/` 下的自有文件约定。

> 已删除编号：H1（会话与日志）、H2（沙箱执行）、H3（工具路由）、H7（降级表达）——运行时能力归 Muse 本体，不在本仓实现；编号空缺不重排。
