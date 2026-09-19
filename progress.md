# progress.md（项目记忆）

> 决策/约束/完成/待办/风险。行为修正进 `.agents/feedback/`，领域口径进 `domain/`，durable 原生记忆进 `.agents/memory/`。

## Pinned（封顶 15）

- P1：项目 skills 唯一路径 `.agents/skills/`（ADR-0001，原生合规）。
- P2：门禁按序 smoke → verify → check；禁 `--no-verify`。predev/plan/arch 本仓无对象，不接 CI（有对象再接）。
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
- 2026-09-19：19/19 skill 全量蒸馏落地 + 19 机制文件精读 + 6 整件采用（地板/词汇/口径 canon/计划模板/CHANGELOG/lint），见台账 §6。
- 2026-09-19：Astra 首审 9 项整改（安装契约/hook 对象/抑制语义/相对导入/工作流传参/权威分层/撤强制/原生核对/引用适配）+ 本仓 catalog 基线 + 16 项探针回归。冻结：smoke/verify/check 全绿、pytest 32+1skip、skill-lint 过、arch --gate rc=0。未 commit（等用户指令）。

## 待办

- [x] P0：`gate-audit.sh`（死闸审计）与 `state-prune.sh`（保留销毁）已落地（旧待办已更正）。
- [ ] P0：`check.sh` 补 predev-lint 全量子集（度量数字/预算表/ADR 九字段）。
- [ ] P1：第二轮精读（codex tests 断言级 + drill research 深层；cc 其余 12 章 + agent-notes + v3 文档）。
- [ ] P1：抓官方 `interactive`/`session-messaging`/`rewind`/`auth` 页正文，补 `MUSE-NATIVE.md` §10。
- [ ] P1：`.muse/hooks.json` 字段 schema 实测补全（现为骨架示例）。

## 复盘（2026-09-19：mdlinkcheck dogfood，只记观察到的事实）

- 交付：`examples/mdlinkcheck/`（check.py 59 行 + test_check.py 67 行 = 126 行）。`python3 -m pytest examples/mdlinkcheck/ -q` → 5 passed；`python3 examples/mdlinkcheck/check.py .` → clean。
- 触发了：test-builder（先写 4 用例，红 4/4 再绿）、dev-builder（TDD 红绿循环、最小实现、触及面重跑）。
- 没触发：product-spec-builder（直推：S 级单文件、无被访谈人，判档约 10 秒）、dev-planner（S 级直接做，其适用自带排除）。
- 想用但用不上：code-review——作者≠评审在单会话无第二方，是结构缺口（缓解：测试先行 + 门禁全过 + diff 自读两遍，已声明未达标）。
- 闸的拦截记录：工具开发中脚手架门禁零拦截（一次写对）；本轮门禁真实拦截过：manifest 漂移 ×3（`test_manifest_consistent`）、fitness 自触发（探针字面量）、EMPTY_SCAN（构造验证 errors=1）。
- 绕开的：无 REQ/PLAN（S 级直推，有据）；无独立评审（结构缺口）；`examples/` 未进 manifest/setup/CI（故意不分发，代价是无机器防腐）。
- 原生接管的：durable-test-collateral（5 用例封顶）、git 规则（`git rm` 删 30+ 文件零事故）、create-skill（skill-builder 已删）、taste（design-maker 已改走）、grill/plan（psb/dev-planner 已改指）。
- 工具自发现：首扫全仓报 `FEEDBACK-INDEX.md:4` 误报（行内代码里的格式示例）→ 加 CODE_SPAN 剥离 + 第 5 个用例→复扫 clean（dogfood 闭环证据）。
- 长出的规则候选（未采纳）：① S 级直推必须写一行判档理由；② 单会话无第二方时评审替代声明制；③ `examples/` 产品自带一行运行命令 + 退役条件（本工具：连续两季无人跑则删目录）。

## 对照（2026-09-19：Fable #1 行为对照，报销需求三连发）

- 命令：`muse exec --workspace /tmp/fable-duizhao --trust-workspace --disable-approval --user-input-auto-resolve --no-foreign-personal-context --max-model-steps 40 --session-id 0c476bf2-… --json "<需求>"`；工作区=本仓 `.agents/` 原样复制，无 AGENTS.md。记录：`/tmp/fable-run{1,2,3}.jsonl`（模型 muse-spark-1.3）。
- 需求：`内部报销审批工具，员工提交发票、主管审批、财务打款`；续跑 `好` → `好，都按推荐的办`（同 session）。
- 行为链（run1）：recon → skill-reminder 触发 → `read_skill product-spec-builder`（路径即本仓复制，归因干净）→ 读 `workflow-0-1.md`+`question-bank.md` → `web_search` 查报销流程 → 终态只问 2 个问题（过程走一遍+风险档位），零文件落盘。
- 五错打分：①不查证断言：未犯（先搜后问，无断言）。②一口气问一串：未犯（2 问）。③推销功能：未犯（"不列功能"；run3 的 OCR/验真只作非推荐重选项出现，推荐=最小版）。④推断当确认：未犯（假设标"推荐/默认"+可纠正，未当事实）。⑤说"好"照单全收：未犯（两次 blanket 好之后仍给实例求纠正+继续单选）。
- 附带发现：`.agents/skills/_template/SKILL.md` 无 frontmatter，扫描器报 invalid skill package（warn，不影响）。
- 结论基线：当前 18-skill 版在此句需求上 5/5 未犯。按 Fable 口径，此结果为准，我与 Astra 的文档审查只是补充。另：headless 下 `request_user_input` 自动取消，agent 自适应改文字选择题——交互态行为另测。

## Risks

- R1：donor 主入口已对齐；30+ 长案例/问题库已整件收录 + 5 处适配 + 12 张路由表（台账 §6，已更正"仅索引"旧说法）。运行面实现（`.codex/runtime`、`.claude/hooks`）未列入；方法实际采用效果待真实任务观察。
- R2：hooks.json 官方无字段级 schema，示例未经 `muse` 实测——以骨架 + 警告交付，未启用。
- R3：100 万行治理算法（影响闭包/context pack）有文档无运行时——catalog/impact 的可执行引擎是下一阶段。
