---
name: code-review
description: 当一批改动完成、合并/发版前需要结构化审查时使用。三阶段九 lens，结论必须落到 file:line。
---

# code-review

- 版本：2.0.0
- 适用：合并/发版前的改动审查；高风险变更强制走。不适用：纯文档改字（直推）、需对抗深度的发版闸（走 red-blue-review）。
- 输入：变更范围（`git diff` / commit 区间）+ 关联 REQ + catalog 条目（如有）。
- 输出：评审报告（P0/P1/P2 findings + verdict：APPROVE / FIX_REQUIRED / ESCALATE）。

## 步骤

1. 取范围：`git diff --stat` + 全 diff 确认评审对象；**删除与重命名单独成节先看**；无改动直接回"无可审范围"。
2. Stage 0 静态先行：先消费实现冻结的 verify/fitness 证据（核对 `AGENTS.md` §4.6 代码指纹）；缺证据或指纹对不上才重跑，且只跑受影响部分。静态红则直接 FIX_REQUIRED。
3. Stage code → functional → trust：按三阶段九 lens 过（架构红线/catalog、需求承诺追真实结果、SEC/SAF/PRI/RES）；finding 无 `path:line`/复现路径即无效。
4. 四态输出：✅ 通过 / ⚠️ 可修可不修（不阻断）/ ❌ 必须修 / ❓ 存疑（回流需求，不猜）；任一 error 即 FIX_REQUIRED，不被干净 lens 投票稀释。
5. 修复路由：静态缺失→implementer 补；质量问题→dev-builder；缺陷/安全→bug-fixer；需求存疑→product-spec-builder。
6. 同一轮复核：HIGH 改动的 FIX 由同一 reviewer 再看一次（只看修复点）；连续 FIX_REQUIRED 达 3 轮则 ESCALATE。
7. 报告：verdict + findings（级别/证据/复现/修复建议）+ Not-verified；高风险变更附 verify/check 冻结证据（消费实现侧的，代码变了才重跑受影响面）。

## 约束与红线

- 只读评审：除报告外不写业务文件（`AGENTS.md` §3 最小改动）。
- 作者≠评审（本地隔离依据，非身份认证）：评审子任务不得与实现子任务是同一个 run；会话内用 run 身份 + 作者声明区分。`git log` 作者集只能看已提交作者——多角色可共用同一 Git 身份、未提交变更没有 commit author，所以 Git 比对只是辅助信号，不能宣传成"机器已强制"，更不引入签名账本。自报是作者的评审拒收。
- 风格偏好/nit 不阻断；medium/low 不仅凭级别要求再审。
- 审查 diff 绑定：diff 变一字节结论即 stale，须重审（不可拿旧报告为新 diff 背书）。

## 验收

- 每条 finding 有 file:line 或复现路径；删除/重命名已单列审计。
- 报告含明确 verdict；FIX_REQUIRED 有须修清单。

## 示例

审"支付回调重试"改动：Stage trust 发现"重试无幂等键"（P0，`src/pay/notify.py:88`）→ FIX_REQUIRED；另 nit"日志级别"不阻断。

## Donor 出处

- `cc-base/.claude/skills/code-review/SKILL.md`（三阶段九 lens、删除单列、连续 FIX 上报）
- `codex-base/.agents/skills/code-review/SKILL.md`（证据绑定、diff-bound、裁决规则）
