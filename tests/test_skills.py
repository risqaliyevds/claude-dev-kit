#!/usr/bin/env python3
"""Skills and agents: structure, always-on budget, and the agentic-workflow contracts.

Skill bodies are prose, so the contract is pinned by the phrases that carry
each safety rule (never merge, caps on unattended runs, no skipped
permissions). Rewording a rule means updating its phrase here on purpose.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
CORE = ROOT / "plugins/core"
# Every description is listed in the system prompt of every session (manual-only
# ones too, unless Claude Code drops them). Measured 4598 chars on 2026-11-02;
# raise this only after checking the cost with `claude plugin details core@dev-kit`.
DESCRIPTION_BUDGET_CHARS = 5200


def frontmatter(path):
    text = path.read_text(encoding="utf-8")
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    assert m, f"{path} has no frontmatter"
    return m.group(1), text


def field(fm, key):
    m = re.search(rf"^{key}:\s*(.+)$", fm, re.M)
    return m.group(1).strip() if m else None


def flat(text):
    return re.sub(r"\s+", " ", text)


def skill(name):
    return flat(frontmatter(CORE / "skills" / name / "SKILL.md")[1])


class TestStructure(unittest.TestCase):
    def test_every_skill_and_agent_is_well_formed(self):
        for d in sorted((CORE / "skills").iterdir()):
            if not d.is_dir():
                continue
            fm, _ = frontmatter(d / "SKILL.md")
            self.assertEqual(field(fm, "name"), d.name, d)
            self.assertTrue(field(fm, "description"), d)
        for f in sorted((CORE / "agents").glob("*.md")):
            fm, _ = frontmatter(f)
            self.assertEqual(field(fm, "name"), f.stem, f)
            self.assertTrue(field(fm, "description"), f)

    def test_always_on_descriptions_stay_within_budget(self):
        files = [*(CORE / "skills").glob("*/SKILL.md"), *(CORE / "agents").glob("*.md")]
        total = sum(len(field(frontmatter(f)[0], "description") or "") for f in files)
        self.assertLessEqual(total, DESCRIPTION_BUDGET_CHARS, "kit's always-on surface grew; trim descriptions")

    def test_manual_only_skills_and_the_model_invocable_ship(self):
        for name in ("plan", "learn", "overnight", "firstmate"):
            fm, _ = frontmatter(CORE / "skills" / name / "SKILL.md")
            self.assertEqual(field(fm, "disable-model-invocation"), "true", name)
        # Background crewmates invoke /core:ship themselves, so it must stay invocable.
        fm, _ = frontmatter(CORE / "skills/ship/SKILL.md")
        self.assertIsNone(field(fm, "disable-model-invocation"))


class TestWorkflowContracts(unittest.TestCase):
    def test_ship_pipeline(self):
        text = skill("ship")
        for phrase in (
            "Continue only if the user, or the prompt that started this session, asked",
            # Push-to-main needs an exact opt-in line; anything else, or doubt, means a PR.
            "grep -qxF 'Ship: main' AGENTS.md CLAUDE.md",
            "whenever in doubt, branch + PR",
            "core:code-reviewer",
            "At most 3 rounds",
            "end to end",
            "tmp/ship/",
            "AskUserQuestion",
            "gh pr checks <pr> --watch",
            "gh run watch <id> --exit-status",
            "--force-with-lease",
            "Never force-push the default branch",
            "Never merge",
            "Never get a gate green by deleting, skipping or weakening a test",
        ):
            self.assertIn(phrase, text)
        for level in ("**low**", "**medium**", "**high**"):
            self.assertIn(level, text)

    def test_reviewer_returns_actionable_findings_and_risk(self):
        text = flat((CORE / "agents/code-reviewer.md").read_text(encoding="utf-8"))
        for phrase in (
            "you never edit files",
            "Trace at least one concrete input",
            "no independent oracle",
            "Report each defect class once",
            "[auto-fix|ask-user]",
            "Risk: low | medium | high",
            "Never invent findings",
        ):
            self.assertIn(phrase, text)

    def test_firstmate_uses_native_background_workers_safely(self):
        text = skill("firstmate")
        for phrase in (
            'claude --bg -w <slug> --permission-mode auto "<brief>"',
            "claude agents --json --all",
            "gives up after 4 hours",
            "never delete a worktree by hand unless",
            "claude logs <id>",
            "claude rm <id>",
            "At most 3 crewmates at a time",
            "run /core:ship with this intent",
            "Never pass `--dangerously-skip-permissions`",
            "You do not write product code",
        ):
            self.assertIn(phrase, text)

    def test_overnight_runs_are_capped_isolated_and_not_permission_skipping(self):
        raw = (CORE / "skills/overnight/SKILL.md").read_text(encoding="utf-8")
        self.assertRegex(raw, r"agentArgsOverride:\s*\n\s*claude:\s*\n\s*- --permission-mode\s*\n\s*- auto")
        text = flat(raw)
        for phrase in (
            "export GNHF_TELEMETRY=0",
            "gnhf --worktree --max-iterations",
            "--max-tokens",
            "--stop-when",
            "never fall back to skipping permissions silently",
            "never merge a gnhf branch wholesale",
        ):
            self.assertIn(phrase, text)

    def test_learn_is_gated_and_moves_conditional_rules_into_skills(self):
        text = skill("learn")
        for phrase in ("At most 5 edits per run", ".claude/skills/<kebab-name>/SKILL.md", "Apply only after I confirm"):
            self.assertIn(phrase, text)

    def test_plan_is_interactive_but_plan_md_stays_the_source_of_truth(self):
        text = skill("plan")
        for phrase in ("docs/plans/PLAN.md", "ArtifactComments", "`PLAN.md` stays the source of truth", "tmp/plans/<slug>.html", "offer `/core:ship`"):
            self.assertIn(phrase, text)

    def test_projects_get_the_loop_and_ignore_worker_worktrees(self):
        raw = (CORE / "skills/new-project/templates/AGENTS.md").read_text(encoding="utf-8")
        template = flat(raw)
        for phrase in ("## Maintaining this file", "end to end first", "/core:ship", "/core:learn", "the word Ship, a colon, a space and main"):
            self.assertIn(phrase, template)
        # A new project must default to PRs: the template explains the opt-in
        # without containing the opt-in line itself.
        self.assertNotIn("Ship: main", raw)
        for ignore in (CORE / "skills/new-project/templates/gitignore", ROOT / ".gitignore"):
            self.assertIn(".claude/worktrees/", ignore.read_text(encoding="utf-8").splitlines(), ignore)
        # This repo publishes every commit to main, so /core:ship must not open PRs here.
        self.assertIn("Ship: main", (ROOT / "AGENTS.md").read_text(encoding="utf-8").splitlines())


if __name__ == "__main__":
    unittest.main()
