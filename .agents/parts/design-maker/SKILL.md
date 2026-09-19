---
name: design-maker
description: 当 Design Brief 完成后、用户需要生成可交互设计稿时使用。产物单文件离线 HTML。
---

# design-maker

- 版本：1.0.0
- 适用：从 Brief 出可交互 HTML 设计稿（开发参照 + 干系人评审两用）。不适用：无 Brief（先走 design-brief-builder）。
- 输入：REQ + Design-Brief + 视觉方向/token。
- 输出：`demo/index.html`（单文件、离线、可交互）+ 设计计划 + 验收报告。

## 步骤

1. 依赖检测：Brief 必需；视觉 token 缺失则临时抽一组并标"未经视觉基线"，建议回补。
2. 两遍法第一遍：写设计计划（token 摘录、每页线框与对齐、首屏特征、大胆一处、动效一处、组件复用）。
3. 两遍法第二遍：先过原生 taste（AI 味否决清单），再对照 Brief 的 Don'ts 自审——凡"给任何同类页面都会给的默认"就改，并写"原本→改成→为什么"。
4. 生成：单文件 index.html（CSS/JS 内联，零外部依赖，字体系统栈回退）；真实业务文案与样本数据，不用 Lorem；token 外不许散写 hex；八态逐页覆盖；`docs/UI-QUALITY-FLOOR.md` 的 MUST 不宣告地做到；`docs/DESIGN_VOCABULARY.md` 作 taste 之外的扩展对照（命中的说出改了什么）。
5. 客观验收（逐条跑，不凭看）：`</html>` 完整收尾、无 CDN 字样、页面覆盖 grep、八态文案 grep、hex 值全在 token 内、390px 无横向滚动、Tab 走主流程。
6. 方向样张（如需）：先用三版完整人格样张让用户选定方向再出全稿；同一失败两轮无新证据则停下报阻塞。
7. 交付：落盘 `demo/`；编码参照分两层——业务规则/权限/数据以 Spec → Brief 为准，demo 不得覆盖；布局与交互细节参照 demo → token。两层冲突时 Spec 赢，并把 demo 缺口写进报告已知缺口。

## 约束与红线

- 文档驱动：一切设计决策来自 Brief/token，不添加文档未描述的功能（`ARCHITECTURE.md` 红线 2）。
- 真实内容：样本数据须脱敏，禁止真实个人信息进稿（PRI）。
- 模拟边界明确标注：原型"保存/发送"不声称真调后端；演示控制与产品操作区分。

## 验收

- 双击离线可开；页面 N/N、八态 N/N；hex 全在 token 内；质量地板抽查过。
- 领导评审可直接浏览器打开，所见即所得。

## 示例

派单 Brief → 设计计划（三屏线框+大胆放在"状态一瞥条"）→ 自审改掉"全圆角卡片阵列"默认 → 生成 → grep 验收 → 交付 demo/index.html。

## 参考（`references/`，按触发条件读，不预读）

- `prototype-construction.md`：布局实现、组件/状态、直接操作或实际预览时读相应部分。
- `task-walkthrough.md`：跨页面任务、易误解的结果状态或参与者试走时读。
- `example-after-sales-DESIGN.md`：范例（DESIGN 全文，token 引用写法对照）。

## Donor 出处

- `cc-base/.claude/skills/design-maker/SKILL.md`（两遍法、odc/提示词双路、客观验收、离线自包含）
- `codex-base/.agents/skills/design-maker/SKILL.md`（覆盖矩阵、试走方法、回填路由）
- 注：本仓无 odc，用"直接生成 + 提示词模式"替代其双路；验收脚本待补（缺口）。
