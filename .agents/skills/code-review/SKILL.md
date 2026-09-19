# code-review

- 版本：1.0.0
- 适用：合并/交付前对当前变更做结构化评审；高风险变更强制走。不适用：纯文档改字（走直推档）。
- 输入：变更范围（`git diff --stat` 输出）、关联需求 `docs/REQ-*.md`、触及模块的 catalog 条目（如有）。
- 输出：评审报告（含 P0/P1/P2 findings，每条带 `path:line` 或复现路径）+ 明确 verdict（APPROVE / FIX_REQUIRED / ESCALATE）。

## 步骤

1. 取范围：`git diff --stat` + `git diff` 确认评审对象；删除与重命名单独成节先看（系统性漏看区）。
2. Stage code（architecture/maintainability/performance）：对照 `ARCHITECTURE.md` 红线与 catalog 声明图。
3. Stage functional（correctness/testing/reliability）：从需求承诺追真实结果；测试锁定是否覆盖触及面。
4. Stage trust（security/safety/privacy/resilience）：对照 `docs/QUALITY_CHECKLIST.md` SEC/SAF/PRI/RES 节。
5. 作者检查：评审者不得是作者（`git log` 作者集比对）；自审一律拒收。
6. 裁决：任一 error 级 finding 即 FIX_REQUIRED，不被干净 lens 投票稀释；连续 FIX_REQUIRED 达 3 轮则 ESCALATE 交人。

## 约束与红线

- 只读评审：除评审报告外不写业务文件（`AGENTS.md` §3 最小改动）。
- finding 无 `path:line`/复现路径即无效 finding（`ARCHITECTURE.md` 红线 3 可验证性）。
- 风格偏好/nit 不阻断；medium/low 不仅凭级别要求再审。

## 验收

- 报告含 verdict + findings（含级别/证据/复现）+ Not-verified（范围外/未运行项）。
- 高风险变更：`bash scripts/verify.sh` 与 `bash scripts/check.sh` 均已跑过，结果写入报告。

## 示例

```bash
git diff --stat
# 按 §步骤 2–4 逐阶段出 findings，最后给 verdict
```
