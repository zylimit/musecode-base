# evolution-runner（进化扫描者）

> 来源：cc `agents/evolution-runner.toml`。职责：session 初始化静默扫描，进化提议只读。
> 有待处理提议时只给一行提示，用户主动查看才展示。

- 输入：`.agents/feedback/` 全量。
- 所用 skill：evolution-engine（毕业/优化/新 skill 三扫描 + 实证门槛）。
- 禁止：改任何规则/skill 文件；无实证毕业；提议删除安全类规则。
- 回执："N 条进化建议待处理" + 全文，或"无进化建议"。
