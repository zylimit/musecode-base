#!/usr/bin/env bash
# plan-lint.sh — 开发计划静态质量门（把 dev-planner 的规则自动化）。
# 来源：cc-base/.claude/scripts/plan-lint.sh（ID 口径与路径适配本仓）。
# 退役条件：PLAN 模板停用时删。
# 用法： bash scripts/plan-lint.sh [plan] [spec...]
#   无参数：PLAN 取 docs/PLAN-*.md 首个，SPEC 取全部 docs/REQ-*.md；缺谁跳过谁。
# 退出码：0 通过/跳过 / 1 有失败 / 2 用法错。
set -eu

PLAN=""
SPECS=""
seen=0
for arg in "$@"; do
  case "$arg" in
    -*)
      echo "plan-lint: 未知参数 $arg（用法：plan-lint.sh [plan] [spec...]）" >&2
      exit 2
      ;;
    *)
      seen=$((seen + 1))
      if [ "$seen" -eq 1 ]; then PLAN="$arg"; else SPECS="$SPECS $arg"; fi
      ;;
  esac
done

if [ -z "$PLAN" ]; then
  PLAN="$(ls docs/PLAN-*.md 2>/dev/null | head -n 1 || true)"
  [ -z "$PLAN" ] && { echo "plan-lint: 无 PLAN，跳过（docs/PLAN-*.md 不存在）"; exit 0; }
fi
if [ ! -f "$PLAN" ]; then
  echo "plan-lint: 无 PLAN，跳过 ($PLAN)"
  exit 0
fi

if [ -z "$SPECS" ]; then
  SPECS="$(ls docs/REQ-*.md 2>/dev/null || true)" # musecode-fitness:ignore no-silent-failure reason="no REQs means skip coverage, stated below"
fi
REAL_SPECS=""
for s in $SPECS; do
  if [ -f "$s" ]; then REAL_SPECS="$REAL_SPECS $s";
  else echo "plan-lint: 忽略不存在的 SPEC ($s)" >&2; fi
done
if [ -z "$REAL_SPECS" ]; then
  echo "plan-lint: 无 REQ，跳过覆盖检查"
fi

python3 - "$PLAN" $REAL_SPECS <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
spec_paths = [Path(a) for a in sys.argv[2:]]
text = path.read_text(encoding="utf-8")
lines = text.splitlines()
failures = []

def fail(message):
    failures.append(message)

# 标记 ``` 围栏内的行号（成对围栏之间，含围栏行本身），占位符与 ID 扫描跳过这些行
def fenced_lines(src_lines):
    marked = set()
    in_fence = False
    for i, line in enumerate(src_lines):
        if re.match(r"\s*```", line):
            marked.add(i)
            in_fence = not in_fence
            continue
        if in_fence:
            marked.add(i)
    return marked

fenced = fenced_lines(lines)

def lines_matching(pattern):
    return [i + 1 for i, line in enumerate(lines)
            if i not in fenced and re.search(pattern, line, re.I)]

# 1) 禁占位符（对齐 dev-planner SKILL.md 已写的规则）
placeholder_patterns = [
    r"\bTBD\b",
    r"\bTODO\b",  # musecode-fitness:ignore todo-without-owner reason="this list is the placeholder rule, not a deferral"
    "待补充",
    "待确定",
    "类似 Task",
    "类似 Phase",
    "按需调整",
    "做相应修改",
    "implement later",
]
for pattern in placeholder_patterns:
    hits = lines_matching(pattern)
    if hits:
        loc = ", ".join(f"L{n}" for n in hits)
        fail(f"占位符命中: {pattern}  ({loc})")

# 2) Phase 结构完整：每个 Phase 须有 交付内容/验证的假设/关键文件/Task 清单/验收标准
phase_matches = list(re.finditer(r"^## Phase\s+\d+[:：].*$", text, re.M))
if not phase_matches:
    fail("未找到任何 ## Phase 小节")

def line_no(pos):
    return text.count("\n", 0, pos) + 1

TASK_ITEM_RE = re.compile(r"^\s*-\s*\*\*Task\s+\d+\.\d+[:：]", re.M)

for index, match in enumerate(phase_matches):
    start = match.start()
    end = phase_matches[index + 1].start() if index + 1 < len(phase_matches) else len(text)
    section = text[start:end]
    title = match.group(0).strip()
    ln = line_no(start)
    for anchor in ["**交付内容**", "**验证的假设**", "**关键文件**", "**Task 清单**", "**验收标准**"]:
        if anchor not in section:
            fail(f"L{ln} {title} 缺字段 {anchor}")
    # 3) 任务粒度：每个 Phase ≥ 1 个 Task
    task_count = len(TASK_ITEM_RE.findall(section))
    if task_count == 0:
        fail(f"L{ln} {title} 没有可执行的 Task 条目（需 - **Task N.M：...**）")

# 4) 需求 ↔ 计划双向覆盖：本仓 ID 口径 FR/R/SC/OUT/SCOPE/Q + 数字；
#    声明认表格行首（| FR-1 |）或列表项（- [FR-1]），引用是裸 token
ID_CORE = r"(?:FR|R|SC|OUT|SCOPE|Q)-\d+"
ID_DECL = re.compile(rf"^\s*(?:\|\s*|(?:[-*+]|\d+[.)])\s*\[?)({ID_CORE})\]?")
ID_REF = re.compile(rf"\b{ID_CORE}\b")

def name_few(id_to_line):
    shown = sorted(id_to_line.items(), key=lambda kv: kv[1])[:3]
    loc = "、".join(f"{rid}（L{ln}）" for rid, ln in shown)
    return loc + (f" 等 {len(id_to_line)} 个" if len(id_to_line) > 3 else "")

def scan_ids(src_lines, skip):
    declared = {}
    mentioned = {}
    for i, line in enumerate(src_lines):
        if i in skip:
            continue
        decl = ID_DECL.match(line)
        if decl and decl.group(1) not in declared:
            declared[decl.group(1)] = i + 1
        for req_id in ID_REF.findall(line):
            mentioned.setdefault(req_id, i + 1)
    return declared, mentioned

if spec_paths:
    spec_declared_all = {}
    spec_mentioned_all = {}
    spec_files = {}
    for sp in spec_paths:
        spec_lines = sp.read_text(encoding="utf-8").splitlines()
        declared, mentioned = scan_ids(spec_lines, fenced_lines(spec_lines))
        for rid, ln in declared.items():
            spec_declared_all.setdefault(rid, f"{sp.name} L{ln}")
        for rid in mentioned:
            spec_mentioned_all.setdefault(rid, sp.name)
        spec_files[sp.name] = (declared, mentioned)
    if not spec_declared_all:
        if spec_mentioned_all:
            print(f"plan-lint: 警告（不改 rc）：REQ 里出现了 {', '.join(sorted(spec_mentioned_all)[:3])}，"
                  "但没有一条被识别成声明——检查是不是没写成表格行首（| FR-1 |）或列表项（- [FR-1]）",
                  file=sys.stderr)
        print("plan-lint: REQ 未用编号，跳过覆盖检查——跳过 = 没查，不是查过了")
    else:
        plan_mentioned = scan_ids(lines, fenced)[1]
        # 覆盖只认 Task 条目行：计划别处提到编号多半是「已知风险：本期不做」，算成有人做就是假绿
        task_ids = set()
        for i, line in enumerate(lines):
            if i not in fenced and TASK_ITEM_RE.match(line):
                task_ids.update(ID_REF.findall(line))
        for req_id, loc in sorted(spec_declared_all.items()):
            if req_id not in task_ids:
                fail(f"需求没人做: {req_id}（{loc}）在 {path.name} 里没有任何 Task 引用")
        for req_id in sorted(set(plan_mentioned) - set(spec_mentioned_all)):
            hits = [i + 1 for i, line in enumerate(lines)
                    if i not in fenced and req_id in line]
            loc = ", ".join(f"L{n}" for n in hits)
            fail(f"悬空引用: {req_id} 在 REQ 中不存在  ({loc})")
        stray = {rid: loc for rid, loc in spec_declared_all.items()
                 if rid not in plan_mentioned}
        # stray 即上面的"需求没人做"已覆盖；此处只报"提到但从未声明"
        mentioned_never_declared = {rid for rid in spec_mentioned_all
                                    if rid not in spec_declared_all and rid not in plan_mentioned}
        if mentioned_never_declared:
            print(f"plan-lint: 警告（不改 rc）：REQ 里的 {', '.join(sorted(mentioned_never_declared)[:3])}"
                  "写了编号但没被识别成声明，计划里也没人做——检查声明格式", file=sys.stderr)

if failures:
    print("plan-lint: 失败", file=sys.stderr)
    for item in failures:
        print(f"- {item}", file=sys.stderr)
    raise SystemExit(1)

print(f"plan-lint: 通过 ({path})")
PY
