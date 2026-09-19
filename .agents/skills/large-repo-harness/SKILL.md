---
name: large-repo-harness
description: 当仓库规模大、跨模块、上下文易失控，或需配置 catalog、影响分析与定向验证时使用。
---

# large-repo-harness

- 版本：1.0.0
- 适用：大仓接入治理（catalog/影响/防腐/定向验证）。小仓（无 catalog）不启用本 skill。
- 输入：仓库现状 + 变更范围。
- 输出：catalog 配置 / 影响结论 / 定向验证计划 / 防腐基线。

## 步骤

1. 接入：复制 `.agents/harness/module-catalog.example.json` 为 `module-catalog.json` 按实填写；跑 `bash scripts/arch-check.sh` 至声明图干净；老仓 `--record` 立基线（环/禁边/保护层反向永不可入 baseline）。
2. 切片：每 Task 一个可独立验收的行为切片；schema/迁移/lockfile/生成物/根配置视为共享 ownership；共享 checkout 默认单 writer；并行写须 disjoint + 独立 worktree + integration owner。
3. 影响：changed path 归入最深模块，沿 dependsOn 反向扩到消费者；shared/global/unmapped/overlap/截断一律保守全扩 + 标记 degraded；删文件/非 git/无效基线明确降级，不伪造精确影响。
4. 上下文预算：只给 Task 所需（任务+Spec 指针+diff+契约+capsule）；超预算拆 Task；密钥/私密永不入包；缺 contract/capsule 记 omission，不拿全目录源码补洞。
5. 定向验证：顺序 changed 静态 → 模块单测 → 消费者契约 → 更广构建/安全/冒烟；空计划 = BLOCKED；受影响模块的 critical/high 属性须有 PASS 认领（反证优先：同属性一 PASS 一 FAIL = 未覆盖）。
6. 防腐：`arch-check.sh --scan/--gate`（未声明边=漂移=影响漏算，须补声明或修代码）；`check.sh` 的 adr-check（Enforced-by 幽灵引用 fail）；新边零容忍。
7. 派单：Goal/Scope/Out-of-Scope/Existing-Pattern/Verification/Escalation + 交接六段；回传只带结论与证据句柄；BLOCKED 升级树：补上下文→换强角色→拆小→上报。

## 约束与红线

- 靠缩小活动范围治大仓，不靠全仓灌入上下文（`docs/LARGE-REPO.md`）。
- 并行 fan-out 到 workflow/subagent 规模须用户显式 opt-in（`docs/MUSE-NATIVE.md` §5）。
- 档位只调工程门强度，不改 approval/sandbox/模型三轴。

## 验收

- catalog lint 干净；影响结论有模块清单与保守声明；验证计划非空且按序执行有输出。
- 防腐门：无新边、无幽灵引用，或缺口已显式 BLOCKED。

## 示例

改 `src/billing/`：归入 billing 模块 → 反向扩到 quote/notifier 消费者 → 验证跑 billing 单测 + 消费者契约 → arch-gate 无新边 → 放行。

## Donor 出处

- `codex-base/.agents/skills/large-repo-harness/SKILL.md`（全文：onboarding/切片/影响/pack/预算/经济学/压力场景）
- 本仓：`docs/LARGE-REPO.md`、`.agents/harness/module-catalog.example.json`
