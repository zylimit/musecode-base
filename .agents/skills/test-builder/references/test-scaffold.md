> 来源：cc-base `test-builder/templates/test-scaffold.md` + codex-base `test-builder/templates/test-scaffold.md`（合并，路径适配本仓）。
> 原则：最小可用。先让空套件 + 一个样例用例跑通，再写真测试。不引入覆盖率门禁、不接 CI（除非用户要求）。

# 测试基建最小 scaffold 参考

## 后端 · pytest（Python / FastAPI）

**依赖**（进 `requirements.txt` 或 dev 依赖）：`pytest`；测 async 再加 `pytest-asyncio`。
**目录约定**：`tests/`，文件名 `test_*.py`，文件头标 `# risk: high|medium|low`。
**最小配置**（`pytest.ini` 或 pyproject 段，用了 pytest-asyncio 才加第三行）：

```ini
[pytest]
testpaths = tests
asyncio_mode = auto
```

**样例用例**（`tests/test_smoke.py`，验证基建可跑）：

```python
def test_scaffold_alive():
    assert 1 + 1 == 2
```

**跑**：`python -m pytest -q`

## 前端 · vitest（TypeScript / React + Vite）

**依赖**（devDependencies）：`vitest`；测组件渲染再加 `@testing-library/react` 与 `jsdom`。
**目录约定**：就近 `*.test.ts` 或 `src/__tests__/`；scripts 加 `"test": "vitest run"`。
**最小配置**（`vitest.config.ts`，纯函数测试可省 environment）：

```ts
import { defineConfig } from "vitest/config";
export default defineConfig({
  test: { environment: "node" },   // 测组件改 "jsdom"
});
```

**样例用例**（优先测无副作用纯函数）：

```ts
import { describe, it, expect } from "vitest";
describe("utils 纯函数", () => {
  it("scaffold alive", () => expect(1 + 1).toBe(2));
});
```

**跑**：`npm run test`

## 双向转换 / 外部格式契约（必抄法）

外部文件、协议、双向换算的测试必须包含：**单向预期**（`2500mm→2.5m` 与 `2.5m→2500mm` 是两条独立期望，分别写死）、**固定向量**（来自交接文档/真实样本的字节级输入输出各一条，不从待测函数生成）、**无参照声明**（外部解析没有第三方参照时明说测试只能保证内部一致，不能证明符合真实世界）。

## 取舍提醒

- 先测纯逻辑 / 契约 / 解析：构造数据喂纯函数即可，跑得快、稳；需要真库时用最小 fixture + 测试库，绝不碰生产或基线数据。
- 组件渲染、E2E（Playwright）成本高，按预算和价值排后。
- scaffold 阶段只求样例能跑通，高价值用例按 test-builder 风险分级补。
