# 规模指南（SCALING.md）

> 本仓是脚手架（skills + 脚本 + 文档），不是运行时：不拥有调度器、会话存储、子进程池、指标端点。
> 因此本文件只承诺本仓脚本真实承担的扫描面；运行面容量（并发/可用性/延迟 SLO）是目标项目的事，本仓不承诺。

## 1. 本仓实际承担的规模面

| 脚本 | 真实扫描范围 | 硬上限 | 超限行为 |
|---|---|---|---|
| `arch-check.sh --scan/--gate` | `src/**` 下 py/js/mjs/cjs/ts/tsx | 20000 文件；单文件 20 万字符；AST 批前 2000 个 py 文件 | 截断并记 partial（`--gate` 下 partial 即 fail） |
| `fitness.sh` | 触及面/指定路径（默认 git 变更集） | 单文件 1MB；findings 200 条 | 跳过超大文件；超 200 条截断计数 |
| `smoke.sh` / `verify.sh` / `check.sh` | 仓内固定文件清单 + 触及面 | 无（清单级检查，常数时间） | 不适用 |
| `python-imports.py` helper | 单批输入 16MB；单文件源码 1MB | 输入超限/协议不符 rc=2 | 整批回退正则并记 REGEX_FALLBACK |
| catalog contextPack | 单任务上下文预算 | 120000 总字符 / 40 文件 / 单文件 6000 字符 | 超预算拆 Task（`docs/LARGE-REPO.md` §3） |

## 2. 明确不承诺的运行面

以下曾在本文件以 SLO/容量模型出现，现撤回——本仓无对应实现与观测手段，
目标项目如有需要自行定口径（`dfx-designer` 可帮目标项目定，不落本仓）：

- 工具调用并发、全局信号量、调度延迟、99.9% 调度可用性
- 会话数/会话大小/TTL/磁盘水位、子进程池、外部 API QPS
- 熔断器、水平扩容、埋点指标（tool_calls_total 等）、告警线、降级矩阵

## 3. 效率验证（最小可跑，只测本仓真实范围）

```bash
# 3.1 范围：arch 实边扫描耗时与截断（合成 src 树，按真实上限 20000 附近测）
mkdir -p /tmp/scale_probe/src && cd /tmp/scale_probe && git init -q 2>/dev/null
seq 1 5000 | xargs -P 8 -I{} sh -c 'mkdir -p src/m_{}; echo "import os" > src/m_{}/a.py'
cp /path/to/musecode-base/scripts/arch-check.sh scripts/  # 或在目标仓直接跑
time bash scripts/arch-check.sh --scan   # 看 scanned/耗时，>20000 时确认 TRUNCATED partial 出现

# 3.2 预算：fitness 在大 diff 下的输出上限（200 条截断 + 超大文件跳过）
python3 -c "print('TODO fix\n' * 500)" > big.js
bash scripts/fitness.sh --paths big.js   # 确认 findings 截断且退出码语义不变

# 3.3 遗漏：相对导入/动态导入必须记 partial 而不是静默零边（见 arch-check 头注释）
```

> 不用反复跑 `smoke.sh` 冒充容量验证：smoke 是清单检查，与规模无关。
> 压测产物放 `/tmp`，不进仓。

## 4. 与 LARGE-REPO.md 的分工

SCALING 定本仓脚本的扫描范围/上限/验证方法；`docs/LARGE-REPO.md` 定治理机制
（目录/影响/上下文/验证/防腐）。目标项目的运行时容量由目标项目自己定。
