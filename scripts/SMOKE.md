# Smoke 说明（`scripts/smoke.sh`）

> 最小可跑的冒烟验证：零依赖（bash + coreutils），10 秒内给出仓健康红绿。对应门禁 L0/L1/L2 的统一入口，详见 `docs/HOOKS.md`。

## 运行

```bash
# 仓根执行
bash scripts/smoke.sh
# 期望：退出码 0，尾行 ALL SMOKE CHECKS PASSED
```

首次使用先加执行位：`chmod +x scripts/smoke.sh`（smoke 自身会检查该位）。

## 检查项

| # | 项 | 失败含义 |
|---|---|---|
| 1 | 必备文件存在（协议×3、README、模板×2、HOOKS、QUALITY_CHECKLIST、MUSE-NATIVE、SCALING、SMOKE、SKILLS_SPEC、SKILL 模板） | 有文件缺失，按 FAIL 行补文件 |
| 1b | 扩展必备文件（门禁脚本×6、安装器×2、manifest、契约测试、指南×4、示例 ADR/skill/memory/workflow/catalog/hooks 示例） | 同上 |
| 1c | skill 全量文件（19 skills + skill-lint + 计划模板 + 地板/词汇 + 口径 canon + feedback 模板/索引 + 证据脚本） | 同上 |
| 2 | 模板非空 | 模板被清空，恢复内容 |
| 3 | `bash -n scripts/*.sh` | 门禁脚本自身语法错，先修脚本 |
| 4 | 目录结构（src/tests/docs/adr/scripts/.agents/skills/.agents/memory/.agents/workflows） | 有目录被删，恢复 |
| 5 | python3/bash 可用 | 环境缺解释器，安装后重跑 |
| 6 | 泄露初检（`.secrets` 不存在 + 私钥/云密钥/token 正则无命中） | 疑似密钥落仓：删密钥、轮换、查历史；误报则白名单化该行而非删检查 |
| 7 | `smoke.sh` 可执行位 | 跑 `chmod +x scripts/smoke.sh` |

## 退出码

- `0`：PASS 全绿，尾行 `ALL SMOKE CHECKS PASSED`。
- `1`：任一 FAIL，尾行 `SMOKE FAILED` + `PASS=n FAIL=m` 汇总。

## CI 接入

```yaml
- name: smoke gate
  run: bash scripts/smoke.sh
```

## 扩展约定

- 新增检查只追加、不删除已有检查；删除需 ADR。
- 保持零依赖：只能用 bash + coreutils（grep/sed/awk/find），不得引入 python 包或网络。
- 单文件内完成；复杂逻辑（lint 流水线、三件套检查）归 `verify.sh`/`check.sh`（H4/H5），不塞进 smoke。
- 检查输出统一 `PASS: ...` / `FAIL: ...` 前缀，便于 CI 解析。
