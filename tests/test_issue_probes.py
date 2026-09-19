"""Issue probes: one originally-failing case + one normal control per class.

Covers the Astra review remediation (items 1-4, 7). Each test builds an
isolated temp copy and consumes the real scripts (no mocks except stdin
simulation for pre-push and mock hosts for the workflow file).
Run: python3 -m pytest tests/test_issue_probes.py -q
"""
import json
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NEED_NODE = shutil.which("node") is None
NEED_GIT = shutil.which("git") is None


def run(cmd, cwd, **kw):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                          timeout=120, **kw)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


class TestInstallerContract(unittest.TestCase):
    def test_fresh_install_exits_zero_and_smoke_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = os.path.join(tmp, "empty")
            r = run(["bash", os.path.join(ROOT, "setup.sh"), target], cwd=ROOT)
            self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)
            self.assertNotIn("update=", r.stdout)
            for p in [".agents/rules/domain-rulings.md",
                      ".agents/feedback/FEEDBACK-INDEX.md",
                      ".agents/feedback/templates/feedback-topic-template.md",
                      ".agents/agents/implementer.md"]:
                self.assertTrue(os.path.isfile(os.path.join(target, p)), msg=p)
            s = run(["bash", "scripts/smoke.sh"], cwd=target)
            self.assertEqual(s.returncode, 0, msg=s.stdout + s.stderr[-2000:])

    def test_customized_target_keeps_customization_and_sidecar(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = os.path.join(tmp, "custom")
            os.makedirs(target)
            write(os.path.join(target, "AGENTS.md"), "我的定制\n")
            write(os.path.join(target, "README.md"), "旧版\n")
            write(os.path.join(target, "README.md.framework-new"), "旧sidecar\n")
            r = run(["bash", os.path.join(ROOT, "setup.sh"), target], cwd=ROOT)
            self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)
            self.assertEqual(open(os.path.join(target, "AGENTS.md"),
                                   encoding="utf-8").read(), "我的定制\n")
            self.assertEqual(open(os.path.join(target, "README.md.framework-new"),
                                   encoding="utf-8").read(), "旧sidecar\n")
            self.assertTrue(os.path.isfile(
                os.path.join(target, "AGENTS.md.framework-new")))


class TestFitnessSuppression(unittest.TestCase):
    def _fixture(self, tmp, body):
        os.makedirs(os.path.join(tmp, "scripts"))
        shutil.copy2(os.path.join(ROOT, "scripts", "fitness.sh"),
                     os.path.join(tmp, "scripts", "fitness.sh"))
        write(os.path.join(tmp, "src", "sample.js"), body)

    # NOTE: probe literals are concatenated so this file itself does not
    # trip the scanner under test (no real personal data anywhere here).
    _PII_LINE = "console.log(" + "phone" + "_number" + ");\n"
    _WRONG_MARK = ("// " + "musecode-fitness:ignore" + " no-unbounded-retry"
                   + ' reason="unrelated"\n')
    _RIGHT_MARK = ("// " + "musecode-fitness:ignore" + " no-pii-in-logs"
                   + ' reason="synthetic probe id"\n')

    def test_wrong_rule_does_not_suppress(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._fixture(tmp, self._WRONG_MARK + self._PII_LINE)
            r = run(["bash", "scripts/fitness.sh", "--paths", "src/sample.js"],
                    cwd=tmp)
            self.assertEqual(r.returncode, 1, msg=r.stdout)
            self.assertIn("no-pii-in-logs", r.stdout)

    def test_right_rule_suppresses(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._fixture(tmp, self._RIGHT_MARK + self._PII_LINE)
            r = run(["bash", "scripts/fitness.sh", "--paths", "src/sample.js"],
                    cwd=tmp)
            self.assertEqual(r.returncode, 0, msg=r.stdout)


@unittest.skipIf(NEED_GIT, "git absent")
class TestHookObjects(unittest.TestCase):
    def _hook_repo(self, tmp):
        run(["git", "init", "-q"], cwd=tmp, check=True)
        run(["git", "config", "user.email", "t@t"], cwd=tmp, check=True)
        run(["git", "config", "user.name", "t"], cwd=tmp, check=True)
        os.makedirs(os.path.join(tmp, "scripts", "githooks"))
        write(os.path.join(tmp, "scripts", "smoke.sh"), "#!/bin/bash\nexit 0\n")
        write(os.path.join(tmp, "scripts", "staged-check.sh"),
              "#!/bin/bash\nexit 0\n")
        shutil.copy2(os.path.join(ROOT, "scripts", "fitness.sh"),
                     os.path.join(tmp, "scripts", "fitness.sh"))
        shutil.copy2(os.path.join(ROOT, "scripts", "githooks", "pre-commit"),
                     os.path.join(tmp, "scripts", "githooks", "pre-commit"))

    def test_precommit_blocks_staged_violation_despite_clean_worktree(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._hook_repo(tmp)
            write(os.path.join(tmp, "src", "sample.js"),
                  TestFitnessSuppression._PII_LINE)
            run(["git", "add", "src/sample.js"], cwd=tmp, check=True)
            write(os.path.join(tmp, "src", "sample.js"), "const answer = 42;\n")
            r = run(["bash", "scripts/githooks/pre-commit"], cwd=tmp)
            self.assertEqual(r.returncode, 2, msg=r.stdout + r.stderr)

    def test_precommit_passes_clean_stage(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._hook_repo(tmp)
            write(os.path.join(tmp, "src", "sample.js"), "const answer = 42;\n")
            run(["git", "add", "src/sample.js"], cwd=tmp, check=True)
            r = run(["bash", "scripts/githooks/pre-commit"], cwd=tmp)
            self.assertEqual(r.returncode, 0, msg=r.stdout + r.stderr)

    def _push_repo(self, tmp):
        run(["git", "init", "-q"], cwd=tmp, check=True)
        run(["git", "config", "user.email", "t@t"], cwd=tmp, check=True)
        run(["git", "config", "user.name", "t"], cwd=tmp, check=True)
        os.makedirs(os.path.join(tmp, "scripts"))
        write(os.path.join(tmp, "scripts", "smoke.sh"),
              "#!/bin/bash\ntouch smoke-ran; exit 0\n")
        write(os.path.join(tmp, "scripts", "verify.sh"),
              "#!/bin/bash\ntouch verify-ran; exit 0\n")
        shutil.copy2(os.path.join(ROOT, "scripts", "githooks", "pre-push"),
                     os.path.join(tmp, "scripts", "pre-push"))
        write(os.path.join(tmp, "f.txt"), "base\n")
        run(["git", "add", "."], cwd=tmp, check=True)
        run(["git", "commit", "-qm", "base"], cwd=tmp, check=True)
        base = run(["git", "rev-parse", "HEAD"], cwd=tmp,
                   check=True).stdout.strip()
        run(["git", "checkout", "-qb", "codebr"], cwd=tmp, check=True)
        write(os.path.join(tmp, "app.js"), "code\n")
        run(["git", "add", "app.js"], cwd=tmp, check=True)
        run(["git", "commit", "-qm", "code"], cwd=tmp, check=True)
        code = run(["git", "rev-parse", "HEAD"], cwd=tmp,
                   check=True).stdout.strip()
        run(["git", "checkout", "-q", base], cwd=tmp, check=True)
        run(["git", "checkout", "-qb", "docsbr"], cwd=tmp, check=True)
        write(os.path.join(tmp, "NOTE.md"), "doc\n")
        run(["git", "add", "NOTE.md"], cwd=tmp, check=True)
        run(["git", "commit", "-qm", "docs"], cwd=tmp, check=True)
        docs = run(["git", "rev-parse", "HEAD"], cwd=tmp,
                   check=True).stdout.strip()
        return base, code, docs

    def test_prepush_multi_ref_runs_full_gates(self):
        with tempfile.TemporaryDirectory() as tmp:
            base, code, docs = self._push_repo(tmp)
            stdin = (f"refs/heads/codebr {code} refs/heads/codebr {base}\n"
                     f"refs/heads/docsbr {docs} refs/heads/docsbr {base}\n")
            r = run(["bash", "scripts/pre-push"], cwd=tmp, input=stdin)
            self.assertEqual(r.returncode, 0, msg=r.stderr)
            self.assertTrue(os.path.isfile(os.path.join(tmp, "smoke-ran")))
            self.assertTrue(os.path.isfile(os.path.join(tmp, "verify-ran")))

    def test_prepush_docs_only_skips_verify(self):
        with tempfile.TemporaryDirectory() as tmp:
            base, _, docs = self._push_repo(tmp)
            stdin = f"refs/heads/docsbr {docs} refs/heads/docsbr {base}\n"
            r = run(["bash", "scripts/pre-push"], cwd=tmp, input=stdin)
            self.assertEqual(r.returncode, 0, msg=r.stderr)
            self.assertTrue(os.path.isfile(os.path.join(tmp, "smoke-ran")))
            self.assertFalse(os.path.isfile(os.path.join(tmp, "verify-ran")))


class TestArchRelativeImports(unittest.TestCase):
    def _arch_repo(self, tmp, extra_modules=()):
        os.makedirs(os.path.join(tmp, "scripts"))
        for name in ("arch-check.sh", "python-imports.py"):
            shutil.copy2(os.path.join(ROOT, "scripts", name),
                         os.path.join(tmp, "scripts", name))
        mods = [{"id": "a", "paths": ["src/a/**"], "dependsOn": [],
                 "forbiddenDependencies": ["b"]},
                {"id": "b", "paths": ["src/b/**"], "dependsOn": []}]
        mods.extend(extra_modules)
        write(os.path.join(tmp, ".agents", "harness", "module-catalog.json"),
              json.dumps({"version": 1, "modules": mods}))

    def test_js_relative_forbidden_edge_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._arch_repo(tmp)
            write(os.path.join(tmp, "src", "a", "a.js"),
                  'import { b } from "../b/b.js";\nexport const a = b;\n')
            write(os.path.join(tmp, "src", "b", "b.js"), "export const b = 1;\n")
            r = run(["bash", "scripts/arch-check.sh", "--scan"], cwd=tmp)
            self.assertEqual(r.returncode, 1, msg=r.stdout)
            self.assertIn("FORBIDDEN_EDGE: a -> b at src/a/a.js", r.stdout)

    def test_python_relative_forbidden_edge_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._arch_repo(tmp)
            write(os.path.join(tmp, "src", "a", "a.py"), "from ..b import b\n")
            write(os.path.join(tmp, "src", "b", "b.py"), "value = 1\n")
            r = run(["bash", "scripts/arch-check.sh", "--scan"], cwd=tmp)
            self.assertEqual(r.returncode, 1, msg=r.stdout)
            self.assertIn("FORBIDDEN_EDGE: a -> b at src/a/a.py", r.stdout)

    def test_declared_relative_edge_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            mods = [{"id": "a", "paths": ["src/a/**"], "dependsOn": ["b"]},
                    {"id": "b", "paths": ["src/b/**"], "dependsOn": []}]
            os.makedirs(os.path.join(tmp, "scripts"))
            for name in ("arch-check.sh", "python-imports.py"):
                shutil.copy2(os.path.join(ROOT, "scripts", name),
                             os.path.join(tmp, "scripts", name))
            write(os.path.join(tmp, ".agents", "harness", "module-catalog.json"),
                  json.dumps({"version": 1, "modules": mods}))
            write(os.path.join(tmp, "src", "a", "a.js"),
                  'import { b } from "../b/b.js";\n')
            write(os.path.join(tmp, "src", "b", "b.js"), "export const b = 1;\n")
            r = run(["bash", "scripts/arch-check.sh", "--scan"], cwd=tmp)
            self.assertEqual(r.returncode, 0, msg=r.stdout)
            self.assertIn("edges=1", r.stdout)

    def test_beyond_top_reports_partial_without_fake_edge(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._arch_repo(tmp)
            write(os.path.join(tmp, "src", "a", "a.py"),
                  "from ...zzz import q\n")
            write(os.path.join(tmp, "src", "b", "b.py"), "value = 1\n")
            r = run(["bash", "scripts/arch-check.sh", "--scan"], cwd=tmp)
            self.assertEqual(r.returncode, 0, msg=r.stdout)
            self.assertIn("RELATIVE_BEYOND_TOP", r.stdout)
            self.assertIn("edges=0", r.stdout)


@unittest.skipIf(NEED_NODE, "node absent")
class TestWorkflowResultPassing(unittest.TestCase):
    RUNNER = r"""
import workflow from './review-change.js';
const R = (ref, data, err) => ({ ref, data, error_kind: err || null });
const good = (ref) => R(ref, { complete: true, evidence: ['x:1:y'], unresolved: [] });
const scenarios = {
  green: [[good('r1'), good('r2'), good('r3')],
          R('v', { complete: true, evidence: ['c'], unresolved: [] }),
          R('s', { complete: true, evidence: ['p'], unresolved: [] })],
  verifyFalse: [[good('r1'), good('r2'), good('r3')],
          R('v', { complete: false, evidence: [], unresolved: ['q1-open'] }),
          R('s', { complete: true, evidence: ['p'], unresolved: [] })],
};
const [reports, verify, synth] = scenarios[process.argv[2]];
const host = { parallel: async () => reports,
               agent: async ({ label }) => label === 'verify' ? verify : synth };
workflow(host).then((out) => console.log(JSON.stringify(out)));
"""

    def _run_scenario(self, name):
        with tempfile.TemporaryDirectory() as tmp:
            shutil.copy2(os.path.join(ROOT, ".agents", "workflows",
                                      "review-change.js"), tmp)
            write(os.path.join(tmp, "package.json"), '{"type":"module"}')
            write(os.path.join(tmp, "run.mjs"), self.RUNNER)
            r = run(["node", "run.mjs", name], cwd=tmp)
            self.assertEqual(r.returncode, 0, msg=r.stderr)
            return json.loads(r.stdout)

    def test_incomplete_verifier_yields_partial_with_unresolved(self):
        out = self._run_scenario("verifyFalse")
        self.assertEqual(out["status"], "partial")
        self.assertIn("verification-incomplete", out["unresolved"])
        self.assertIn("verify:q1-open", out["unresolved"])

    def test_all_green_yields_complete(self):
        out = self._run_scenario("green")
        self.assertEqual(out["status"], "complete")
        self.assertEqual(out["unresolved"], [])


class TestTierUnwritableState(unittest.TestCase):
    def test_blocked_state_dir_fails_explicitly(self):
        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, "scripts"))
            shutil.copy2(os.path.join(ROOT, "scripts", "tier.sh"),
                         os.path.join(tmp, "scripts", "tier.sh"))
            os.makedirs(os.path.join(tmp, ".agents"))
            write(os.path.join(tmp, ".agents", "harness-state"),
                  "blocker file, not a dir\n")
            r = run(["bash", "scripts/tier.sh", "off"], cwd=tmp)
            self.assertEqual(r.returncode, 2, msg=r.stdout + r.stderr)
            self.assertIn("状态不可写", r.stderr)

    def test_normal_off_succeeds(self):
        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, "scripts"))
            shutil.copy2(os.path.join(ROOT, "scripts", "tier.sh"),
                         os.path.join(tmp, "scripts", "tier.sh"))
            r = run(["bash", "scripts/tier.sh", "off"], cwd=tmp)
            self.assertEqual(r.returncode, 0, msg=r.stderr)
            self.assertTrue(os.path.isfile(
                os.path.join(tmp, ".agents", "harness-state", "tier.json")))


if __name__ == "__main__":
    unittest.main()
