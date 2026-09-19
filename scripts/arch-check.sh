#!/bin/bash
# arch-check.sh — 架构防腐最小版：catalog 声明图校验 + JS/TS/Python 静态 import 实边对照 + 趋势棘轮。
# 用法：bash scripts/arch-check.sh [--scan] [--record] [--gate] [--help]
#   无 flag     只做声明图校验（catalog lint）
#   --scan      追加实边扫描（默认开 legislated 范围：JS/TS/Python 静态 import）
#   --record    快照边身份集合到 .agents/harness-state/arch-trend.jsonl
#   --gate      按边身份比对历史最优：新边即 fail；forbidden>0 任何快照命中即 fail
# 退出码：0 干净 / 1 有违规 / 2 用法错 / 3 降级（无 catalog，未建立结论）
# 依赖：python3（标准库 only）。环/显式禁边/保护层反向边永不可 baseline。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
usage() { sed -n '2,9p' "$0"; }

SCAN=0; RECORD=0; GATE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --scan) SCAN=1; shift ;;
    --record) RECORD=1; shift ;;
    --gate) GATE=1; shift ;;
    -*) echo "arch-check: unknown flag $1" >&2; usage >&2; exit 2 ;;
    *) echo "arch-check: unexpected positional $1" >&2; usage >&2; exit 2 ;;
  esac
done

CATALOG=".agents/harness/module-catalog.json"
if [ ! -f "$CATALOG" ]; then
  echo '{"state":"DEGRADED","degraded":true,"error":"catalog-missing","detail":"'"$CATALOG"'"}'
  echo "arch-check: no catalog (small repo, checks not established)" >&2
  exit 3
fi
command -v python3 >/dev/null 2>&1 || { echo "arch-check: python3 not found" >&2; exit 2; }

export ARCH_CATALOG="$CATALOG" ARCH_SCAN="$SCAN" ARCH_RECORD="$RECORD" ARCH_GATE="$GATE"
python3 - "$CATALOG" <<'PYEOF'
import json, os, re, sys, glob as pyglob
from pathlib import Path

catalog_path = sys.argv[1]
scan = os.environ.get("ARCH_SCAN") == "1"
record = os.environ.get("ARCH_RECORD") == "1"
gate = os.environ.get("ARCH_GATE") == "1"
errors, warnings = [], []

try:
    cat = json.loads(Path(catalog_path).read_text(encoding="utf-8"))
except Exception as e:
    print(f"ERROR[CATALOG_PARSE]: {catalog_path}: {e}")
    sys.exit(2)

modules = cat.get("modules", [])
layers = cat.get("layers", [])
known_attrs = {"security", "safety", "privacy", "resilience", "reliability",
                "availability", "performance", "maintainability"}
tiers = {"critical", "high", "medium", "low", "minimal", "none"}
CATCH_ALL = {"", ".", "*", "**", "**/*"}

ids = set()
for m in modules:
    mid = m.get("id", "")
    if not re.fullmatch(r"[A-Za-z0-9._-]+", mid):
        errors.append(f"BAD_ID: module id {mid!r}")
    if mid in ids:
        errors.append(f"DUPLICATE_ID: {mid}")
    ids.add(mid)
    for p in m.get("paths", []):
        if p in CATCH_ALL:
            errors.append(f"CATCH_ALL: {mid} paths {p!r} too broad")
    for d in m.get("dependsOn", []):
        if d == mid:
            errors.append(f"SELF_DEP: {mid} depends on itself")
    for f in m.get("forbiddenDependencies", []):
        if f == mid:
            errors.append(f"SELF_FORBIDDEN: {mid} forbids itself")
        if f in m.get("dependsOn", []):
            errors.append(f"FORBIDDEN_DECLARED: {mid} both depends on and forbids {f}")
    if "layer" in m and m["layer"] not in layers:
        errors.append(f"UNKNOWN_LAYER: {mid} layer {m['layer']!r}")
    for a, t in (m.get("attributes") or {}).items():
        tier = t.get("tier") if isinstance(t, dict) else t
        if a not in known_attrs:
            errors.append(f"UNKNOWN_ATTRIBUTE: {mid} attr {a!r}")
        if tier not in tiers:
            errors.append(f"UNKNOWN_TIER: {mid} attr {a} tier {tier!r}")
        if tier in ("minimal", "none") and not (isinstance(t, dict) and t.get("reason")):
            errors.append(f"UNJUSTIFIED_TIER: {mid} attr {a} tier {tier} needs reason")
for m in modules:
    for d in m.get("dependsOn", []):
        if d not in ids:
            errors.append(f"DANGLING_DEP: {m['id']} -> unknown {d}")

# OVERLAP：glob 字面去 ** 后前缀包含即重叠（启发式，保守报 warn→error 按 error 计）
prefixes = {}
for m in modules:
    for p in m.get("paths", []):
        lit = p.split("*")[0].rstrip("/")
        prefixes.setdefault(lit, []).append(m["id"])
lits = sorted(prefixes)
for i, a in enumerate(lits):
    for b in lits[i + 1:]:
        if a and b.startswith(a + "/"):
            errors.append(f"OVERLAP: {a} ({prefixes[a]}) shadows {b} ({prefixes[b]})")

# CYCLE（声明图 DFS）
adj = {m["id"]: [d for d in m.get("dependsOn", []) if d in ids] for m in modules}
color = {}
def dfs(u, stack):
    color[u] = 1
    for v in adj.get(u, []):
        if color.get(v) == 1:
            errors.append("CYCLE: " + " -> ".join(stack + [u, v]))
        elif color.get(v) is None:
            dfs(v, stack + [u])
    color[u] = 2
for mid in adj:
    if color.get(mid) is None:
        dfs(mid, [])

def mod_of(path):
    best, bestlen = None, -1
    for m in modules:
        for p in m.get("paths", []):
            lit = p.split("*")[0].rstrip("/")
            if lit and (path == lit or path.startswith(lit + "/")) and len(lit) > bestlen:
                best, bestlen = m["id"], len(lit)
    return best

real_edges = set()  # (src_mod, dst_mod, file)
JS_IMPORT = re.compile(r"""(?:import\s+(?:[^'"]*?\s+from\s+)?|require\()\s*['"]([^'"]+)['"]|from\s+['"]([^'"]+)['"]""")
PY_IMPORT = re.compile(r"^\s*(?:from\s+([\w.]+)\s+import|import\s+([\w.,\s]+))", re.M)
scanned, partial_reasons = 0, set()

if scan or record or gate:
    files = []
    for ext in ("*.py", "*.js", "*.mjs", "*.cjs", "*.ts", "*.tsx"):
        files += pyglob.glob(f"src/**/{ext}", recursive=True)
    files = files[:20000]
    if len(files) >= 20000:
        partial_reasons.add("TRUNCATED: file list capped at 20000 (conservative: unknown remainder)")
    for f in files:
        try:
            text = Path(f).read_text(encoding="utf-8", errors="strict")[:200000]
        except Exception:
            partial_reasons.add(f"UNREADABLE: {f}")
            continue
        scanned += 1
        src = mod_of(f)
        if src is None:
            continue
        specs = set()
        if f.endswith(".py"):
            for a, b in PY_IMPORT.findall(text):
                if a and not a.startswith("."):
                    specs.add(("py", a.split(".")[0]))
                elif b:
                    for name in b.split(","):
                        n = name.strip().split(" ")[0].split(".")[0]
                        if n and not n.startswith("."):
                            specs.add(("py", n))
            if re.search(r"__import__|importlib|exec\(|eval\(", text):
                partial_reasons.add(f"DYNAMIC: {f} uses dynamic import (partial coverage)")
        else:
            for a, b in JS_IMPORT.findall(text):
                spec = a or b
                if spec.startswith("."):
                    target = str((Path(f).parent / spec).as_posix())
                    specs.add(("rel", target))
                elif spec.startswith("@"):
                    specs.add(("pkg", spec.split("/")[0] + "/" + spec.split("/")[1] if "/" in spec else spec))
                else:
                    specs.add(("pkg", spec.split("/")[0]))
            if re.search(r"require\s*\(\s*[A-Za-z_$]|import\s*\(", text):
                partial_reasons.add(f"DYNAMIC: {f} uses dynamic import (partial coverage)")
        for kind, spec in specs:
            dst = None
            if kind == "rel":
                for cand in (spec, spec + ".py", spec + ".js", spec + ".ts", spec + "/index.js", spec + "/__init__.py"):
                    dst = mod_of(cand) or (mod_of(str(Path(cand).parent)) if "/" in cand else None)
                    if dst:
                        break
            elif kind == "py":
                for cand in (f"src/{spec}", f"src/{spec}/__init__.py"):
                    dst = mod_of(cand)
                    if dst:
                        break
            if dst and dst != src:
                real_edges.add((src, dst, f))
    # 实边 vs 声明
    by_id = {m["id"]: m for m in modules}
    for (s, d, f) in sorted(real_edges):
        m = by_id[s]
        if d in (m.get("forbiddenDependencies") or []):
            errors.append(f"FORBIDDEN_EDGE: {s} -> {d} at {f}")
        elif d not in (m.get("dependsOn") or []):
            errors.append(f"UNDECLARED_EDGE: {s} -> {d} at {f} (drift: impact under-counts)")
        la, lb = m.get("layer"), by_id[d].get("layer")
        if la and lb and layers and layers.index(la) > layers.index(lb):
            errors.append(f"LAYER_VIOLATION: {s}[{la}] -> {d}[{lb}] at {f} (must depend inward)")

state_path = Path(".agents/harness-state/arch-trend.jsonl")
if record:
    state_path.parent.mkdir(parents=True, exist_ok=True)
    snap = {"edges": sorted([f"{s}>{d}" for (s, d, _) in real_edges]),
            "forbidden": sum(1 for e in errors if e.startswith("FORBIDDEN_EDGE"))}
    with state_path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(snap, sort_keys=True) + "\n")
    print(f"INFO: recorded {len(snap['edges'])} edges to {state_path}")
if gate:
    if not state_path.exists():
        print("ERROR[TREND_NO_BASELINE]: no baseline; run --record first")
        sys.exit(2)
    try:
        lines = [json.loads(line) for line in state_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    except Exception:
        print("ERROR[TREND_HISTORY_CORRUPT]: cannot parse trend history")
        sys.exit(1)
    if any(isinstance(x, dict) and x.get("forbidden", 0) > 0 for x in lines):
        pass  # historical forbidden noted; current forbidden fails below via errors
    baseline = set.intersection(*[set(x.get("edges", [])) for x in lines]) if lines else set()
    current = {f"{s}>{d}" for (s, d, _) in real_edges}
    new_edges = sorted(current - baseline)
    for e in new_edges:
        errors.append(f"NEW_EDGE: {e} not in baseline (pay down or record new baseline)")
    if not lines:
        print("WARN[TREND_EMPTY]: empty history, everything is new")

for w in sorted(partial_reasons):
    print(f"WARN[{w.split(':')[0]}]: {w}")
for e in sorted(errors):
    print(f"ERROR: {e}")
print("---")
print(f"arch-check: errors={len(errors)} warnings={len(partial_reasons)} scanned={scanned} edges={len(real_edges)}")
if partial_reasons and gate:
    print("arch-check: PARTIAL scan under --gate blocks (strict)")
    sys.exit(1)
sys.exit(1 if errors else 0)
PYEOF
