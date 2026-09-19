# Shell 安全速查（SHELL-SAFETY）

> 来源：codex `.codex/rules/safety.rules`（前缀规则 DSL 蒸馏）+ cc `secret-exfil-guard`（R1–R4）+ `dangerous-pkill`。
> 机器执行：`bash scripts/shell-guard.sh "<命令>"`（deny/prompt/allow 三态）。Muse 原生 approval 是第一层，本表是可审计的第二意见。

## DENY（永远不跑，先改命令）

| 规则 | 命中 | 反例（安全） |
|---|---|---|
| 管道进 shell | `curl … \| sh`、`wget … \| bash` | 落盘审查后再跑 |
| rm -rf 危险目标 | `/`、`~`、`$HOME`、`/home`、`/etc`、`/usr`、`/var`、通配符 | 具体子路径（进 PROMPT） |
| 关机重启 | `poweroff/reboot/shutdown/halt/init 0|6` | — |
| 格式化分区 | `mkfs/fdisk/parted …` | — |
| dd 写块设备 | `dd … of=/dev/…` | 写普通文件 |
| find -delete | 任何 `find … -delete` | 先列清单再删 |
| 强制杀进程 | `kill/pkill/killall -9` | 先确认归属再温柔杀 |
| chmod 777 | 尤其 `-R 777` | 最小权限 |
| git 破坏性 | force-push / `reset --hard` / `checkout .` / `clean -fd` / 历史重写 | 普通提交推送 |
| 读密钥文件 | cat/less/grep/sed…读 `*.pem/*.key/id_rsa/.env/credentials.json/secrets.yaml` | 读前确认必要性并脱敏 |
| 外发密钥材料 | scp/rsync/curl/wget 传密钥文件或 AKIA 等字面量 | — |

## PROMPT（停下来给人看，确认再跑）

| 规则 | 命中 | 确认什么 |
|---|---|---|
| 远端副作用 | git push / npm publish / docker push / kubectl apply·delete / gh release / ssh | 目标与动作是否被授权覆盖 |
| 改服务状态 | systemctl/service/brew/launchctl stop·restart·disable | 影响面 |
| xargs 接 rm | `xargs … rm` | 先看清单（-p 或先列） |
| pkill 宽泛 | 短模式 pkill（非精确进程名） | 先 pgrep 确认 |
| rm -rf 普通路径 | 具体子路径 | ls 先看 |

## wrapper 剥离

`sudo/timeout/env/nice/nohup` 下的真实命令才是判定对象，多层剥到裸命令。
`timeout 30 curl …` 的超时数字不影响危险分级。

## 与 Muse 原生的关系

- Muse 自带分级审批与危险模式拦截（见 `docs/MUSE-NATIVE.md` §4），本表是其**超集文档化**：凡本表 DENY 的，在 Muse 里也必须被拦（亲决或拒跑）。
- 例外：以宽 allow 存前缀规则时，deny 恒胜 allow；解释器前缀（python/bash/node）不可存宽 allow。
