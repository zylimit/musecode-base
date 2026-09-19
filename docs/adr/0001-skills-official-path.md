# ADR-0001：项目 skills 落 `.agents/skills/`（对齐 Muse 原生 Project skills 路径）

- 编号：ADR-0001
- 标题：项目 skills 落 `.agents/skills/`，废弃 `.muse/skills/`
- 状态：accepted
- 日期：2026-09-19
- 关联需求：`docs/MUSE-NATIVE.md` §2
- 关联 ADR：无

## 背景

脚手架初版把项目 skills 放在 `.muse/skills/`。2026-09-19 抓取 Muse 官方文档（[Extending and automating](https://dev.meta.ai/docs/muse-code/extending) §Skills）确认：Project skills 标准路径是 `<repo>/.agents/skills/<skill-id>/SKILL.md`（另扫描 `.codex/skills`、`.claude/skills`）；`.muse/` 下只有 `hooks.json` 是项目级标准路径。初版布局在官方 skill 发现机制下不可见，属合规缺陷。

## 决策

项目 skills 唯一落点为 `.agents/skills/<id>/SKILL.md`；`.muse/` 只保留 `hooks.json`；`AGENTS.md`/`ARCHITECTURE.md`/`README.md`/`scripts/smoke.sh` 同步改路径；`smoke.sh` 目录检查追加 `.agents/memory`、`.agents/workflows`。

## 备选项

| 选项 | 优点 | 缺点 | 拒绝理由 |
|---|---|---|---|
| A（选定）`.agents/skills/` | 官方原生发现；与 memory/workflows 同根 | 需一次性迁移引用 | — |
| B 双写兼容（两处各一份） | 零迁移 | 双真相源，迟早漂移；`.muse/` 仍违规 | 拒绝：漂移成本 > 迁移成本 |
| C 留 `.muse/skills/` 并自建发现 | 不动 | 与官方 CLI（`muse skills list`）脱节，自造标准 | 拒绝：违反“最大程度符合原厂规范” |

## 后果

- 正面：`muse skills list` 可见；与 memory/workflows 布局统一；合规红线闭合。
- 负面：旧引用（文档/脚本/外部链接）需同步改，已在本 ADR 实施中改完。
- 回滚：`git mv .agents/skills .muse/skills` + 回退引用提交；单提交可逆。

## 实施

- [x] 代码变更：目录迁移 + 5 处引用更新（`ARCHITECTURE.md`、`README.md`、`SKILLS_SPEC.md`、`smoke.sh`、`SMOKE.md`）。
- [x] 测试变更：`bash scripts/smoke.sh` 全绿（PASS=29 FAIL=0）。
- [ ] 门禁/脚本变更：`scripts/check.sh` 落地后加“禁 `.muse/skills/` 重生”检查。
- [x] 文档变更：`docs/MUSE-NATIVE.md` §2/§9 记录对照。

## 执法方式

Enforced-by: `scripts/smoke.sh`（存在性检查绑定 `.agents/skills/` 路径）。

## Revisit-if

官方变更 Project skills 路径（以 `dev.meta.ai/docs/muse-code/extending` 为准）时复评。

## Reversal

单向门：否。回滚步骤见“回滚”，代价 < 30 分钟。
