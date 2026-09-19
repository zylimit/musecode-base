---
name: branch-finisher
description: 当 Phase/功能开发完成，或用户说"收尾"、"合并分支"、"这个分支弄完了"时使用。
---

# branch-finisher

- 版本：1.0.0
- 适用：开发分支的测试→合并/PR→清理收尾。不适用：发版（走 release-builder）。
- 输入：当前分支 + 用户选定的收尾动作（合并/PR/暂留）。
- 输出：合并 commit 或 PR 链接 + 清理报告 + baseline 对照。

## 步骤

1. 先探后动：判三类环境（正常分支/linked worktree/detached HEAD，排除 submodule 误判）、工作区是否干净、相对主分支的提交差；脏工作区先提交或暂存。
2. 前置闸：回归全绿（测试运行器真实输出，复用 test-builder 套件）；有红按代码错/测试错分流修到绿；无测试基建须用户显式放行并记录"无测试保护的收尾"。
3. 给条件化菜单：正常分支（合并/PR/暂留）、worktree（+清理）、detached（先建分支再收）；用户选定后执行，不擅自取舍合并冲突。
4. 执行：合并核对目标分支与冲突结果；PR 核对 base/head 与内容；每步后查实际状态（提交核新 HEAD、推送核远端 ref）。
5. 清理：分支已合并才删（`git branch -d`，不用 -D）；worktree 改动已合并/已推且工作区干净才 `remove`；PR 待合并的分支不删。
6. baseline 对照：收尾前后各跑 `git status` + `git worktree list` + 当前分支确认，无残留脏状态。
7. 报告：动作/清理/baseline；commit/PR 描述用 HUMAN（用户原话意图与验收确认）/AGENT（变更与证据）分区，不把测试 PASS 伪装成人工确认。

## 约束与红线

- 收尾意图≠授权：commit/push/merge/rebase/删分支/清 worktree 各项须覆盖目标与动作的授权（`AGENTS.md` §5）。
- 不删未合并的东西；dirty tree 不切分支、不 rebase、不覆盖文件。
- 中断后先核本地/远端真实状态，不盲目重试。

## 验收

- 测试闸真实输出全绿；合并/PR 目标核对无误；baseline 干净无残留 worktree。
- 报告写明"验证了什么/没验证什么"，工作树干净≠业务已验收。

## 示例

feature/dispatch 收尾：环境正常分支、干净、领先 main 5 提交 → 回归 34 passed → 用户选合并 → merge 无冲突 → push → `branch -d` → baseline 干净。

## Donor 出处

- `cc-base/.claude/skills/branch-finisher/SKILL.md`（三类环境、菜单、清理规则、baseline）
- `codex-base/.agents/skills/branch-finisher/SKILL.md`（授权边界、HUMAN/AGENT 分区、核验链）
