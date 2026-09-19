#!/bin/bash
# arch-check.sh — 架构防腐最小版：catalog 声明图校验 + JS/TS/Python 静态 import 实边对照 + 趋势棘轮。
# 实边范围：只扫 src/**（JS/TS 用静态 import，Python 用 AST helper，失败回退正则并声明）。
#   相对导入按语言规则归属（JS 按文件路径规范化；Python 按目录≈包），解不出的记 partial；
#   catalog 模块路径落在 src/ 之外的，WARN 明示未覆盖——零边不等于结构干净。
# 用法：bash scripts/arch-check.sh [--scan] [--record] [--gate] [--baseline FILE] [--help]
#   无 flag     只做声明图校验（catalog lint）
#   --scan      追加实边扫描（Python 用 AST，JS/TS 用静态 import；AST 不可用保守回退正则并声明）
#   --record    快照边身份集合到 .agents/harness/arch-baseline.json（随仓提交，不是运行态）
#   --gate      按边身份比对基线：新边即 fail；基线损坏先 quarantine 再重立
#   --baseline  指定基线文件（默认上值；ARCH_BASELINE 环境变量同效）
# 退出码：0 干净 / 1 有违规 / 2 用法错 / 3 降级（无 catalog，未建立结论）
# 依赖：python3（标准库 only）。环/显式禁边/保护层反向边永不可 baseline。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
usage() { sed -n '2,10p' "$0"; }

SCAN=0; RECORD=0; GATE=0; BASELINE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --scan) SCAN=1; shift ;;
    --record) RECORD=1; shift ;;
    --gate) GATE=1; shift ;;
    --baseline) [ $# -ge 2 ] || { echo "arch-check: --baseline needs a value" >&2; exit 2; }; BASELINE="$2"; shift 2 ;;
    --baseline=*) BASELINE="${1#--baseline=}"; shift ;;
    -*) echo "arch-check: unknown flag $1" >&2; usage >&2; exit 2 ;;
    *) echo "arch-check: unexpected positional $1" >&2; usage >&2; exit 2 ;;
  esac
done
[ -n "$BASELINE" ] && export ARCH_BASELINE="$BASELINE"

CATALOG=".agents/harness/module-catalog.json"
if [ ! -f "$CATALOG" ]; then
  echo '{"state":"DEGRADED","degraded":true,"error":"catalog-missing","detail":"'"$CATALOG"'"}'
  echo "arch-check: no catalog (small repo, checks not established)" >&2
  exit 3
fi
command -v python3 >/dev/null 2>&1 || { echo "arch-check: python3 not found" >&2; exit 2; }

export ARCH_CATALOG="$CATALOG" ARCH_SCAN="$SCAN" ARCH_RECORD="$RECORD" ARCH_GATE="$GATE"
python3 - "$CATALOG" <<'PYEOF'
import json, os, posixpath, re, sys, glob as pyglob
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

# 内建门漏接提醒：catalog 声明了 layers/禁边，但 checks 里没有任何 arch-check 命令
_checks = cat.get("checks", {}) or {}
_has_arch_gate = any("arch-check" in str(v.get("command", "")) for v in _checks.values() if isinstance(v, dict))
_declares_structure = bool(layers) or any(m.get("forbiddenDependencies") for m in modules)
if _declares_structure and not _has_arch_gate:
    print("WARN[ARCH_GATE_MISSING]: catalog 声明了分层/禁边，但 checks 里没有 arch-check 命令——声明无人执行")

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

def py_rel_targets(f, level, module, names):
    """Python 相对导入归属（静态近似：目录≈包，namespace package 同）。
    返回 (targets, partial_note)：targets 为 src/ 下候选路径；解不出时 note 非空。"""
    try:
        comps = list(Path(f).parent.relative_to("src").parts)
    except ValueError:
        return [], f"RELATIVE_OUTSIDE_SRC: {f} level={level}"
    if level < 1:
        return [], f"RELATIVE_BAD_LEVEL: {f} level={level}"
    if level - 1 > len(comps):
        return [], f"RELATIVE_BEYOND_TOP: {f} level={level}"
    base = comps[:len(comps) - (level - 1)]
    if module:
        return [posixpath.join("src", *(base + module.split(".")))], None
    if names:
        tgts = [posixpath.join("src", *(base + [n.split(".")[0]])) for n in names if n and n.split(".")[0]]
        if tgts:
            return tgts, None
    return [], f"RELATIVE_EMPTY: {f} level={level} (no module, no names)"

_ast_abs = {}     # path -> [absolute top modules]
_ast_rel = {}     # path -> [(level, module, names)]
_ast_issues = {}  # path -> [helper issues]（缺省=helper 未覆盖该文件）
if scan or record or gate:
    files = []
    for ext in ("*.py", "*.js", "*.mjs", "*.cjs", "*.ts", "*.tsx"):
        files += pyglob.glob(f"src/**/{ext}", recursive=True)
    files = files[:20000]
    if len(files) >= 20000:
        partial_reasons.add("TRUNCATED: file list capped at 20000 (conservative: unknown remainder)")
    # Python AST 批提取（单次 helper 调用；失败则整批回退正则）
    _py = [f for f in files if f.endswith(".py")]
    if _py and Path("scripts/python-imports.py").exists():
        try:
            import subprocess
            batch = {"version": 1, "files": []}
            for f in _py[:2000]:
                try:
                    batch["files"].append({"path": f, "text": Path(f).read_text(encoding="utf-8")[:500000]})
                except Exception:
                    pass
            out = subprocess.run(["python3", "scripts/python-imports.py"], input=json.dumps(batch),
                                 capture_output=True, text=True, timeout=120)
            if out.returncode == 0:
                for item in json.loads(out.stdout).get("files", []):
                    absmods, rels = [], []
                    for imp in item.get("imports", []):
                        if not isinstance(imp, dict):
                            continue
                        lvl = imp.get("level", 0) or 0
                        if lvl > 0:
                            rels.append((lvl, imp.get("module") or "", list(imp.get("names") or [])))
                            continue
                        mod = imp.get("module") or ""
                        if not mod and imp.get("names"):
                            mod = imp["names"][0]
                        if mod:
                            absmods.append(mod)
                    _ast_abs[item["path"]] = absmods
                    _ast_rel[item["path"]] = rels
                    _ast_issues[item["path"]] = [i for i in item.get("issues", []) if isinstance(i, str)]
        except Exception:
            pass
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
            imp = _ast_abs.get(f, None)
            if imp is None:  # AST 不可用时回退正则（注释/字符串可能误报，保守记录）
                for a, b in PY_IMPORT.findall(text):
                    if a:
                        dots = len(a) - len(a.lstrip("."))
                        if dots:
                            tgts, note = py_rel_targets(f, dots, a[dots:], [])
                            if note:
                                partial_reasons.add(note)
                            for t in tgts:
                                specs.add(("rel", t))
                        else:
                            specs.add(("py", a.split(".")[0]))
                    elif b:
                        for name in b.split(","):
                            n = name.strip().split(" ")[0].split(".")[0]
                            if n and not n.startswith("."):
                                specs.add(("py", n))
                partial_reasons.add(f"REGEX_FALLBACK: {f} python imports via regex (AST unavailable)")
            else:
                for name in imp:
                    if name and not name.startswith("."):
                        specs.add(("py", name.split(".")[0]))
                for (lvl, mod, names) in _ast_rel.get(f, []):
                    tgts, note = py_rel_targets(f, lvl, mod, names)
                    if note:
                        partial_reasons.add(note)
                    for t in tgts:
                        specs.add(("rel", t))
                for iss in _ast_issues.get(f, []):
                    if iss == "python-dynamic-import":
                        partial_reasons.add(f"DYNAMIC: {f} uses dynamic import (partial coverage)")
                    else:
                        partial_reasons.add(f"PYAST: {f} {iss} (partial coverage)")
            if re.search(r"__import__|importlib|exec\(|eval\(", text):
                partial_reasons.add(f"DYNAMIC: {f} uses dynamic import (partial coverage)")
        else:
            for a, b in JS_IMPORT.findall(text):
                spec = a or b
                if spec.startswith("."):
                    target = posixpath.normpath((Path(f).parent / spec).as_posix())
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

base_env = os.environ.get("ARCH_BASELINE", "").strip()
state_path = Path(base_env) if base_env else Path(".agents/harness/arch-baseline.json")
if record:
    state_path.parent.mkdir(parents=True, exist_ok=True)
    snap = {"version": 1, "edges": sorted([f"{s}>{d}" for (s, d, _) in real_edges]),
            "forbidden": sum(1 for e in errors if e.startswith("FORBIDDEN_EDGE"))}
    state_path.write_text(json.dumps(snap, sort_keys=True, indent=1) + "\n", encoding="utf-8")
    print(f"INFO: recorded {len(snap['edges'])} edges to {state_path} (commit this file)")
if gate:
    if not state_path.exists():
        print("ERROR[TREND_NO_BASELINE]: no baseline; run --record first (then commit the baseline file)")
        sys.exit(2)
    try:
        base_doc = json.loads(state_path.read_text(encoding="utf-8"))
        baseline = set(base_doc.get("edges", []))
    except Exception:
        print("ERROR[TREND_BASELINE_CORRUPT]: cannot parse baseline; quarantine and re-record")
        sys.exit(1)
    current = {f"{s}>{d}" for (s, d, _) in real_edges}
    new_edges = sorted(current - baseline)
    for e in new_edges:
        errors.append(f"NEW_EDGE: {e} not in baseline (pay down or record new baseline)")
    removed = sorted(baseline - current)
    if removed:
        print(f"INFO: {len(removed)} baseline edges gone (paydown or dead code): {', '.join(removed[:5])}")

if scan or record or gate:
    for m in modules:
        for p in m.get("paths", []):
            lit = p.split("*")[0].rstrip("/")
            if lit and not (lit == "src" or lit.startswith("src/")):
                print(f"WARN[SCAN_SCOPE]: {m['id']} 路径 {p} 在 src/ 实边扫描之外——零边不代表该模块干净")
                break
for w in sorted(partial_reasons):
    print(f"WARN: {w}")
for e in sorted(errors):
    print(f"ERROR: {e}")
print("---")
print(f"arch-check: errors={len(errors)} warnings={len(partial_reasons)} scanned={scanned} edges={len(real_edges)} roots=src")
if partial_reasons and gate:
    print("arch-check: PARTIAL scan under --gate blocks (strict)")
    sys.exit(1)
sys.exit(1 if errors else 0)
PYEOF
