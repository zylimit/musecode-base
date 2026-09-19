# Hooks 与门禁说明

> 目标：把 `AGENTS.md` §4 验证门禁落成三层防线（目标态；当前会话 hook 层未启用未验证，见下）。
> 吸收 cc-base 三层强制（C10）与退出码契约（C13）、codex 五态语义（X11）。

## 1. 三层防线（目标态；接入条件见各层"生效条件"列）

> 现状：git hook + CI 两层已接线生效；Muse 原生 hook 层只有 `.muse/hooks.json.example` 骨架，未启用、未验证——启用前"缺一不可"是目标，不是现状。需要启用时只验证一个实际需要的事件/输入/退出/重载行为，再扩展。

| 层 | 位置 | 管到哪 | 生效条件 |
|---|---|---|---|
| Muse 原生 hook | `.muse/hooks.json` | 会话内的生命周期事件（15 事件，见 `docs/MUSE-NATIVE.md` §3） | 信任 workspace + 开新会话；命令跑在**沙箱之外** |
| git hook | `.git/hooks/`（`scripts/install-githooks.sh on` 安装） | 凡走 git 的提交/推送路径，不论谁发起 | `git init` 后显式 `on`；只删带本仓标记的钩子 |
| CI | `.github/workflows/gate.yml`（示例见 §5） | 所有人、所有分支、所有机器 | 仓库托管侧配置 |

会话 hook 只管会话内：手敲 commit、别的编辑器提交、别的 Agent 提交全都绕得过去——git hook + CI 补这个缺口。

## 2. 时机表（git hook + CI 层）

| 时机 | 执行 | 阻断条件 | 可否绕过 |
|---|---|---|---|
| 每次改码后（手动 L0） | `bash scripts/smoke.sh` | 任一 FAIL | 否：先修再交 |
| `git commit`（pre-commit） | smoke + `fitness.sh --staged --paths <staged>`（查 index 字节） | FAIL/error | 否（禁 `--no-verify`，见 `AGENTS.md` §5） |
| `git push`（pre-push） | smoke + `verify.sh` | FAIL/BLOCKED | 否 |
| CI | smoke + verify + `check.sh` + `skill-lint.sh`（predev/plan/arch 本仓无对象，不接） | 同上 | 否 |

安装：`bash scripts/install-githooks.sh on|off|status`。`off` 只删带 `musecode-base managed hook` 标记的钩子，用户自有钩子不动；不碰 `core.hooksPath`。

## 3. 退出码契约（全仓脚本统一）

| 码 | 含义 | 举例 |
|---|---|---|
| 0 | 建立了结论且干净 | verify 全绿、check 无 error |
| 1 | 建立了结论且有发现 / 用法错 | fitness 有 error；`arch-check` 有违规；未知 flag |
| 2 | 门没过（阻断级） | verify FAIL/BLOCKED；check 有 error |
| 3 | 降级：什么都没建立 | 无 catalog、无 REQ/ADR、全 SKIPPED |
| 4 | STALE（预留） | 回执不绑当前 diff（本轮未实现回执文件，见缺口） |

`rc=3` 永不读作绿：pre-commit 对 3 静默放行是设计（小仓无 catalog 时不扰民），看字段与 stderr 才知道原因。

## 4. 档位与 fast 语义

档位表见 `docs/LARGE-REPO.md` §7。fast 规则：必带 reason、上限 8h、到期自回；状态 `.agents/harness-state/tier.json`（git 忽略）；改家底（`AGENTS.md`、`ARCHITECTURE.md`、`docs/**` 规范、`scripts/**`、`.agents/skills/**`、`.muse/hooks.json`）本轮自动 strict。五个地板闸（密钥外泄/危险删除/发布前置/记忆同步/通知）任何档都 block。

fast 下门照跑、红照报、只记账不拦；`release` 装配在 fast 生效时直接 FAIL。降档必须留理由，进 `gate-block.log`。

## 5. CI 接入示例（GitHub Actions 风格）

```yaml
- name: smoke gate
  run: bash scripts/smoke.sh
- name: verify gate
  run: bash scripts/verify.sh
- name: req-adr check
  run: bash scripts/check.sh
- name: arch gate
  run: bash scripts/arch-check.sh --gate
  # 只在有 catalog 且有 src/ 文件时接线；无对象不接（EMPTY_SCAN 会响亮失败，不静默绿）
```

CI 门必须挂**自己的测试命令**，不能只看 `muse exec` 退出码（exit 0 只表轮次结束，不表活干得对，见 `docs/MUSE-NATIVE.md` §8）。

## 6. 账本

`verify.sh` 的 FAIL/BLOCKED 追加到 `.agents/harness-state/gate-block.log`（一行 `<UTC>\tverify\t<reason>`，git 忽略）。写不上账吞掉不抛——账本是旁路，绝不改变判决。死闸审计脚本未实现前人工看账（见 `docs/CROSS-POLLINATION.md` §5）。

## 7. 与质检 checklist 的关系

- Hooks 管“什么时候拦”（时机 + 退出码）。
- `docs/QUALITY_CHECKLIST.md` 管“拦什么”（Resilience/Security/Safety/Privacy/Reliability 条目）。
- smoke 只做存在性/语法/泄露初检；五维 checklist 的语义项由人工 + 对应测试在 L1/L2 覆盖。

## 8. 故障排查

| 现象 | 处理 |
|---|---|
| `smoke.sh` 报文件缺失 | 按输出补文件，不要改脚本跳过检查 |
| git 钩子未触发 | `install-githooks.sh status` 查安装态；未 `git init` 时属预期，手动跑门禁 |
| 想 `--no-verify` 跳过 | 禁止（`AGENTS.md` §5）。门禁误报则修门禁并留 ADR，而非跳过 |
| 原生 hook 改了不生效 | 改配置后必须**开新会话**（官方无热重载）；畸形文件只告警且该源零 handler |
| `arch-check --gate` 无基线 | 先 `--record` 立基线；老仓带债接入同理 |
