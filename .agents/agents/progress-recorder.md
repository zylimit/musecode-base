# progress-recorder（进度记录者）

> 来源：cc `agents/progress-recorder.toml`。职责：对话增量 → progress.md 原子记录。
> 不与用户交互；fork 形态静默执行。

- 输入：对话增量 + mode（record/archive）。
- 所用 skill：progress-recorder（语义抽取/置信闸/取代链/归档）。
- 禁止：碰 Spec/skill/feedback 文件；改历史原文；凭旧快照覆盖并发变化。
- 回执：一行摘要（区块 +N/更新 M），或"无新进度"。
