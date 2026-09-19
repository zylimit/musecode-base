# Skills 规范（本仓约定）

> 落点：`.agents/skills/`（Muse 官方 Project skills 路径，见 `docs/MUSE-NATIVE.md` §2；原 `.muse/skills/` 违规，已由 ADR-0001 迁走）。
> 与 `ARCHITECTURE.md` §2 模块边界对齐：技能只放可复用能力说明与轻量脚本，不放密钥与大二进制。

## 1. 目录约定

```text
.agents/skills/
  SKILLS_SPEC.md          # 本文件（规范）
  _template/SKILL.md      # 新技能模板（复制改名即用）
  <skill-name>/SKILL.md   # 每个技能一个目录，入口固定为 SKILL.md
  <skill-name>/scripts/   # 可选：技能私有脚本（只被该技能引用）
  <skill-name>/references.md  # 可选：背景资料索引（链到 docs/ 或具名外部源）
```

官方四源对照：Built-in（随包）/ User（`~/.agents/skills` 等）/ Project（本目录）/ Plugin。
管理命令：`muse skills list|inspect|enable|install|validate`，跨 agent 导入 `muse skills import --from claude|codex`。

## 2. 命名与版本

- 目录名：小写 kebab-case，动词或动宾结构，如 `verify-gate`、`adr-review`。
- `SKILL.md` 头部必须声明：名称、版本（semver 三段）、适用范围、输入/输出。
- 破坏性变更必须升 major 并在 `docs/adr/` 留 ADR。

## 3. SKILL.md 结构（必选节）

```markdown
# <skill-name>

- 版本：x.y.z
- 适用：何时用 / 何时不用
- 输入：需要什么上下文
- 输出：产出什么文件或结论

## 步骤
## 约束与红线
## 验收
## 示例
```

- 步骤 ≤ 7 步，每步可独立验证。
- 约束节必须引用 `AGENTS.md`/`ARCHITECTURE.md` 相关条款编号。
- 验收节必须可执行（命令 + 期望退出码/输出）。

## 4. 权限与安全

- 默认只读；需写文件/执行命令时，在“输入”节声明最小路径与命令白名单。
- 禁止项（与 `AGENTS.md` §5 一致）：不读 `.secrets`/grader 私域，不做全盘扫描，不杀用户进程。
- 需网络时声明域名白名单与超时/重试策略。

## 5. 质量门槛

- 新增技能必须：`bash -n` 过（若含脚本）、被 `scripts/smoke.sh` 存在性检查覆盖、写一条验收命令。
- 技能间不循环依赖；通用逻辑上浮到 `scripts/`（本仓无 `src/`），技能只做编排。

## 6. 合入流程（创建机制归原生，本节只留本仓约定）

创建 skill 的机制（scope/安全位/校验）走原生 `create-skill`（用户显式要求建 skill 时触发），不要自写第二套。本仓只加三条项目约定：

1. 结构按 §3（版本/适用/输入/输出/步骤≤7/约束/验收/示例）填 `_template/SKILL.md` 骨架；description 只写触发条件。
2. 大改先做新旧对照：2–3 个代表性场景，只给当轮输入不预给期望；只有原版真失败且改版同断言通过才称改进。
3. 落盘后跑 `bash scripts/smoke.sh` + `bash scripts/skill-lint.sh`，SPEC §7 加索引行；有架构影响补 ADR；在交付说明中贴技能路径 + 验收命令输出。

## 7. 现有技能索引（三选一判定 + 退役条件）

判定依据：逐个读过 built-in body（`plan`/`grill`/`requirements-clarification`/`taste`/`create-skill`/`git`/`durable-test-collateral` 均已实际加载比对）+ CLI 实测（`skills list/install/import`、`--agents`、plugins 面）。原生 `plan`/`grill`/clarification 均为显式触发（任务本身不触发），这是 ① 少的的结构原因；observer 无可调用面，不能作为覆盖依据。

| 技能 | 判定 | 原生映射/保留理由 | 退役条件 |
|---|---|---|---|
| `product-spec-builder` | ②留半 | 通用追问归 `grill`；留 REQ 机器（判档/四标记/收敛+check/复述/CHANGELOG） | REQ 模板+check 闸被原生需求流取代时删 |
| `arch-designer` | ③留 | `plan` 只管计划形态与审批不管架构方法；留 S/M/L+事实归属+ADR/catalog 接线 | 连续 3 个架构任务无人触发时删 |
| `dfx-designer` | ③留 | 无原生 SLO/质量目标能力 | 同上（计数对象换 DFX 任务） |
| `design-brief-builder` | ③留 | `taste` 只管创作时否决不管风格发现；`grill` 不懂视觉轴 | 同上 |
| `design-maker` | ②留半 | 通病否决归 `taste`；留两遍法/离线稿/客观验收/样张/分层交付 | 同上 |
| `dev-planner` | ②留半 | 计划形态与审批闸归 `plan`；留切片/反推四问/disjoint+owner/spike/PLAN 落盘 | 同上 |
| `dev-builder` | ③留 | TDD/Phase 执行法无原生对应（`durable-test-collateral` 仅一条规则） | 本仓改用其他实现流程时删 |
| `bug-fixer` | ③留 | 调试执行法无原生对应（`plan` 的 debug 型只是计划形态） | 同上 |
| `code-review` | ③留 | 无原生评审 skill；observer 不可调用不作数 | 同上 |
| `test-builder` | ③留 | 全套测试方法无原生对应 | 同上 |
| `red-blue-review` | ③留 | 对抗仪式+evidence.sh，与 code-review 触发不同 | 一年无发版前对抗审查时删 |
| `release-builder` | ③留 | 无原生发布能力 | 同上（计数对象换发布任务） |
| `branch-finisher` | ③留 | 内置 `git` 只管安全规则不管收尾流程 | 同上（计数对象换收尾任务） |
| `large-repo-harness` | ③留 | 无原生对应 | 连续 3 个大仓任务无人触发时删，留 LARGE-REPO.md |
| `feedback-writer` | ③留 | 无原生教训采集能力；动词已按平台改为补丁式回执 | 有原生 lesson 采集时删 |
| `evolution-engine` | ③留 | 只读提议（恰为本平台答案形态）；输入是读操作 | feedback 为空满一季时删 |
| `progress-recorder` | ③留 | 写 progress.md（仓根可写区）；原生 memory 是另一系统 | progress.md 停用时删 |
| `domain-rulings` | ③留 | 无原生口径库能力；写 domain/（仓根可写区） | 口径库空满一季时删 |
| `skill-builder` | ③留 | 新建/大改 skill 的交互模式参照+场景对照+来源清单；原生 `create-skill` 只管脚手架不管本仓 §6 落盘口径 | 本仓 skill 零新增满一季时删 |

> 新增行即注册，无需中心清单文件。
