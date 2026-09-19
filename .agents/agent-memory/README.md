# Agent 角色战术笔记（第三类记忆）

> 来源：cc `memory-systems.md`（agent memory 节）。角色自己的战术备忘（本项目高发缺陷模式 / flaky 区），
> 由角色自维护、无人工审核。不承载框架规则（那是 feedback 的事），不承载项目事实（那是 progress/Spec 的事）。

约定：

- 路径：`.agents/agent-memory/<role>/MEMORY.md`（role = code-reviewer / tester 等）。
- 上限：单文件 ≤5KB，每角色合计 ≤50KB。超了就是文档不是记忆——搬到 `docs/agent-notes/<role>/` 并在 MEMORY.md 留相对路径指针。
- fresh 实例会带上 MEMORY.md 索引与点开的文件：记忆越厚 fresh 越假，预算同样受"单任务 ≤6 次工具调用"约束。
- 角色交接时战术笔记跟随角色走，不跟项目走。
