#!/bin/bash
# shell-guard.sh — shell 命令危险分级（deny/prompt/allow + 规则解释）。
# 规则来源：codex safety.rules（kill/shutdown/format/pipe/find/xargs/git/rm/chmod/dd/secret 全表）
#   + cc secret-exfil-guard（R1-R4 密钥读/复制/外发）+ dangerous-pkill。
# 用法：bash scripts/shell-guard.sh "<command>" [--explain]
# 退出码：0 allow / 1 deny / 3 prompt（需人看）/ 2 用法错。
# 定位：Muse 原生 approval 之外的可审计第二意见；也可作 PreToolUse hook 命令（schema 待验）。
set -uo pipefail

usage() { sed -n '2,7p' "$0"; }
CMD=""; EXPLAIN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --explain) EXPLAIN=1; shift ;;
    -*) echo "shell-guard: unknown flag $1" >&2; usage >&2; exit 2 ;;
    *) [ -z "$CMD" ] && CMD="$1" || { echo "shell-guard: 只接受一条命令" >&2; exit 2; }; shift ;;
  esac
done
[ -z "$CMD" ] && { usage >&2; exit 2; }

# 剥 wrapper：timeout/env/nice/sudo 下的真实命令才是判定对象（多层剥到裸命令）
strip() {
  local c="$1"
  while :; do
    case "$c" in
      sudo\ *) c="${c#sudo}"; c="$(printf '%s' "$c" | sed -E 's/^ +-+[^ ]+( +[^ ]+)?//')";;
      timeout\ [0-9]*\ *) c="${c#timeout [0-9]*}"; c="${c#[0-9 ]*}";; # 保守：timeout 后数字去不净则整体 prompt
      env\ *|nice\ *|nohup\ *) c="${c#* }" ;;
      *) break ;;
    esac
    c="$(printf '%s' "$c" | sed -E 's/^ +//')"
  done
  printf '%s' "$c"
}
C="$(strip "$CMD")"

deny()  { echo "DENY [$1]: $2"; [ "$EXPLAIN" -eq 1 ] && echo "  command: $CMD"; exit 1; }
prompt() { echo "PROMPT [$1]: $2"; [ "$EXPLAIN" -eq 1 ] && echo "  command: $CMD"; exit 3; }

# --- deny 类：破坏性 / 不可逆 / 外发 ---
case "$C" in
  *"|"*"sh"|*"|"*"bash"*) deny "REMOTE_PIPE" "管道进 shell（curl|sh 类）：先落盘审查再跑" ;;
esac
if printf '%s' "$C" | grep -qE '\b(rm|rmdir)\b.*-[a-zA-Z]*r[a-zA-Z]*f'; then
  if printf '%s' "$C" | grep -qE '(^|[[:space:];|&/])(/|~|\$HOME|/home|/etc|/usr|/var)([[:space:];|&]|$)' \
     || printf '%s' "$C" | grep -qE '\*'; then
    deny "RM_RF_ROOT" "rm -rf 指向根/家目录/系统目录/通配符"
  fi
  prompt "RM_RF" "rm -rf：确认目标路径无误（ls 先看）"
fi
printf '%s' "$C" | grep -qE '\b(poweroff|reboot|shutdown|halt|init 0|init 6)\b' && deny "SHUTDOWN" "关机/重启机器"
printf '%s' "$C" | grep -qE '\b(mkfs|fdisk|parted)[[:space:]]' && deny "DISK_FORMAT" "格式化/分区磁盘"
printf '%s' "$C" | grep -qE '\bdd\b.*of=/dev/' && deny "DD_BLOCK" "dd 写块设备"
printf '%s' "$C" | grep -qE '\bfind\b.*-delete' && deny "FIND_DELETE" "find -delete（先列清单再删）"
printf '%s' "$C" | grep -qE '\b(kill|pkill|killall)\b.*-9' && deny "FORCED_KILL" "强制杀进程（-9）：先确认归属"
printf '%s' "$C" | grep -qE '\bpkill\b' && ! printf '%s' "$C" | grep -qE '\bpkill\b.*(-f[[:space:]]+.{8,}|--full)' && \
  ! printf '%s' "$C" | grep -qE 'node|python|java|npm|vite|next|pytest|jest|vitest' && \
  prompt "PKILL_BROAD" "pkill 宽泛匹配：用精确进程名或先 pgrep 确认"
printf '%s' "$C" | grep -qE '\bchmod\b.*(-R[[:space:]]+)?777' && deny "CHMOD_777" "chmod 777（尤其 -R）"
printf '%s' "$C" | grep -qE '\bgit\b.*(push[[:space:]].*--force|push[[:space:]].*-f([[:space:]]|$)|reset[[:space:]].*--hard|checkout[[:space:]]+\.|clean[[:space:]].*-fd|filter-branch|filter-repo)' && \
  deny "GIT_DESTRUCTIVE" "git 破坏性操作（force-push/hard-reset/clean -fd/历史重写）"
# 密钥读/复制/外发（R1-R4 简版：读密钥文件/复制出安全区/外发）
printf '%s' "$C" | grep -qE '\b(cat|less|more|head|tail|grep|sed|awk|strings|xxd|base64|head -c)\b[^|;]*(\.pem$|\.pem[[:space:]]|\.key$|\.key[[:space:]]|id_rsa|id_ed25519|\.env($|[[:space:].])|credentials\.json|secrets\.yaml)' && \
  deny "SECRET_READ" "读取密钥文件内容"
printf '%s' "$C" | grep -qE '\b(scp|rsync|curl|wget)\b.*(\.pem|\.key|id_rsa|\.env|credentials|AKIA)' && \
  deny "SECRET_EGRESS" "疑似外发密钥材料"
# --- prompt 类：高影响可逆操作 ---
printf '%s' "$C" | grep -qE '\b(git[[:space:]]+push|npm[[:space:]]+publish|docker[[:space:]]+push|kubectl[[:space:]]+(delete|apply)|gh[[:space:]]+release[[:space:]]+(create|delete)|ssh[[:space:]]+[a-z])' && \
  prompt "REMOTE_EFFECT" "远端副作用（push/publish/apply/ssh）：确认目标与动作"
printf '%s' "$C" | grep -qE '\b(systemctl|service|brew[[:space:]]+services|launchctl)[[:space:]]+(stop|restart|disable)' && \
  prompt "SERVICE_STATE" "改服务状态：确认影响面"
printf '%s' "$C" | grep -qE '\b(xargs|xargs -0)\b' && printf '%s' "$C" | grep -qE '\brm\b' && \
  prompt "XARGS_RM" "xargs 接 rm：先看清单（-p 或先列）"

echo "ALLOW: 无命中规则"
exit 0
