# musecode-base

给 Muse Code 用的可复用工程脚手架：skills + 门禁脚本 + 文档模板，随仓分发、按需裁剪。

## 定位

- 本仓是脚手架，不是运行时：会话/调度/沙箱/记忆运行时归 Muse 本体，本仓只给可复用的工程纪律与检查工具。
- 约定优先于配置：代理行为以 `AGENTS.md` 为准，架构红线以 `ARCHITECTURE.md` 为准。
- 可复用 harness 能力见 `HARNESS.md`（注明 codex / cc 出处）。

## 目录

| 路径 | 说明 |
|---|---|
| `AGENTS.md` | 代理工作协议（原厂规范本地化） |
| `ARCHITECTURE.md` | 架构看护：原则、边界、变更门禁 |
| `HARNESS.md` | harness 复用清单与出处 |
| `docs/REQUIREMENTS_TEMPLATE.md` | 需求模板（+ `REQUIREMENTS_GUIDE.md` 四标记/收敛/复述） |
| `docs/ADR_TEMPLATE.md` | ADR 模板 |
| `docs/adr/` | 已采纳 ADR（`NNNN-标题.md`） |
| `docs/LARGE-REPO.md` | 100 万行治理：catalog/影响/防腐/档位 |
| `docs/CROSS-POLLINATION.md` | codex/cc 吸收台账与拒绝清单 |
| `docs/MEMORY_GUIDE.md` | 四记忆系统分工与保留销毁 |
| `docs/QUALITY_CHECKLIST.md` | 五维质检（Resilience/Security/Safety/Privacy/Reliability） |
| `tests/` | 脚手架契约测试 + 行为探针 |
| `scripts/` | 本地校验与运维脚本（smoke/verify/check/fitness/arch-check） |
| `.agents/skills/` | 项目技能（官方路径，见 SKILLS_SPEC） |
| `.agents/memory/` | 项目记忆（`MEMORY.md` 索引） |
| `.agents/workflows/` | 可复用 workflow 脚本 |
| `.muse/hooks.json` | 项目 hooks 声明（跑在沙箱之外） |
| `docs/MUSE-NATIVE.md` | Muse 原生能力映射与合规红线 |

## 快速开始

```bash
# 1. 读协议
cat AGENTS.md ARCHITECTURE.md HARNESS.md

# 2. 新需求：复制模板
cp docs/REQUIREMENTS_TEMPLATE.md docs/REQ-<slug>.md
cp docs/ADR_TEMPLATE.md docs/adr/0001-<slug>.md

# 3. 本地校验（按序，见 docs/HOOKS.md 退出码契约）
bash scripts/smoke.sh && bash scripts/verify.sh && bash scripts/check.sh
```

## 工作流（最小闭环）

1. 领需求：用需求模板建 `docs/REQ-*.md`，明确验收标准。
2. 定方案：有架构影响则写 ADR，落到 `docs/adr/`。
3. 改代码：小步修改，同步更新测试。
4. 跑验证：先跑触及面的单测，再按序跑 smoke → verify → check（+ arch-check，如有 catalog）。
5. 交交付：说明变更文件、验证命令与结果。

## 规范

- 语言：中文沟通，代码注释 concise English/中文均可，禁止长链式思考写入注释。
- 提交：只提交任务相关文件，不顺手重构无关代码。
- 验证：改动必须有对应测试证据；禁止为过测试而弱化正确代码。
