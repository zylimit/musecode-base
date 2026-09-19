---
name: red-blue-review
description: 当要对一批改动做发版前/合并前对抗审查，或用户说红蓝审查、对抗审查时使用。Blue自证→Red攻击→Judge裁定。
---

# red-blue-review

- 版本：1.0.0
- 适用：发版/合并前的对抗闸。比 code-review 更对抗（红队默认证伪），比 workflow fanout 省（串行三遍）。
- 输入：改动范围（默认最近 tag..HEAD；`--working` 审未提交工作树）+ REQ/计划（如有）。
- 输出：审查报告（ACCEPT / FIX_REQUIRED / NEEDS_MORE_EVIDENCE），落 `/tmp` per-review 副本。

## 步骤

1. 拷报告模板、凑证据包：`bash .agents/skills/red-blue-review/scripts/evidence.sh [BASE] [HEAD|--working]`，拿到范围/改动清单/删除审计/新文件/完整 diff。脚本失败响亮报错，不产空包。
2. Blue 自证（摆靶子，不作数）：实现者逐条自证改了什么/验证了什么/证据在哪，写入报告副本；自述不免除任何一条的 Red 攻击。
3. Red 攻击（fresh 视角，四 lens 默认想推翻）：correctness（逻辑/边界/与 Spec 矛盾）、security（注入/越权/泄露/破坏性操作）、release（打包/版本/回滚/隐私残留）、platform（Windows 真机：PowerShell/路径/CRLF/编码）。每条 finding 必须附 file:line 或复现路径，否则不算。
4. Judge 裁定（主 Agent，不派人）：逐条采信（证据成立→须修）/驳回（证据不足→写明理由降级）；证据不够判 NEEDS_MORE_EVIDENCE，不替任何一方圆场。
5. 结论三态：ACCEPT 放行；FIX_REQUIRED 列清单（file:line + 修复建议）→ 修完重跑本流程；NEEDS_MORE_EVIDENCE 指明缺什么 → 补了重判。
6. 领域线索回收：Red 攻出来"原来这个域是这样的"类发现，不按缺陷驳回，转 domain-rulings 分诊入口。
7. 报告归档：副本路径与结论进 `progress.md` Notes；FIX 清单进 TODO。

## 约束与红线

- 自述不作数、Judge 只看证据（`ARCHITECTURE.md` 红线 3 可验证性）。
- 模板永保空：skill 目录内模板不就地填，每次拷副本（防污染模板）。
- 驳回须写理由；"挑不出"须是真挑过之后才成立，不凑数。

## 验收

- 报告含三遍记录 + 逐条裁定 + 三态结论；FIX_REQUIRED 每条可定位、可复现。
- 证据包与结论绑定同一 diff；diff 变化结论 stale。

## 示例

审"支付网关切换"：Blue 自证 12 条 → Red 在 release lens 攻出"回滚需手动切 DNS，无演练"（P0，有复现路径）→ Judge 采信 → FIX_REQUIRED。

## Donor 出处

- `cc-base/.claude/skills/red-blue-review/SKILL.md`（全文：三遍/四 lens/证据包/模板副本/线索回收）
