#!/bin/bash
# install-githooks.sh — 安装/卸载本仓 git hooks（只写本仓 .git/hooks，不碰 core.hooksPath）。
# 用法：bash scripts/install-githooks.sh on|off|status
#   on:     写入 pre-commit（smoke + staged fitness）与 pre-push（smoke + verify）
#   off:    仅删除由本脚本安装的钩子（含 MUSecode 标记的才删，不动用户自有钩子）
#   status: 报告安装态
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
MARK="# musecode-base managed hook"

cmd="${1:-status}"
case "$cmd" in on|off|status) ;; *) echo "usage: install-githooks.sh on|off|status" >&2; exit 2;; esac

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "install-githooks: not a git repository (run git init first)" >&2; exit 2; fi
HOOKS_DIR="$(git rev-parse --git-dir)/hooks"
mkdir -p "$HOOKS_DIR"

is_managed() { [ -f "$1" ] && grep -qF "$MARK" "$1" 2>/dev/null; }

if [ "$cmd" = "status" ]; then
  for h in pre-commit pre-push; do
    if is_managed "$HOOKS_DIR/$h"; then echo "$h: installed (managed)";
    elif [ -f "$HOOKS_DIR/$h" ]; then echo "$h: present (user-owned, untouched)";
    else echo "$h: absent"; fi
  done
  exit 0
fi

if [ "$cmd" = "off" ]; then
  for h in pre-commit pre-push; do
    if is_managed "$HOOKS_DIR/$h"; then rm -f "$HOOKS_DIR/$h"; echo "$h: removed"; else echo "$h: kept (not managed)"; fi
  done
  exit 0
fi

# on
cat > "$HOOKS_DIR/pre-commit" <<EOF
#!/bin/bash
$MARK (pre-commit: smoke + staged fitness)
set -uo pipefail
ROOT="\$(git rev-parse --show-toplevel)"
cd "\$ROOT" || exit 2
bash scripts/smoke.sh || exit 2
STAGED="\$(git diff --cached --name-only --diff-filter=ACM | tr '\n' ',' | sed 's/,\$//')"
if [ -n "\$STAGED" ]; then
  bash scripts/fitness.sh --paths "\$STAGED" || exit 2
fi
EOF
cat > "$HOOKS_DIR/pre-push" <<EOF
#!/bin/bash
$MARK (pre-push: smoke + verify)
set -uo pipefail
ROOT="\$(git rev-parse --show-toplevel)"
cd "\$ROOT" || exit 2
bash scripts/smoke.sh || exit 2
bash scripts/verify.sh || exit 2
EOF
chmod +x "$HOOKS_DIR/pre-commit" "$HOOKS_DIR/pre-push"
echo "pre-commit: installed (smoke + staged fitness)"
echo "pre-push: installed (smoke + verify)"
