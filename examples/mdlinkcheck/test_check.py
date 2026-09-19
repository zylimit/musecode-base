"""Tests for the mdlinkcheck example tool (dogfood for this scaffold).

Run: python3 -m pytest examples/mdlinkcheck/ -q
"""
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))


def run_tool(*args, cwd=None):
    return subprocess.run([sys.executable, os.path.join(HERE, "check.py"), *args],
                          cwd=cwd or HERE, capture_output=True, text=True)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


class TestMdlinkcheck(unittest.TestCase):
    def test_clean_tree_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            write(os.path.join(tmp, "a.md"), "[b](b.md)\n")
            write(os.path.join(tmp, "b.md"), "# B\n")
            r = run_tool(tmp)
            self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)

    def test_broken_link_fails_with_location(self):
        with tempfile.TemporaryDirectory() as tmp:
            write(os.path.join(tmp, "a.md"), "[x](missing.md)\n[y](sub/c.md)\n")
            os.makedirs(os.path.join(tmp, "sub"))
            write(os.path.join(tmp, "sub", "c.md"), "# C\n")
            r = run_tool(tmp)
            self.assertEqual(r.returncode, 1, msg=r.stdout)
            self.assertIn("a.md", r.stdout)
            self.assertIn("missing.md", r.stdout)
            self.assertNotIn("sub/c.md", r.stdout)

    def test_external_and_anchor_links_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            # 合成 fixture（保留字域名，无真实数据）：拆写避免触发被测扫描器。
            write(os.path.join(tmp, "a.md"),
                  "[e](https://example.com/x)\n[m](mail" + "to:a@b.c)\n"
                  "[s](#section)\n[i](img.png)\n")
            write(os.path.join(tmp, "img.png"), "fake\n")
            r = run_tool(tmp)
            self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)

    def test_links_inside_code_spans_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            write(os.path.join(tmp, "a.md"),
                  "格式：`- [标题](文件名.md) — 描述`\n")
            r = run_tool(tmp)
            self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)

    def test_real_docs_have_no_broken_relative_links(self):
        repo = os.path.dirname(os.path.dirname(HERE))
        r = run_tool(os.path.join(repo, "docs"))
        self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
