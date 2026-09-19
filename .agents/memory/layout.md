# 脚手架布局约定

`.agents/` 放 Muse 原生项目资产（skills/memory/workflows，随仓共享）；`.muse/` 只放 `hooks.json`（项目 hooks 声明）。

原因：官方文档规定 Project skills 路径为 `.agents/skills/<id>/SKILL.md`，Project memory 为 `.agents/memory/`，可复用 workflow 为 `.agents/workflows/*.js`，Project hooks 为 `.muse/hooks.json`（见 `docs/MUSE-NATIVE.md` §2/§3/§6/§7，ADR-0001）。

不要在 `.muse/` 下新建 `skills/`、`memory/`、`workflows/` 目录——官方发现机制看不见它们。
