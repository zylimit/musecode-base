# Cross-Pollination（吸收台账）

> 吸收与拒绝都要留痕：记录本仓从 codex-base、cc-base 学了什么、明确拒绝了什么、为什么。防止重复评估，也防止无据吸收。
> 审计日期：2026-09-19。donor 路径：`/home/z00632348/code/codex-base`、`/home/z00632348/code/cc-base`。

## 1. 审计边界（诚实声明）

**更正记录（2026-09-19）**：初版称"两 donor 仓无 skill 源码"，系用 `ls -R`（不显示 dotfiles）盘点所致的**误判**，已纠正。实际两仓均含完整 skill 源码：`cc-base/.claude/skills/`（18 个）与 `codex-base/.agents/skills/`（17 个）。

当前覆盖（源码级）：

- **35 个 SKILL.md 核心**（约 4000 行）已逐个通读并蒸馏为本仓 19 个 skill（并集，见 §6）。
- **19 个机制 references** 已通读并焊入蒸馏 skill 或指南：访谈原理/引导菜单/自检清单/0-1 流程、质量地板、风格词汇、正常对照与诊断实验、采用与退役、产物与恢复、交互设计、风险与老化、独立预期、验收与依赖、决策评价、测量方法、发现方法（清单见 §6）。
- 整件采用 6 份：质量地板、风格词汇、口径 canon、计划模板、CHANGELOG 节、skill description lint。
- 先前精读的根文档与 `docs/`（codex：AGENTS/Architecture/DFX/Product-Spec/MANIFEST/QUALITY/HARNESS-AUDIT/LARGE-REPO/OPERATIONS/CROSS-POLLINATION/ISOLATION；cc：ARCHITECTURE/README/guide-04/09/11）继续有效。

未覆盖（诚实缺口，§5）：两仓 `references/` 中 30+ 长案例/问题库/大模板（售后全套范例、双问题库 45KB、原型构造、视觉方法等）仅建索引未逐行读；codex `docs/research/*`、`tests/*.test.mjs` 断言级；cc `docs/guide` 其余 12 章断言级、`agent-notes/*`、`v3-*.md`；两仓 `.codex/runtime`、`.claude/hooks` 等运行面实现（本次未列入）。

## 2. 从 codex-base 采纳

| # | 机制 | donor 出处 | 本仓落点 | 备注 |
|---|---|---|---|---|
| X1 | 三轴分离：工程保障 / 宿主权限 / 计算策略互不冒充 | `AGENTS.md` §Assurance Profiles、`Architecture-Design.md` §2 | `docs/MUSE-NATIVE.md` §4–§6、`ARCHITECTURE.md` 红线 | Muse 侧映射为 approval/sandbox 与档位正交 |
| X2 | 唯一解析器 + 单调 floor（风险/属性/治理只能抬高） | REQ-030/031、`Architecture-Design.md` §5 | `docs/LARGE-REPO.md` §档位（简化为 fast/standard/strict 三档表） | 不做 codex 式 policy resolver 代码，只做档位表 + 校验脚本 |
| X3 | Rapid 是可偿还债务：DEFERRED ≠ PASS，换 fingerprint 不消债 | REQ-032、`Architecture-Design.md` §7 | `docs/HOOKS.md` §fast 语义、`scripts/check.sh` 债务检查 | 时限取 cc 的 8h 而非 codex 的 48h（本仓无 loan 状态机） |
| X4 | 证据绑定：receipt 绑 task/base/diff/plan/policy，旧证据 stale | REQ-012/013/033 | `docs/QUALITY_CHECKLIST.md` §0 通用证据、`ARCHITECTURE.md` 红线 3 | 不做哈希链账本；用 git diff + 测试输出作证据 |
| X5 | 五维属性证据门 + 反证优先 + security/safety/privacy 不可延期豁免 | REQ-019、`docs/QUALITY-ATTRIBUTES.md` | `docs/QUALITY_CHECKLIST.md` 全文、`docs/LARGE-REPO.md` 属性档位 | 档位六档简化为 critical/high/medium/low 四档 |
| X6 | 架构防腐三件套：声明图 + 实边扫描 + 债务棘轮，环/禁边/保护层反向不可 baseline | REQ-020 | `scripts/arch-check.sh`（最小版）+ `docs/LARGE-REPO.md` §防腐 | 实边仅 JS/TS/Python 静态 import；棘轮用 `--record/--gate` 文件比对 |
| X7 | ADR 强制：Enforced-by 必须指向真实执法点，幽灵引用 fail | REQ-020、`docs/OPERATIONS.md` §adr | `scripts/check.sh` ADR 校验 + `docs/ADR_TEMPLATE.md` | 执法点 = 本仓 script id / fitness 规则 / 人工标记 |
| X8 | 大仓顺序：catalog lint → 影响闭包 → 预算 pack → 定向验证 | `docs/LARGE-REPO-GUIDE.md` | `docs/LARGE-REPO.md` 全文 | 目标从 60 万行提到 100 万行，算法同构 |
| X9 | 单 writer 默认；并行写要 disjoint + worktree + integration owner | REQ-015、`docs/ISOLATION-PROFILES.md` | `docs/MUSE-NATIVE.md` §5、`docs/LARGE-REPO.md` §Ownership | 隔离语义直接用 Muse 原生 worktree（永不静默回落） |
| X10 | 安装器最小契约：dry-run 零写、只创建不修改、冲突落 sidecar（已有 sidecar 不覆盖）、私产不分发 | REQ-017、`scripts/codex-base.mjs` | `setup.sh`/`setup.ps1`（头注释即契约） | 撤回 staging/backup/逆序 rollback/manifest 后验/update 升级语义承诺：未实现且无需求，不补锁与账本 |
| X11 | 失败可见：FAIL/BLOCKED/DEFERRED/SKIPPED/stale 五态分明，SKIPPED 只表平台不适用 | `AGENTS.md` §核心纪律 8 | `scripts/verify.sh` 四态输出 + `docs/HOOKS.md` 退出码契约 | 空计划 = BLOCKED，不假绿 |
| X12 | fitness 反模式扫描 + 行内抑制（rule+reason 绑定） | REQ-023/038 | `scripts/fitness.sh`（grep 版五规则） | 抑制标记 `musecode-fitness:ignore`，要求同行 |
| X13 | retention/state prune：证据分级销毁，活动 task 引用永不删 | REQ-023 | `docs/MEMORY_GUIDE.md` §保留、`scripts/` 预留 | 本轮只定策略，未实现 prune 脚本（缺口 §5） |
| X14 | 严格 CLI 契约：未知 flag rc=2，ghost argument 零容忍 | REQ-036 | 全部 `scripts/*.sh` 统一 `--help` + 非法参数 rc=2 | |
| X15 | 派单契约：Goal/Scope/Out-of-Scope/Existing-Pattern/Verification/Escalation + 交接六段 | `AGENTS.md` §派发契约 | `.agents/skills/_template/SKILL.md` 输入/输出节 + `docs/LARGE-REPO.md` §派单 | Business-context 栏保留为可选 |

## 3. 从 cc-base 采纳

| # | 机制 | donor 出处 | 本仓落点 | 备注 |
|---|---|---|---|---|
| C1 | 主 Agent 唯一编排 + fresh 子 + 扁平 depth=1 | `ARCHITECTURE.md` §2 | `docs/MUSE-NATIVE.md` §5、`AGENTS.md` §3 | Muse 侧用 subagent/workflow 原生能力实现 |
| C2 | 决策自洽轴定并行：只读广度才 fan-out，编码默认串行 | `ARCHITECTURE.md` §4.2 | 同上 + `docs/LARGE-REPO.md` §Ownership | 附 Anthropic/Cognition 引用（转引自 cc 文档） |
| C3 | 档位一张表 + floor 地板闸 + raise 自动升档（改家底→strict） | `README.md` §档位、`09-gates-and-tiers.md` | `docs/HOOKS.md` §档位、`scripts/check.sh` 家底改动提示 | floor 五闸取：密钥外泄、危险删除、发布前置、记忆同步、通知 |
| C4 | fast 必带 reason + 8h 硬上限 + 到期自回 + 记账可审计 | `09-gates-and-tiers.md` §fast | `docs/HOOKS.md` §fast | 状态文件 `.agents/harness-state/tier.json`（git 忽略） |
| C5 | gate-block.log 账本 + gate-audit 死闸审计（零命中要么举证要么撤） | `09-gates-and-tiers.md` §账本 | `docs/HOOKS.md` §账本（`scripts/*.sh` 写账约定） | 本轮未实现 audit 脚本（缺口 §5） |
| C6 | diff-bound 审查回执：diff 变一字节即 stale | `11-large-repo.md` §receipt | `docs/QUALITY_CHECKLIST.md` REL-3、`scripts/check.sh` 回执绑定提示 | 不做回执文件格式；用“测试重跑 + git diff 哈希”自然实现 |
| C7 | 需求四标记 `[确认]/[推断]/[默认]/[待定]` + 复述签字 + CHANGELOG 成对 | `04-requirements-and-design.md` | `docs/REQUIREMENTS_GUIDE.md` 全文 + 需求模板 §标记 | `[待定]` 只许在待定表，功能条目挂待定即 fail |
| C8 | predev-lint 五文档闸（占位符/缺段/无度量/预算超支） | 同上 §predev-lint | `scripts/check.sh` §需求静态检查（子集） | 全量规则待补（缺口 §5） |
| C9 | ADR 九字段 + revisit-if 写条件不写日期 + reversal/单向门 | 同上 §arch | `docs/ADR_TEMPLATE.md`（已含 Enforced-by 思想，补 revisit/reversal 行） | check.sh 校验三字段存在 |
| C10 | 三层强制：会话 hook + git hook + CI（hook 只管会话内） | `README.md` §Claude Code 之外的强制层 | `docs/HOOKS.md` 三层表 + `scripts/install-githooks.sh` + CI 示例 | Muse 原生 hook 仍只管会话内，同理 |
| C11 | 记忆四系统分工：progress / feedback / domain / 角色笔记 | `ARCHITECTURE.md` §8 | `docs/MEMORY_GUIDE.md` | 角色 memory 映射为 skill 内“常见坑”节 |
| C12 | arch-trend 棘轮：per-edge 身份比对，新债零容忍 | `11-large-repo.md` §arch-trend | `scripts/arch-check.sh --record/--gate` | 老仓带债接入路径 |
| C13 | 退出码契约 0/1/2/3/4（3=降级未建立结论，4=STALE） | `11-large-repo.md` §退出码 | `docs/HOOKS.md` §退出码 + 各脚本统一 | rc=3 永不读作绿 |
| C14 | review 九 lens 三阶段 + 作者≠评审机器强制 + 删除重命名单列 | `README.md` §大仓能力 | `docs/QUALITY_CHECKLIST.md` REL 节 + `.agents/skills/code-review/` skill | 作者账本用 git author 实现最小版 |

## 4. 明确拒绝（及理由）

| # | donor 机制 | 拒绝理由 |
|---|---|---|
| R1 | codex 完整 Assurance Policy resolver 代码 + policyHash 状态机 | 本仓无 `.codex/runtime` 等价物；Muse 原生 approval/sandbox 已覆盖权限轴，工程档位用静态表 + 脚本校验足够，不造第二套状态机 |
| R2 | codex 账本哈希链 + 轮转 + attestation | 同上；git 历史 + 测试输出即证据链，不引入本地伪信任根 |
| R3 | codex `service` 开发服务守护 | 本仓是脚手架非产品运行面；长驻服务归 systemd/k8s/supervisor 各项目自理 |
| R4 | codex 48h Rapid loan + 跨 fingerprint 债务索引 | 无状态机支撑时做不实；取 cc 的 8h fast + 人工记账 |
| R5 | cc auto-push（commit 后自动 push） | 违反最小副作用与 Muse 保守默认（不经要求不 push）；codex 台账同样拒绝 |
| R6 | cc kill-dev-ports（起服务前清端口） | 可能杀用户进程，违反 SAF-2；codex 台账同样拒绝 |
| R7 | cc `.needs-review` 全局布尔 marker | 可伪造、无绑定；已被 diff-bound 思想取代（C6） |
| R8 | cc 三文件同步 Stop 硬闸（每次编辑机械写 progress） | 误报噪音；改为决策/约束/风险出现才记（codex REQ-016 纪律） |
| R9 | cc TDD gate（派单前查 `.red-verified`） | 本仓无 Sub-Agent 派单 hook 面（Muse hook 在沙箱外且无 Agent 事件 matcher 细节）；TDD 由 skill 约定承载 |
| R10 | 两仓的 daemon/tmux/多模型 fan-out、兄弟仓脚本互调 | 非 Muse 原生运行面；多智能体只用 Workflow/subagent 原生能力 |
| R11 | 两仓的 300 行/测试比例/覆盖率数字门 | 以风险覆盖与有效性为准，不为数字凑用例（codex QUALITY-ECONOMY 纪律） |

## 5. 缺口与后续增量（诚实未完成项）

- [ ] codex `tests/*.test.mjs` 断言级吸收（突变测试、execpolicy 向量、installer 黑盒）→ 待第二轮精读。
- [ ] cc `docs/guide` 剩余 12 章 + `docs/agent-notes/*` + `docs/v3-*.md` → 待第二轮精读。
- [ ] `scripts/gate-audit.sh`（C5 死闸审计）与 `scripts/state-prune.sh`（X13 保留销毁）未实现。
- [ ] `scripts/check.sh` 的 predev-lint 全量子集（C8 仅落地占位符/缺段/待定三规则）。
- [ ] Muse 官方 `interactive`/`session-messaging`/`rewind`/`auth` 页正文未抓（见 `docs/MUSE-NATIVE.md` §10）。
- [x] skill 支撑文件：30+ 文件已整件收录 + 5 处供体专用适配 + 12 张主入口路由表（见 §6）。方法实际采用效果待真实任务观察。
- [ ] `design-maker` 的 UI 审计脚本（`ui-audit.mjs` 等价物）未实现；`red-blue-review` 证据脚本已落地最小版。

## 6. Skill 吸收台账（2026-09-19 精读蒸馏 + 整改轮同步）

donor 并集 19 个 skill，主入口 SKILL.md 19/19 已落地；references 30+ 文件已整件收录（非"仅索引"，旧说法已更正），供体专用 5 处已适配（2 处 predev 路径、1 处 setup 路径、1 处 exec-envelope 机制、1 处示例命令标注），主入口路由 12/12 已接。收录≠验证效果：方法类参考的实际采用以后续真实任务观察为准。

| 本仓 skill | 主入口 | references 收录 | 主入口路由 | 适配/验证备注 |
|---|---|---|---|---|
| product-spec-builder | √ | 10 件整件 | √ 参考节 10 条 | 通用方法原样保留；触发条件已补 |
| arch-designer | √ | 3 件整件 | √ 参考节 3 条 | 同上 |
| dfx-designer | √ | 2 件整件 | √ 参考节 2 条 | 范例 setup 路径已适配本仓 |
| design-brief-builder | √ | 7 件整件 | √ 参考节 7 条 | 2 处 predev-lint 路径已适配本仓 |
| design-maker | √ | 3 件整件 | √ 参考节 3 条 | 通用方法原样保留 |
| dev-planner | √ | 1 件整件 | √ 参考节 1 条 | 同上 |
| dev-builder | √ | 2 件整件 | √ 参考节 2 条 | 同上 |
| bug-fixer | √ | 1 件整件 | √ 参考节 1 条 | 同上 |
| code-review | √ | —（无） | — | 独立预期由 test-builder 侧共用 |
| test-builder | √ | 3 件整件 | √ 参考节 3 条 | exec-envelope 句已改本仓九段信封；脚手架示例命令已标注 |
| red-blue-review | √ | —（无） | — | 证据包脚本自写（行为对齐 donor） |
| release-builder | √ | 1 件整件 | √ 参考节 1 条 | 通用方法原样保留 |
| branch-finisher | √ | —（无） | — | — |
| large-repo-harness | √ | —（无） | — | catalog 示例在 `.agents/harness/` |
| skill-builder | √ | 1 件整件 | √ 参考节 1 条 | description-lint→`scripts/skill-lint.sh` |
| feedback-writer | √ | —（无） | — | feedback 双模板→`.agents/feedback/` |
| evolution-engine | √ | 1 件整件 | √ 参考节 1 条 | 通用方法原样保留 |
| progress-recorder | √ | —（无） | — | — |
| domain-rulings | √ | —（无） | — | canon→`.agents/rules/domain-rulings.md` |

未收录（无义务读完，按失败路径深读时再取）：供体 `templates/*.md` 模板文件、`skill-builder/scripts/test-skill-behavior.sh`、donor runtime 私有脚本。整件采用到本仓正文的另计 6 件：地板→`docs/UI-QUALITY-FLOOR.md`、词汇→`docs/DESIGN_VOCABULARY.md`、口径→`.agents/rules/domain-rulings.md`、计划模板→`docs/PLAN_TEMPLATE.md`、CHANGELOG 节→REQ 模板 §8、自检清单→指南 §7。
