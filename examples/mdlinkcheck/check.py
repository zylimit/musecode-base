#!/usr/bin/env python3
"""mdlinkcheck: report broken relative links in markdown trees.

Scope: file existence only (no anchor validation, no network).
Usage: python3 check.py [DIR]   (default: current directory)
Exit: 0 clean / 1 broken links / 2 usage error.
Example product built with this scaffold (dogfood); not distributed.
"""
import os
import re
import sys

LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
CODE_SPAN = re.compile(r"`[^`]*`")
SKIP = ("http://", "https://", "mailto:", "data:", "#")


def check_file(path):
    broken = []
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            line = CODE_SPAN.sub("", line)
            for m in LINK.finditer(line):
                target = m.group(1)
                if target.startswith(SKIP):
                    continue
                target = target.split("#")[0].split("?")[0]
                if not target:
                    continue
                full = os.path.normpath(os.path.join(os.path.dirname(path), target))
                if not os.path.exists(full):
                    broken.append(f"{path}:{n}: {target}")
    return broken


def main(argv):
    if len(argv) > 2 or (len(argv) == 2 and argv[1] in ("-h", "--help")):
        print(__doc__.strip().splitlines()[4])
        return 0 if len(argv) == 2 else 2
    root = argv[1] if len(argv) == 2 else "."
    if not os.path.isdir(root):
        print(f"mdlinkcheck: not a directory: {root}", file=sys.stderr)
        return 2
    broken = []
    for dirpath, _, files in os.walk(root):
        for name in sorted(files):
            if name.endswith(".md"):
                broken.extend(check_file(os.path.join(dirpath, name)))
    for line in broken:
        print(line)
    if broken:
        print(f"mdlinkcheck: {len(broken)} broken links")
        return 1
    print("mdlinkcheck: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
