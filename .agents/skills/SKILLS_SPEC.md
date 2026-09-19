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
- 技能间不循环依赖；通用逻辑上浮到 `src/`，技能只做编排。

## 6. 合入流程

1. 复制 `_template/SKILL.md` 到新目录并填写。
2. 跑 `bash scripts/smoke.sh` 确认存在性检查通过。
3. 有架构影响则补 ADR（`docs/adr/NNNN-<slug>.md`）。
4. 在交付说明中贴技能路径 + 验收命令输出。

## 7. 现有技能索引

| 技能 | 说明 | 状态 |
|---|---|---|
| `_template` | 模板，非可执行技能 | 常驻 |
| `code-review` | 结构化三阶段评审 + 作者≠评审 + 删除重命名单列 | 可用 |

> 新增行即注册，无需中心清单文件。
