---
name: dev-builder
description: 当开发计划已定、要按 Phase 写代码实现功能时使用。一次只做一个 Phase。
---

# dev-builder

- 版本：1.0.0
- 适用：计划内 Phase 的编码实现。不适用：无计划的探索、无验收的"先写着看"。
- 输入：Phase 定义（目标/范围/验收）+ 相关 REQ/ADR + 现有代码与测试。
- 输出：Phase 代码 + 同步测试 + Phase 完成报告（变更/验证/未验证）。

## 步骤

1. 开工：读 Phase 定义 + REQ 相关条 + ADR；`git status` 确认工作区干净；检索被改符号的**全部调用方**与现有测试，推导真实契约。
2. TDD：先写失败测试（红），再写最小实现（绿），再重构；红测必须红在预期原因上。测试与实现禁止同一视角自证——测试断言来自需求，不是复述实现。
3. 最小改动：只做 Phase 范围内的事；修根因不修症状；不顺手重构、不新增静默 fallback；公共契约/迁移/依赖变化先取授权。
4. 每步验证：改完即跑触及面测试 + `bash scripts/smoke.sh`；红了先修再往下走，不攒红。
5. Phase 完成度自判：验收命令逐条跑过（贴输出）→ 跑 `bash scripts/verify.sh` → 跑 `bash scripts/check.sh` → 更新 `progress.md` Done（附证据指针）。
6. 大批量改造收口：重复代码扫描（新增重复块清单）、死代码清理、注释与文档同步，三件做完才算收口。
7. 交接：报告变更文件、验证命令与输出摘要、未验证项与风险；需独立审查/测试的显式声明。

## 约束与红线

- 同一未改码窗口内同一校验只跑一次；自写脚本只是探针，结论须有独立 oracle（`AGENTS.md` §4）。
- 禁止为过测试而弱化正确代码；禁止 `--skip/--force/--no-verify` 绕门禁（`AGENTS.md` §5）。
- 错误/边界/负例与 happy path 同等覆盖；成对边界同一约定。

## 验收

- Phase 验收命令全绿且输出已贴；verify/check 通过；测试与实现同目录锁定。
- `git diff` 只含 Phase 范围内改动，无附带文件（装完依赖查 `git status` 回滚附带）。

## 任务三档（机械判据，不凭感觉）

| 档 | 判据 | 审查/测试 |
|---|---|---|
| LOW | ≤50 行，单文件，非公共契约 | 作者自测 + smoke |
| MEDIUM | ≤300 行，或跨 2–3 文件，或动公共函数 | 独立 code-review 一次 |
| HIGH | >300 行，或 schema/迁移/公共契约/安全相关 | code-review + 独立 tester 双人 |

单任务预算：LOW/MEDIUM 6 步内；HIGH 先拆，拆不动报主 Agent。超 60 分钟无进展→停下来重切分。

## 新项目初始化（无代码时先搭架子）

技术栈表 → `git init` + `.gitignore` → 目录骨架 → 空套件跑通（test-scaffold）→ 首个 Phase 开工。
初始化本身是一个 Phase，有验收（`smoke.sh` 绿 + 套件 alive）。

## 四步走（每 Phase 收口）

实现 → 自测（触及面全跑）→ 审查（按三档）→ Done（证据贴 progress）。收口期加扫：重复块清单、死代码清理、注释文档同步。

## 示例

P2 派单核心流：先写"建单→派单→接单"失败测试 → 最小实现 → 边界（空单/重复派/并发抢单）补测试 → verify 全绿 → Done 附 `pytest tests/dispatch -q` 输出。

## Donor 出处

- `cc-base/.claude/skills/dev-builder/SKILL.md`（四步走、TDD 闸、收口期扫描）
- `codex-base/.agents/skills/dev-builder/SKILL.md`（契约推导、最小改动、证据绑定）
