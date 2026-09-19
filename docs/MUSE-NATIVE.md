# Muse 原生能力映射与合规红线

> 本文件是本仓与 Muse Code 官方行为对齐的唯一依据。每条均注明官方文档出处，URL 去掉 `team_id/project_id` 查询串后仍可定位到同页。
> 文档基线：2026-09-19 实测抓取（`dev.meta.ai/docs/muse-code/*`，HTTP 200）。
> 官方没有发布“脚手架复制面规范”（不存在等价于 codex-base `AGENTS.md + .codex/ + .agents/` 的官方标准；`muse init` 只写单个 `AGENTS.md`）。
> 因此本仓布局是“对齐原生加载规则的最小约定”，§9 给出对照表。本文件与 `AGENTS.md` 冲突时以本文件为准。

## 1. AGENTS.md 加载规则（项目指令）

- 来源：[Configuration and context](https://dev.meta.ai/docs/muse-code/configuration)
- `muse init` 只在当前目录写一个 `AGENTS.md`，不建其他文件、不改 `settings.json`；`--dry-run` 只看不写；无 `--force` 时已存在则停，`--force` 全量覆盖。
- 加载顺序：从 workspace root 向上走到最近 `.git` 边界；**每层**按 `AGENTS.md` → `CLAUDE.md` → `.agents/AGENTS.md` → `.claude/CLAUDE.md` 检查，本层命中第一个即胜出。
- 冲突优先级：**项目规则 > 用户规则**；项目文件之间**深层 > 浅层**。
- 信任门：用户规则恒加载；**项目规则仅在信任 workspace 后加载**，未信任 checkout 的项目 `AGENTS.md`/`CLAUDE.md` 被忽略。
- 保守默认：不经本 session 明确要求，不 commit/amend/push；草稿放 checkout 之外；回滚附带改动；任务结束 ≠ 提交请求。

本仓落实：根 `AGENTS.md` 即项目指令；大仓子系统可用更深的 `AGENTS.md` 承载局部规则（深层胜出）。

## 2. Skills（四源 + CLI）

- 来源：[Extending and automating](https://dev.meta.ai/docs/muse-code/extending)
- 四源：Built-in（随包）/ User（`$XDG_CONFIG_HOME/muse/skills` 与 `~/.agents/skills`，另默认发现 `~/.claude/skills`、`$CODEX_HOME/skills` 回退 `~/.codex/skills`）/ **Project（`<repo>/.agents/skills/<skill-id>/SKILL.md`，另扫描 `.codex/skills`、`.claude/skills`）** / Plugin。
- 管理命令：`muse skills list|inspect|enable|install|validate`，`muse skills import --from claude|codex`。
- 会话内用 slash 快捷调用；内置 `/plan`（成计划后停待批）、`/grill`（ plans 压测并落书面范围契约）、`/taste`（前端设计门）、`/threejs`；后台 observer 可提示应先加载的 skill。
- `/migrate` 导入 Claude/Codex 的记忆与 MCP（与 `skills import` 互补）。

本仓落实：项目 skills 只放 `.agents/skills/<id>/SKILL.md`（见 `.agents/skills/SKILLS_SPEC.md`）。**`.muse/skills/` 是违规路径**，已在 ADR-0001 中迁走。

## 3. Hooks（3 源 + 15 事件，跑在沙箱之外）

- 来源：[Extending and automating](https://dev.meta.ai/docs/muse-code/extending)
- 三源：Project（`<root>/.muse/hooks.json`，需先信任项目）/ User（settings 内，无需额外信任步）/ Managed（`managed_hooks_path` 指向文件，无需信任步，谁控文件谁控执行）。
- 15 事件（每钩_exactly_一事件）：`SessionStart`、`UserPromptSubmit`、`PreToolUse`、`PermissionRequest`、`PostToolUse`、`PostToolUseFailure`、`PreLLMCall`、`PostLLMCall`、`PreCompact`、`PostCompact`、`SubagentStart`、`SubagentStop`、`Notification`、`Stop`、`SessionEnd`。`SessionEnd` 纯观测，不能拦终止、不能注上下文。
- 会话启动时发现并校验：项目/托管文件畸形 → 该源零 handler + 启动警告；用户 settings 畸形 → 设置校验失败；不支持的事件/matcher/handler 跳过该条 + 警告。
- 无 `muse hooks` 命令族、无逐钩信任命令：改配置后**开新会话**重载。
- 红线：**hook 命令直跑你的 shell，在 sandbox 与 approval 之外**，仅有清空环境 + 小白名单加固。只接入读过的命令。

本仓落实：`.muse/hooks.json` 只放读过、短小、有界的命令；重逻辑放 `scripts/` 由 hook 调用；hook 视角的门禁分层见 `docs/HOOKS.md`。

## 4. 权限两层 + 画像 + 分级审批

- 来源：[Permissions and safety](https://dev.meta.ai/docs/muse-code/permissions)
- 两层独立：Approval（副作用前按策略判，安全过、危险停）+ Sandbox（OS 强制：macOS Seatbelt / Linux bubblewrap / Windows sandbox；不能确认沙箱生效则拒跑）。
- 画像（`permissions.default_profile`）：Ask me（逐条亲决）/ **Auto-review（默认：同 Ask me 权限，自动评审先判，不可用回落问人）** / Unrestricted（= `--yolo`，仅隔离环境）/ Read-only。
- 审批模式（`--approval-mode`）：`on-request`（默认：危险/外部执行模式停，如破坏性删除、`rg -z/--search-zip/--pre/--hostname-bin`，并看穿 wrapper）/ `untrusted`（无 allow 规则即停，仅升级 shell，文件读与仓内写照过）/ `never`（只剩沙箱）。
- `--approval-judge off` 关闭自动评审，全部亲决。
- 分级审批：复合 shell 按 stage 逐段审，首个不可批即 hold 全命令；拒绝则整条不跑。Windows 走 PowerShell，同规则。
- 信任粒度：Allow once / Always allow in this workspace（前缀规则，deny 恒胜 allow；`python/bash/node` 等解释器前缀不可存为宽 allow）/ Reject。会话消息有独立 peer 准入边界，他会话消息**不能批工具、不能给同意、不能改本会话权限**。
- 沙箱：可写 workspace + temp，其余只读；仓内 `.git/.muse/.agents` 只读（agent 不能改自己的历史/配置/记忆）。网络 `--sandbox-network`：`proxy-only`（默认：新目标首连审批）/ `restricted`（断网）/ `enabled`（全放）。
- `--yolo` = 去审批 + 去沙箱 + 信任 workspace；PR/fork checkout 的 `AGENTS.md`/rules/skills 是攻击者可控指令，禁止在真机 `--yolo` 跑不可信 checkout。

本仓落实：门禁脚本默认只读检查；需写的脚本必须 `--dry-run` 先行；密钥与远端副作用永不进 allow 规则；见 `docs/QUALITY_CHECKLIST.md` SEC/SAF。

运行态写路径说明：本仓运行态（`tier.json`、test-ledger、gate 日志）落 `.agents/harness-state/`（git 忽略）。官方文档默认该目录只读，但本机实测会话（托管沙箱）可写——`tier.sh on/off/status` 已验证读写正常。两条防御代替 `--yolo`：`tier.sh` 状态不可写时显式报错退出 2（不伪装档位）；`verify.sh` 的 ledger 写入失败静默旁路（判决不依赖日志落盘，设计如此）。若你的会话 sandbox 禁写该目录，tier 相关命令会明确报错，按提示处理，不要开 `--yolo` 绕过。

## 5. Subagents（容量 8 / worktree 隔离 / observer）

- 来源：[Extending and automating](https://dev.meta.ai/docs/muse-code/extending)
- lead 派 bounded 任务；默认共享 checkout；**并行写才要 worktree 隔离**，只读留在共享区。隔离子得一个 Muse 管理的 Git worktree；profile/workspace/provider/Git 任一不支持即**拒绝，永不静默回落**。`--subagent-worktree-isolation` 只是兼容旗，不强制全隔离。
- 容量：单 agent 树默认 8（含 root），`settings.json` 中 `agents.execution_capacity` 可设 1–64，未配置的 ultra root 用 64；树满则新 spawn 被拒；接纳后仍可能排队等宿主调度槽；孙辈共享 root 容量；取消是协作式的（写一半先写完）；全程 journal（谁何时干什么可查）；子**仅在任务明说时才 commit**。
- `/subagents` 看运行/历史，`/tasks` 管直派任务。
- 后台 observer 四个**默认全开**（各有独立模型调用，加 token）：Memory recall / Skill recall / Goal tracking / Verification（核查 agent 是否真跑了所称工作）；提议 → reconciler 裁决 → 仅接纳的进主 agent 下一轮。可用 settings 的 `runtime_capabilities` 关。

本仓落实：编码默认串行（共享契约决策需自洽，见 `ARCHITECTURE.md`）；只读广度（审查维度/探索/批量验）才 fan-out；并行写必须 disjoint 路径 + 独立 worktree + 指定 integration owner；任何 fan-out 需用户显式 opt-in（成本与风险见 `docs/LARGE-REPO.md`）。

## 6. Workflows（可用性 / 1000 / 16 / save / recover）

- 来源：[Workflows](https://dev.meta.ai/docs/muse-code/workflows)
- 可用性：需含 workflow 脚本引擎的构建 + `WorkflowTool` 灰度；二者缺一则无 Workflow 工具与 `/workflows`；公开 `aarch64-apple-darwin` 包无 `workflow-script-engine-v8`，该产物上不可用。
- 本机实测（`Muse Code 1.3.0 (1.3.0-R3401.1)`）：主 help 不列 workflows，但 `muse workflows --help` 可响应——`save/list` 可用；`run/recover` 系 QA 通道（help 明示"not advertised…kept for headless QA seeding and release smokes"），日常评审走子代理。单看一个帮助列表不足以定能力，须逐项实测。
- 显式请求直接启动无二次确认；`Workflows=auto` 时任务够大可提议。
- 上限：单 workflow 生涯最多 1000 child 调用，第 1001 个在启动前失败；本地活跃子上限 CPU 导出封顶 16，超宽 batch 排队。
- `/workflows` 控制室：状态/耗时/token/子进度；C 取消选中，R 看完成结果；运行内 P 暂停/恢复、X 跳过选中运行子、R 重启选中运行子（**不是**已完成/失败子的通用重试）。后台继续跑，完成自动投递，不轮询。
- 写文件任务要声明并行 writer 是否用隔离 worktree；只读子留共享区；隔离规则同 subagent（需 Git 仓，永不静默回落）。
- 可复用脚本：`muse workflows save <name> --from <file> --scope project` 落 `.agents/workflows/<name>.js`，commit 后他 clone 才可见；user 域存配置目录；`muse workflows list`（先在仓内启动并信任，再退出跑）；project 域重名优先；会话启动加载一次（存后重启）；命名 `[a-z0-9._-]{1,64}` 首字符小写字母/数字；源文件常规非空 UTF-8 ≤ 512 KiB；save 只验文件+名不解析 JS，语法错在启动时爆；同目标冲突除非 `--overwrite`；终值必须 JSON 可序列化（`undefined` 即失败）。
- 恢复：inline 脚本落该 session 保留目录的 workflow 子目录，`scriptPath` 在结果中回传；`--no-session-log` 会话用进程级临时存储，进程退出即失，不可恢复。同进程：等 owner 停 → 改 `scriptPath` → 同 `resumeFromRunId` 重调，复用最长未变已完成前缀。跨重启：`muse workflows recover <run-id> --session <session-id> --apply`。同时只跑一个 owner。
- `/settings` → Tools > Workflows：`auto` / `explicit` / `off`（off 摘除工具），即时生效。

本仓落实：可复用 workflow 脚本放 `.agents/workflows/` 并随仓提交（示例见该目录）；workflow 内只读子共享区、写子隔离 worktree；终值一律 `{status, ref(s), unresolved, notes}`。

## 7. Memory（三域 + 48 + 注入警告）

- 来源：[Configuration and context](https://dev.meta.ai/docs/muse-code/configuration)
- 三域：Personal project（默认，机内存仓外，本项目私有）/ **Project（随仓 `<repo>/.agents/memory/`，clone 共享）** / Personal（机内跨项目）。
- 布局：`MEMORY.md` 索引（一主题一行）+ 每主题一 md。记“通用知识会猜错”的 durable 事实：部署步骤、workaround 成因、服务怪癖。
- 会话初注入**索引**（`MEMORY.md` + 至多 48 个文件的路径非正文），正文按需读；observer 可提前塞相关条。
- 红线：**已提交的 project memory 在未信任 workspace 也会被读入上下文**（skills/rules/hooks 则必须先信任）。把他仓 `MEMORY.md` 当 prompt 注入面，uncontrolled checkout 先审后信。

本仓落实：记忆布局与四系统分工见 `docs/MEMORY_GUIDE.md`；`MEMORY.md` 只记 durable 事实，不记临时进度、猜测、密钥。

## 8. Headless / CI 与会话协议

- 来源：[Extending and automating](https://dev.meta.ai/docs/muse-code/extending)、[Overview](https://dev.meta.ai/docs/muse-code)
- `muse exec "<prompt>"` 单 prompt 跑到完成；`--prompt-file`、`--json`（stdout JSONL 事件）。退出码只表**轮次怎么结束**不表**活干得对不对**：0 轮完 / 1 失败或取消（含 `--max-model-steps` 封顶）/ 2 用法错 / 130/143 信号。**CI 门必须挂自己的测试命令，不能只看 exit 0**（agent 可能报告着红测试正常结束）。
- 无人值守二选一：`--disable-approval`（留沙箱）/ `--yolo`（全去 + 信任 workspace，仅可信代码的一次性隔离容器）；`--max-model-steps` 封顶防死循环。
- CI 沙箱：Linux runner 需可用 bubblewrap 且非 musl，否则每条沙箱 shell 全灭为环境失败。
- 断点续跑：`muse exec --session-id <uuid>`；审计：`muse export --session <uuid> --out run.json`（内嵌产出它的 CLI 版本，按 hash 卡门先 pin 版本；workspace 不一致除非 `--allow-workspace-switch`）；`muse resume` 只开交互 UI，不是 headless 面。
- 可编程面：`muse serve` 跑版本化会话协议，`muse schema` 印 JSON schema，TS SDK `npm install @muse-code/sdk`。

本仓落实：CI 门 = `bash scripts/smoke.sh` + `bash scripts/verify.sh` + 触及面测试命令三件套，不看 `muse exec` 退出码放行；见 `docs/HOOKS.md`。

## 9. 本仓布局 ↔ 原生规范对照

| 本仓路径 | 原生规范 | 关系 |
|---|---|---|
| `AGENTS.md` | `muse init` 种子 + 每层四名加载 | 对齐：根项目指令，深层可覆 |
| `.agents/skills/<id>/SKILL.md` | Project skills 标准路径 | 对齐（ADR-0001 由 `.muse/skills/` 迁入）|
| `.agents/memory/` | Project memory 标准路径 | 对齐 |
| `.agents/workflows/*.js` | `muse workflows save --scope project` 落点 | 对齐 |
| `.muse/hooks.json` | Project hooks 标准路径 | 对齐（骨架，待实测补全）|
| `docs/`、`scripts/`、`src/`、`tests/` | 官方无规定 | 本仓约定（codex/cc 吸收），见 `ARCHITECTURE.md` |
| `FRAMEWORK-MANIFEST.json` | 官方无等价物 | 本仓自选（codex 吸收），安装器用 |

## 10. 未覆盖的官方页（诚实缺口，后续补）

- `interactive`（slash 命令全表、goal/loop、session 模型、`--no-session-log` 影响面）、`session-messaging`（peer 准入细节）、`rewind`、`auth`（登录计费）、`cookbook/muse-code`、`coding-agents`、`api-reference`。以上页未在本轮抓取正文，相关断言不得写入本仓规范；用到时先抓页再落字。
