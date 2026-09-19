# Skills 规范（本仓约定）

> 落点：`.agents/skills/`（Muse 官方 Project skills 路径，见 `docs/MUSE-NATIVE.md` §2；原 `.muse/skills/` 违规，已由 ADR-0001 迁走）。
> 与 `ARCHITECTURE.md` §2 模块边界对齐：技能只放可复用能力说明与轻量脚本，不放密钥与大二进制。

## 1. 目录约定

```text
.agents/skills/
  SKILLS_SPEC.md          # 本文件（规范）
  <skill-name>/SKILL.md   # 每个技能一个目录，入口固定为 SKILL.md
  <skill-name>/scripts/   # 可选：技能私有脚本（只被该技能引用）
  <skill-name>/references.md  # 可选：背景资料索引（链到 docs/ 或具名外部源）
.agents/parts/            # 零件库：下架技能 + _template（不装机、不触发，按需取用）
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

1. 结构按 §3（版本/适用/输入/输出/步骤≤7/约束/验收/示例）填 `.agents/parts/_template/SKILL.md` 骨架；description 只写触发条件。
2. 大改先做新旧对照：2–3 个代表性场景，只给当轮输入不预给期望；只有原版真失败且改版同断言通过才称改进。
3. 落盘后跑 `bash scripts/smoke.sh` + `bash scripts/skill-lint.sh`，SPEC §7 加索引行；有架构影响补 ADR；在交付说明中贴技能路径 + 验收命令输出。

## 7. 装机技能索引（Fable #2，2026-09-19：只留需求→开发→审查一条线）

| 技能 | 原生映射/保留理由 | 退役条件 |
|---|---|---|
| `product-spec-builder` | 通用追问归 `grill`；留 REQ 机器（判档/四标记/收敛+check/复述/CHANGELOG） | REQ 模板+check 闸被原生需求流取代时删 |
| `dev-builder` | TDD/Phase 执行法无原生对应（`durable-test-collateral` 仅一条规则） | 本仓改用其他实现流程时删 |
| `code-review` | 无原生评审 skill；observer 不可调用不作数 | 同上 |

零件库（`.agents/parts/`，不装机、不触发，按需取用；三选一判定原文见 git 历史）：`arch-designer`、`dfx-designer`、`design-brief-builder`、`design-maker`、`dev-planner`、`bug-fixer`、`test-builder`、`red-blue-review`、`release-builder`、`branch-finisher`、`large-repo-harness`、`feedback-writer`、`evolution-engine`、`progress-recorder`、`domain-rulings`、`_template`。

已删：`skill-builder`（原生 `create-skill` 全覆盖机制；项目残余并入 §6）。

> 新增行即注册，无需中心清单文件。
