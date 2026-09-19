# 界面质量地板（MUST / SHOULD / NEVER）

> 来源：`cc-base/.claude/skills/design-brief-builder/references/ui-quality-floor.md`（整件采用，适配本仓引用）。
> 定位：风格是选择，地板不是。设计稿与代码共用；审计只报违反项（`文件:行 - 问题`），全过写"✓ 通过"。
> 使用者：design-maker（验收）、dev-builder（写界面）、code-review（UI 一致性）。

## 交互 · 键盘与焦点

- MUST 全键盘可操作，Tab 顺序与视觉顺序一致；焦点环可见且不被 sticky/fixed 遮住；弹层焦点管理（困住、关闭后归还）。
- NEVER `outline: none` 而不给替代焦点样式。

## 交互 · 命中区与输入

- MUST 命中区 ≥24px，移动端 ≥44px（视觉小就扩大命中区）；移动端输入框字号 ≥16px 防 iOS 缩放；`touch-action: manipulation`。
- NEVER 禁用浏览器缩放（`user-scalable=no`、`maximum-scale=1`）。

## 交互 · 表单

- MUST 不阻止粘贴；提交按钮请求开始前可用、请求中禁用+进度+保留文案；Enter 提交聚焦输入（textarea 用 ⌘/Ctrl+Enter）；先接受自由输入再校验；错误就地显示、提交聚焦首错；`autocomplete`+有意义 `name`+正确 `type`/`inputmode`；离开前警告未保存；兼容密码管理器与验证码粘贴；复选/单选标签与控件共用命中区。
- SHOULD 邮箱/验证码/用户名关拼写检查；占位符以「…」结尾并给示例格式。

## 交互 · 状态与导航

- MUST URL 反映状态（筛选/Tab/分页/展开可深链）；后退恢复滚动；导航用 `<a>`/Link（支持 ⌘点击、中键）。
- NEVER 用 `<div onClick>` 做导航。

## 交互 · 反馈

- MUST 破坏性动作要确认或给撤销窗口；toast 与行内校验用 polite `aria-live`。
- SHOULD 乐观更新，失败回滚或给撤销；后续对话选项与加载态用「…」结尾。

## 交互 · 触控与拖拽

- MUST 首个 tooltip 延迟、后续即时；弹层内 `overscroll-behavior: contain`；拖拽禁文本选择、被拖元素设 `inert`；拖拽/滑动/捏合都有点击与键盘替代（本质手势除外）；看起来能点的必须能点。

## 动效

- MUST 尊重 `prefers-reduced-motion`；只动 `transform`/`opacity`；可被输入打断；超 5 秒自动播放要有暂停/停止/隐藏。
- NEVER 动 `top/left/width/height`；`transition: all`。
- SHOULD 优先 CSS，其次 Web Animations API；动效只为说明因果或有意的愉悦。

## 布局

- MUST 刻意对齐到网格/基线/边缘；移动/笔记本/超宽屏都验；尊重安全区；无意外滚动条。
- SHOULD 光学对齐 ±1px；布局用 flex/grid 不用 JS 测量。

## 内容与无障碍

- MUST 骨架屏镜像最终内容；`<title>` 对应上下文；无死胡同；空/稀/密/错四态；数字比较用 `tabular-nums`；状态不只靠颜色；用「…」不用「...」；标题层级+跳到内容链接；日期数字本地化；先原生语义再 ARIA；媒体有字幕/文稿。
- SHOULD 行内帮助优先、tooltip 最后；`text-wrap: balance`；品牌名与代码标识加 `translate="no"`。

## 内容处理 / 性能 / 深色 / 设计

- MUST 文本容器处理长内容；flex 子元素 `min-w-0`；空值不渲染坏 UI。
- MUST 变更请求目标 <500ms；大列表（>50 项）虚拟化；图片写宽高防 CLS；首屏图预加载、其余懒加载。
- MUST 深色底从 `#121212` 起不用纯黑；`<html>` 设 `color-scheme: dark`；对比达标（优先 APCA）。
- MUST 图表色盲友好；hover/active/focus 时对比增加不减少。

## AI 通病自检

另过 `DESIGN_VOCABULARY.md` 通病清单：ALL-CAPS 眉标、中点串、破折号标签、一律圆角灰影、每段淡入、按钮尾巴「→」、纯黑冒充、单一酸绿强调——命中的说出为什么留或改。

## 反模式速查

`user-scalable=no`；`onPaste`+`preventDefault`；`transition: all`；`outline-none` 无替代；`<div>` 挂点击当按钮；图片无尺寸；大数组 `.map()` 无虚拟化；输入无标签；图标按钮无 `aria-label`；硬编码日期格式；无理由 `autoFocus`；能用视频却用 GIF；只有手势无替代。
