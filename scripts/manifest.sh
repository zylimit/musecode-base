#!/bin/bash
# manifest.sh — 框架清单生成/校验（LF 归一 SHA-256；清单自身不列入，避免自指）。
# 出处：本仓自写；方法来源见 docs/CROSS-POLLINATION.md（H10/X10）。
# 退役条件：安装器退役时同步删。
# 用法：bash scripts/manifest.sh --write|--check [--help]
# 退出码：0 一致/写成功 / 1 漂移 / 2 用法错或工具缺。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
usage() { sed -n '2,5p' "$0"; }
MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --write) MODE="write"; shift ;;
    --check) MODE="check"; shift ;;
    -*) echo "manifest: unknown flag $1" >&2; usage >&2; exit 2 ;;
    *) echo "manifest: unexpected positional $1" >&2; usage >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { usage >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "manifest: sha256sum not found" >&2; exit 2; }

MANIFEST="FRAMEWORK-MANIFEST.json"
list_files() {
  # 恒用 find，不用 git ls-files：unborn 空仓、部分暂存、未跟踪新文件三种情况下 git 口径都会漏文件；
  # manifest 要的是“工作树里有什么”，新文件必须迫使 --write 重审。
  find AGENTS.md ARCHITECTURE.md HARNESS.md README.md SCALING.md docs scripts tests .agents .muse setup.sh setup.ps1 .gitignore -type f 2>/dev/null \
    | grep -vE "^FRAMEWORK-MANIFEST.json$|harness-state/|\.framework-new$|\.bak$|/evidence/|__pycache__|\.pyc$|\.pytest_cache|/\.git/|node_modules|\.DS_Store|\.mypy_cache|\.ruff_cache" | LC_ALL=C sort -u
}
gen() {
  printf '{\n  "version": 1,\n  "hashAlgorithm": "sha256-lf",\n  "files": [\n'
  first=1
  while IFS= read -r f; do
    [ -n "$f" ] || continue; [ -f "$f" ] || continue
    h="$(tr -d '\r' < "$f" | sha256sum | awk '{print $1}')"
    b="$(wc -c < "$f" | tr -d ' ')"
    if [ "$first" -eq 1 ]; then first=0; else printf ',\n'; fi
    printf '    {"path": "%s", "sha256": "%s", "bytes": %s}' "$f" "$h" "$b"
  done < <(list_files)
  printf '\n  ]\n}\n'
}
case "$MODE" in
  write) gen > "$MANIFEST"; echo "manifest: wrote $MANIFEST" ;;
  check)
    [ -f "$MANIFEST" ] || { echo "manifest: $MANIFEST absent (run --write)" >&2; exit 1; }
    if [ "$(gen)" = "$(cat "$MANIFEST")" ]; then echo "manifest: OK"; else echo "manifest: DRIFT (run --write after review)" >&2; exit 1; fi
    ;;
esac
