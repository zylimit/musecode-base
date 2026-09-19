#!/bin/bash
# skill-lint.sh — skill 发现元数据检查（frontmatter name/description 契约）。
# 来源：codex-base skill-builder/scripts/skill-description-lint.sh（路径适配本仓）。
# 退役条件：`muse skills validate` 覆盖本仓结构要求时缩为 SPEC 行检查；全覆盖则删。
# 用法：bash scripts/skill-lint.sh
# 退出码：0 通过 / 1 有违规 / 2 用法错或 python3 缺。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
[ "${1:-}" = "--help" ] && { sed -n '2,5p' "$0"; exit 0; }
[ $# -gt 0 ] && { echo "skill-lint: no arguments expected" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "skill-lint: python3 not found" >&2; exit 2; }

python3 - "$ROOT" <<'PYEOF'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
failures = []

def fail(path, message):
    failures.append(f"{path.relative_to(root)}: {message}")

seen_names = {}
for path in sorted((root / ".agents" / "skills").glob("*/SKILL.md")):
    if path.parent.name == "_template":
        continue
    text = path.read_text(encoding="utf-8")
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        fail(path, "missing frontmatter")
        continue
    fields = {}
    for line in m.group(1).splitlines():
        if ":" not in line:
            fail(path, f"invalid frontmatter line: {line}")
            continue
        key, value = line.split(":", 1)
        key, value = key.strip(), value.strip()
        fields[key] = value.strip('"')
        if key not in ("name", "description"):
            if re.fullmatch(r'"(?:true|false)"', value):
                fail(path, f"boolean field {key} must be bare true/false")
            if ": " in value.strip('"') and not (value.startswith('"') and value.endswith('"')):
                fail(path, f"bare value of {key} contains ': ' (quote it)")
    name = fields.get("name", "")
    desc = fields.get("description", "")
    if name in seen_names:
        fail(path, f"duplicate name {name!r} (also in {seen_names[name]})")
    else:
        seen_names[name] = path.parent.name
    if path.parent.name != name:
        fail(path, f"dir/name mismatch: dir={path.parent.name!r} name={name!r}")
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
        fail(path, f"invalid name: {name!r}")
    if not desc:
        fail(path, "missing description")
        continue
    if len(desc) > 180:
        fail(path, f"description too long: {len(desc)} chars")
    if not (desc.startswith("当") or desc.startswith("由")):
        fail(path, "description should describe trigger conditions first")
    for section in ("## 步骤", "## 约束与红线", "## 验收"):
        if section not in text:
            fail(path, f"missing section {section}")

if failures:
    print("skill-lint: failed", file=sys.stderr)
    for item in failures:
        print(f"- {item}", file=sys.stderr)
    raise SystemExit(1)
print("skill-lint: passed")
PYEOF
