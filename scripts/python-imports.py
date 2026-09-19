# 来源：codex-base/.codex/runtime/lib/python-imports.py（整件收录）
"""Bounded AST extraction only. Never import or execute project modules."""

import ast
import json
import sys

MAX_INPUT = 16777216
MAX_SOURCE = 1048576
MAX_NODES = 100000
MAX_IMPORTS = 2048


def extract(source):
    result = {"imports": [], "exports": [], "issues": []}
    try:
        tree = ast.parse(source, filename="<architecture-input>")
    except (SyntaxError, ValueError, RecursionError, MemoryError):
        result["issues"].append("python-syntax-unavailable")
        return result
    issues = set()
    exports = set()
    imports = []
    dynamic_names = {"__import__", "exec", "eval"}
    import_modules = {"importlib", "pkgutil", "runpy", "builtins", "__builtins__"}
    sys_names = {"sys"}
    nodes = []
    for node in ast.walk(tree):
        if len(nodes) >= MAX_NODES:
            issues.add("python-ast-limit")
            break
        nodes.append(node)
    for node in nodes:
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name.split(".")[0] in import_modules:
                    import_modules.add(alias.asname or alias.name.split(".")[0])
                if alias.name == "sys":
                    sys_names.add(alias.asname or alias.name)
        elif isinstance(node, ast.ImportFrom):
            if node.module and node.module.split(".")[0] in import_modules:
                dynamic_names.update(alias.asname or alias.name for alias in node.names)
            if node.module == "sys" and any(alias.name in {"path", "meta_path", "path_hooks", "modules"} for alias in node.names):
                issues.add("python-import-environment-dynamic")
    for node in nodes:
        if isinstance(node, ast.Import):
            imports.extend({"module": alias.name, "level": 0, "names": []} for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            imports.append({"module": node.module or "", "level": node.level, "names": [alias.name for alias in node.names]})
        # Reading a known loader as a value can pass it through reflection,
        # aliases, containers or opaque functions. Its later use is not static.
        # Import declarations alone do not read that value and remain supported.
        elif isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load) and (node.id in dynamic_names or node.id in import_modules):
            issues.add("python-dynamic-import")
        elif isinstance(node, ast.Attribute):
            if node.attr in {"__import__", "import_module", "exec_module", "load_module", "find_spec", "spec_from_file_location"}:
                issues.add("python-dynamic-import")
            if isinstance(node.value, ast.Name) and node.value.id in sys_names and node.attr in {"path", "meta_path", "path_hooks", "modules"}:
                issues.add("python-import-environment-dynamic")
        if len(imports) > MAX_IMPORTS:
            imports = imports[:MAX_IMPORTS]
            issues.add("python-import-limit")
            break
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            exports.add(node.name)
            if node.name == "__getattr__":
                issues.add("python-dynamic-exports")
        elif isinstance(node, (ast.Import, ast.ImportFrom)):
            exports.update(alias.asname or alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, (ast.Assign, ast.AnnAssign)):
            targets = node.targets if isinstance(node, ast.Assign) else [node.target]
            for target in targets:
                exports.update(item.id for item in ast.walk(target) if isinstance(item, ast.Name))
    result.update(imports=imports, exports=sorted(exports)[:MAX_IMPORTS], issues=sorted(issues))
    return result


def main():
    if sys.version_info < (3, 8):
        return 2
    raw = sys.stdin.buffer.read(MAX_INPUT + 1)
    if len(raw) > MAX_INPUT:
        return 2
    request = json.loads(raw.decode("utf-8"))
    if request.get("version") != 1 or not isinstance(request.get("files"), list):
        return 2
    files = []
    for item in request["files"]:
        if not isinstance(item.get("text"), str) or len(item["text"].encode("utf-8")) > MAX_SOURCE:
            return 2
        files.append({"path": item["path"], **extract(item["text"])})
    # ASCII JSON keeps the wire encoding independent of the host console locale.
    output = json.dumps({"version": 1, "files": files}, ensure_ascii=True, separators=(",", ":"))
    if len(output) > MAX_INPUT:
        return 2
    sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    try:
        exit_code = main()
    except (UnicodeError, ValueError, KeyError, TypeError, RecursionError, MemoryError):
        exit_code = 2
    sys.exit(exit_code)
