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
        paths += [os.path.relpath(p, ROOT) for p in
                  _glob.glob(os.path.join(ROOT, ".agents", "skills", "*",
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
                  ".agents/skills/_template/SKILL.md",
                  ".agents/feedback/templates/feedback-topic-template.md"]:
            fp = os.path.join(ROOT, p)
            self.assertTrue(os.path.isfile(fp), msg=p)
            self.assertGreater(os.path.getsize(fp), 0, msg=p)

    def test_skill_lint_passes(self):
        r = run(["bash", "scripts/skill-lint.sh"])
        self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)

    def test_skill_count(self):
        base = os.path.join(ROOT, ".agents", "skills")
        skills = [e for e in os.listdir(base)
                  if os.path.isdir(os.path.join(base, e)) and not e.startswith("_")]
        self.assertEqual(len(skills), 19, msg=sorted(skills))
        for e in skills:
            text = open(os.path.join(base, e, "SKILL.md"), encoding="utf-8").read()
            self.assertIn("## Donor 出处", text, msg=e)

    def test_adopted_docs_present(self):
        for p in ["docs/UI-QUALITY-FLOOR.md", "docs/DESIGN_VOCABULARY.md",
                  ".agents/rules/domain-rulings.md",
                  ".agents/feedback/FEEDBACK-INDEX.md",
                  ".agents/skills/red-blue-review/scripts/evidence.sh"]:
            self.assertTrue(os.path.isfile(os.path.join(ROOT, p)), msg=p)

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

    def test_ci_arch_gate_tolerates_rc3(self):
        # gate.yml runs steps under `bash -e`: the arch-gate block must swallow
        # rc=3 (no catalog) itself instead of tripping errexit. Execute the real
        # block from the workflow file.
        text = open(os.path.join(ROOT, ".github", "workflows", "gate.yml"),
                     encoding="utf-8").read().splitlines()
        try:
            i = next(n for n, l in enumerate(text) if "name: arch gate" in l)
            j = next(n for n in range(i, len(text)) if text[n].strip() == "run: |")
        except StopIteration:
            self.fail("arch gate run block not found in gate.yml")
        body = []
        for line in text[j + 1:]:
            if line.strip().startswith("- ") or (line and not line[0].isspace()):
                break
            body.append(line)
        self.assertTrue(body, msg="empty arch gate block")
        indent = min(len(l) - len(l.lstrip()) for l in body if l.strip())
        script = "\n".join(l[indent:] for l in body)
        r = run(["bash", "-e", "-c", script])
        self.assertEqual(r.returncode, 0, msg=script + "\n" + r.stdout + r.stderr)

    def test_predev_lint_clean_on_repo(self):
        # CI gate.yml runs predev-lint on repo root: framework guides must not
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
