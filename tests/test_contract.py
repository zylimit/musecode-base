"""Contract tests for the musecode-base scaffold (stdlib only).

Run: python3 -m unittest discover -s tests
or:   pytest -q  (if installed; verify.sh prefers pytest)
"""
import json
import os
import subprocess
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(cmd, **kw):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, **kw)


class TestScaffoldContract(unittest.TestCase):
    def test_smoke_green(self):
        r = run(["bash", "scripts/smoke.sh"])
        self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)
        self.assertIn("ALL SMOKE CHECKS PASSED", r.stdout)

    def test_scripts_bash_syntax(self):
        import glob as _glob
        paths = [f"scripts/{n}" for n in os.listdir(os.path.join(ROOT, "scripts"))
                 if n.endswith(".sh")]
        paths.append("setup.sh")
        for sub in ("skills", "parts"):
            paths += [os.path.relpath(p, ROOT) for p in
                      _glob.glob(os.path.join(ROOT, ".agents", sub, "*",
                                              "scripts", "*.sh"))]
        for p in paths:
            r = run(["bash", "-n", p])
            self.assertEqual(r.returncode, 0, msg=p)

    def test_scripts_help_contract(self):
        for script, flag in [("verify.sh", "--help"), ("check.sh", "--help"),
                             ("fitness.sh", "--help"), ("arch-check.sh", "--help"),
                             ("manifest.sh", "--help")]:
            r = run(["bash", f"scripts/{script}", flag])
            self.assertEqual(r.returncode, 0, msg=script)
        r = run(["bash", "scripts/verify.sh", "--nope"])
        self.assertEqual(r.returncode, 1)

    def test_templates_nonempty(self):
        for p in ["docs/ADR_TEMPLATE.md", "docs/REQUIREMENTS_TEMPLATE.md",
                  "docs/PLAN_TEMPLATE.md",
                  ".agents/parts/_template/SKILL.md",
                  ".agents/feedback/templates/feedback-topic-template.md"]:
            fp = os.path.join(ROOT, p)
            self.assertTrue(os.path.isfile(fp), msg=p)
            self.assertGreater(os.path.getsize(fp), 0, msg=p)

    def test_skill_lint_passes(self):
        r = run(["bash", "scripts/skill-lint.sh"])
        self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)

    # 已删：test_skill_count（锁死数量会惩罚正确删除）、test_adopted_docs_present
    # （存在性已有 smoke 覆盖，安装完整性已有 test_issue_probes 行为覆盖）。

    def test_no_forbidden_skills_path(self):
        # ADR-0001: .muse/skills must never be reborn.
        self.assertFalse(os.path.exists(os.path.join(ROOT, ".muse", "skills")))

    def test_skills_structure(self):
        base = os.path.join(ROOT, ".agents", "skills")
        for entry in os.listdir(base):
            d = os.path.join(base, entry)
            if not os.path.isdir(d):
                continue
            sk = os.path.join(d, "SKILL.md")
            self.assertTrue(os.path.isfile(sk), msg=entry)
            text = open(sk, encoding="utf-8").read()
            for section in ["## 步骤", "## 约束与红线", "## 验收"]:
                self.assertIn(section, text, msg=f"{entry}/{section}")

    def test_hooks_example_valid_json(self):
        fp = os.path.join(ROOT, ".muse", "hooks.json.example")
        json.load(open(fp, encoding="utf-8"))

    def test_catalog_example_valid_json(self):
        fp = os.path.join(ROOT, ".agents", "harness", "module-catalog.example.json")
        cat = json.load(open(fp, encoding="utf-8"))
        self.assertEqual(cat["version"], 1)
        self.assertTrue(cat["modules"])

    def test_manifest_consistent(self):
        r = run(["bash", "scripts/manifest.sh", "--check"])
        self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)

    def test_predev_lint_clean_on_repo(self):
        # pytest runs predev-lint on repo root: framework guides must not
        # collide with the REQ-/DESIGN-/ARCH-/DFX- artifact namespaces.
        import shutil as _shutil
        if _shutil.which("node") is None:
            self.skipTest("node absent")
        r = run(["node", "scripts/predev-lint.mjs"])
        self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)

    def test_check_self_adr(self):
        r = run(["bash", "scripts/check.sh"])
        self.assertIn(r.returncode, (0, 3), msg=r.stdout + r.stderr)

    def test_arch_check_degraded_without_catalog(self):
        if os.path.exists(os.path.join(ROOT, ".agents", "harness", "module-catalog.json")):
            self.skipTest("catalog present")
        r = run(["bash", "scripts/arch-check.sh"])
        self.assertEqual(r.returncode, 3)

    def test_workflow_example_syntax(self):
        fp = os.path.join(ROOT, ".agents", "workflows", "review-change.js")
        self.assertTrue(os.path.isfile(fp))
        try:
            r = run(["node", "--check", fp])
        except FileNotFoundError:
            self.skipTest("node absent")
        self.assertEqual(r.returncode, 0, msg=r.stderr)


if __name__ == "__main__":
    unittest.main()
