# 大仓指南（100 万行级治理）

> 本仓靠“缩小活动范围”支撑 100 万行级项目，不靠全仓灌入上下文。吸收 codex `LARGE-REPO-GUIDE.md`（X8）与 cc `11-large-repo.md`（C6/C12–C14）。
> 与 `SCALING.md` 的分工：SCALING 定本仓脚本的扫描范围/上限/验证方法，本文件定**治理机制**（目录/影响/上下文/验证/防腐）。目标项目运行时容量自定，本仓不承诺。

## 1. 启用条件（两步）

1. 在 `.agents/harness/` 放一份过 lint 的 `module-catalog.json`（schema 见 §2，示例见 `.agents/harness/module-catalog.example.json`）。
2. 跑 `bash scripts/arch-check.sh` 确认声明图干净（或已 `--record` 立基线）。

文件存在即启用定向验证与防腐检查；删掉即关闭，小仓零负担。无 catalog 时各脚本统一 rc=3（降级：未建立结论，不是绿）。

## 2. module-catalog.json schema（最小闭集）

```json
{
  "version": 1,
  "layers": ["app", "domain", "infra"],
  "global": ["package.json", "tsconfig.json"],
  "ignored": ["README.md", "docs/**"],
  "modules": [
    {
      "id": "billing",
      "paths": ["src/billing/**"],
      "dependsOn": ["ledger"],
      "forbiddenDependencies": ["analytics"],
      "layer": "domain",
      "riskTier": "high",
      "attributes": { "security": "critical", "privacy": "high", "reliability": "high" },
      "verification": ["unit-billing", "sec-scan"]
    }
  ],
  "checks": {
    "unit-billing": { "command": "pytest tests/billing -q", "attributes": ["reliability"] },
    "sec-scan": { "command": "semgrep scan --error --config auto src/billing", "class": "security", "attributes": ["security"] }
  },
  "contextPack": { "maxTotalChars": 120000, "maxFiles": 40, "maxFileChars": 6000, "maxDiffChars": 40000 }
}
```

- `paths` 禁 `''/'.'/'*'/'**'/'**/*'`（CATCH_ALL）；命中多模块按 glob 字面最长者胜。
- 分类优先级：module > ignored > global > unmapped。
- `riskTier`：low/medium/high；`attributes` 四档 critical/high/medium/low（X5 简化版）。
- `class` 为 security/safety/privacy 的 check 永不可豁免、不可 fast 跳过。

`arch-check.sh` 校验码：`CATALOG_PARSE` / `BAD_ID` / `DUPLICATE_ID` / `CATCH_ALL` / `OVERLAP` / `DANGLING_DEP` / `SELF_DEP` / `SELF_FORBIDDEN` / `FORBIDDEN_DECLARED` / `UNKNOWN_LAYER` / `UNKNOWN_ATTRIBUTE` / `UNKNOWN_TIER` / `UNJUSTIFIED_TIER` / `CYCLE` / `FORBIDDEN_EDGE` / `UNDECLARED_EDGE` / `LAYER_VIOLATION` / `NEW_EDGE` / `TREND_NO_BASELINE` / `TREND_BASELINE_CORRUPT` 均为 error；`TRUNCATED`/`REGEX_FALLBACK`/`DYNAMIC`/`RELATIVE_*`/`PYAST`/`UNREADABLE` 为 partial-warn（`--gate` 下任一 partial 即 fail，不静默漏项）。

## 3. 固定顺序（铁律）

```text
catalog lint → affected/反向依赖闭包 → task baseline → context pack → 定向实现 → verification plan/gate → review/test 证据 → complete
```

- changed path 先归入最深模块，再沿 `dependsOn` 反向找 consumers。
- shared/global/unmapped/overlap/truncated/非 git 一律**保守全 fanout + degraded:true**：宁可全跑，不可漏测。
- Context Pack 只收 task、Spec/Plan 指针、当前 diff、changed file、capsule、public contract、依赖/消费者与 tests；超预算拆 Task，不塞全目录；密钥路径永不入包。
- candidate 顺序（changed static → module unit → consumer contract → broader build/security/smoke）只定候选，**实际跑什么服从 verification plan**，不另写一套风险阈值。

## 4. Ownership（写隔离）

- 共享 checkout 默认**单 writer**。schema/migration/lockfile/根配置/生成物/公共 manifest 视为重叠 ownership。
- 并行写三件套缺一不可：owned paths 完全 disjoint + 独立 worktree（Muse 原生隔离，拒绝永不静默回落）+ 指定 integration owner。
- 读重工作可并行（审查维度/探索/批量验）；写重默认串行。fan-out 到 workflow/subagent 规模需用户显式 opt-in（token 约 15x，Anthropic 实证，转引自 cc 文档）。

## 5. 验证门（四态 + 属性门）

> 人工执行语义：verification plan/档位/豁免当前无机器引擎消费（`verify.sh`/`check.sh`/git hooks/CI 均不读 tier 状态，已核），由执行人按本表操作。机器只校验声明文件格式（`arch-check.sh`）与 git hooks/CI 固定门禁。不为此补第二个 Assurance 引擎（见 `progress.md` D2）。

单 check 四态：`PASS`（exit 0）/ `FAIL`（exit 非零）/ `BLOCKED`（缺 command/缺二进制）/ `SKIPPED`（有效 waiver 或 fast 档非保护 check）。聚合：任一 FAIL → FAIL；任一 BLOCKED → BLOCKED；**空计划 = BLOCKED**（`emptyPlan`，配置缺口必须可见）；全 SKIPPED → rc=3。

属性门（X5）：受影响模块的 critical/high 属性必须有 PASS 的认领 check；**反证优先**（同属性一 PASS 一 FAIL = 未覆盖）；SKIPPED 不覆盖不反证；缺口 → `BLOCKED_BY_ATTRIBUTES` rc=2。

豁免（waiver）：per-check，owner/reason/scope/expiry 必填；security/safety/privacy 类永不可豁；属性缺口仅 high 可推迟、critical 不行；reason 命中 `safety|security|privacy|pii|secret|credential|destructive|push|deploy|production` 即拒。

## 6. 防腐（arch-check + adr-check + trend 棘轮）

- `arch-check.sh`：声明图校验 + JS/TS/Python 静态 import 实边对照，报越禁边/分层违规（只许同层或向内）/未声明边（漂移 = impact 漏测）/虚边/环。声明与禁令冲突时**禁令赢**。
- `arch-check.sh --record` 快照边身份集合到 `.agents/harness/arch-baseline.json`（**随仓提交**，用 git 管基线，不用运行态 jsonl）；`--gate` 按边身份比对，新边即 fail；`forbidden` 边永不可入 baseline。老仓接入：先 record 立基线并提交，旧债慢慢还、新债一分不许添。
- `check.sh` 的 adr-check：活跃 ADR 的 Enforced-by 必须指向真实 check id / fitness 规则 / harness 能力名或显式 `manual:`；幽灵引用 fail，缺失 warning。

## 7. 档位表（fast/standard/strict）

| 闸 | fast | standard | strict |
|---|---|---|---|
| 定向 verify（`verify.sh`） | advise（跑但只记账） | block | block |
| 三件套检查（`check.sh`） | advise | block（提交前） | block |
| arch/fitness | advise | block（提交前） | block |
| 密钥外泄/危险删除/发布前置/记忆同步/通知 | block | block | block（floor，不在表内） |

- fast 必带 reason、上限 8h、到期自回默认档；状态 `.agents/harness-state/tier.json`（git 忽略）。档位是建议（人工执行），无机器强制。
- 改家底（`.agents/skills/**`、`.agents/parts/**`、`.muse/hooks.json`、`scripts/**`、`AGENTS.md`、`ARCHITECTURE.md`、`docs/**` 规范）本轮建议 strict——只是 `tier.sh status` 的显示规则（raise），提交后回落显示。升档不需批，降档要 reason 并记账（人工记）。
- 档位只调工程门强度，**不改** Muse approval/sandbox/模型三轴（X1）。

## 8. 派单契约（多智能体）

每个 writer/审查派单必须包含：Goal / Scope / Out-of-Scope / Existing-Pattern / Business-Context（目标/规则/例子/未决项，可选）/ Verification / Escalation。交接六段：Status / Changed / Verified / Not-verified / Needs-review-by / Evidence。

回传只带结论 + 证据句柄（文件 path:line、命令输出摘要），下判断留主 Agent。BLOCKED 升级树：补上下文 → 换强角色 → 拆小 → 上报；禁同配置无变化重试。
