#!/usr/bin/env python3
"""Unit + end-to-end tests for plugins/core/statusline/statusline.py."""
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True  # keep __pycache__ out of the plugin tree

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "plugins/core/statusline/statusline.py"
spec = importlib.util.spec_from_file_location("statusline", SCRIPT)
sl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sl)


def run(stdin: str, config_dir=None):
    # CLAUDE_CONFIG_DIR points the WLF lookup at an empty sandbox: no
    # credentials -> no network -> deterministic "—", exactly like a machine
    # without a claude.ai login (or a Keychain-only macOS).
    env = dict(os.environ, CLAUDE_CONFIG_DIR=config_dir or tempfile.mkdtemp())
    return subprocess.run(
        [sys.executable, str(SCRIPT)], input=stdin, capture_output=True, encoding="utf-8",
        timeout=10, env=env,
    )


class TestHelpers(unittest.TestCase):
    def test_color_thresholds(self):
        self.assertEqual(sl.color_for(None), sl.DIM)
        self.assertEqual(sl.color_for(0), sl.GREEN)
        self.assertEqual(sl.color_for(49.9), sl.GREEN)
        self.assertEqual(sl.color_for(50), sl.YELLOW)
        self.assertEqual(sl.color_for(79.9), sl.YELLOW)
        self.assertEqual(sl.color_for(80), sl.RED)
        self.assertEqual(sl.color_for(100), sl.RED)

    def test_contract_constants(self):
        # The palette is the ANSI green/yellow/red traffic light — user-visible
        # contract, not implementation detail: changing it must fail this suite.
        self.assertEqual(
            (sl.GREEN, sl.YELLOW, sl.RED, sl.DIM),
            ("\033[32m", "\033[33m", "\033[31m", "\033[2m"),
        )

    def test_pctstr(self):
        self.assertEqual(sl.pctstr(None), "—")
        self.assertIn("42%", sl.pctstr(42))
        self.assertIn("43%", sl.pctstr(42.6))  # rounds

    def test_num_coercion(self):
        self.assertEqual(sl.num("45"), 45.0)
        self.assertIsNone(sl.num("n/a"))
        self.assertIsNone(sl.num(None))
        self.assertIsNone(sl.num([1, 2]))

    def test_reset_str(self):
        now = 1_000_000
        self.assertEqual(sl.reset_str(None, now), "")
        self.assertEqual(sl.reset_str(0, now), "")
        self.assertEqual(sl.reset_str("2026-07-06T12:00:00Z", now), "")  # non-epoch: no crash
        self.assertEqual(sl.reset_str(now - 5, now), "now")
        self.assertEqual(sl.reset_str(now, now), "now")
        self.assertEqual(sl.reset_str(now + 2 * 86400 + 3 * 3600, now), "2d 3h")
        self.assertEqual(sl.reset_str(now + 3 * 3600 + 20 * 60, now), "3h 20m")
        self.assertEqual(sl.reset_str(now + 59, now), "0h 0m")

    def test_tok(self):
        self.assertEqual(sl.tok(None), "—")
        self.assertEqual(sl.tok(0), "0")
        self.assertEqual(sl.tok(999), "999")
        self.assertEqual(sl.tok(1_000), "1k")
        self.assertEqual(sl.tok(73_711), "74k")
        self.assertEqual(sl.tok(1_000_000), "1M")
        self.assertEqual(sl.tok(1_500_000), "1.5M")


class TestFableWeekly(unittest.TestCase):
    """WLF = the per-model weekly Fable window. Claude Code does not pass it on
    stdin, so the script fetches /api/oauth/usage itself (OAuth token from the
    credentials file) and caches the answer."""

    USAGE = {
        "limits": [
            {"kind": "weekly_all", "percent": 5, "resets_at": "2026-09-10T21:59:59+00:00", "scope": None},
            {"kind": "weekly_scoped", "percent": 7, "resets_at": "2026-09-10T21:59:59+00:00",
             "scope": {"model": {"display_name": "Fable"}}},
        ]
    }

    def setUp(self):
        self.dir = pathlib.Path(tempfile.mkdtemp())
        self.cache = self.dir / "statusline-cache" / "fable.json"

    def creds(self):
        (self.dir / ".credentials.json").write_text(
            json.dumps({"claudeAiOauth": {"accessToken": "tok"}}), encoding="utf-8"
        )

    def test_extracts_fable_window(self):
        pct, reset = sl.fable_window(self.USAGE)
        self.assertEqual(pct, 7.0)
        self.assertAlmostEqual(reset, 1789077599, delta=1)  # 2026-09-10T21:59:59Z

    def test_absent_window_is_none(self):
        self.assertEqual(sl.fable_window({"limits": []}), (None, None))
        self.assertEqual(sl.fable_window({}), (None, None))
        self.assertEqual(sl.fable_window("garbage"), (None, None))

    def test_no_credentials_no_fetch(self):
        calls = []
        pct, _ = sl.fable_weekly(self.dir, fetch=lambda tok: calls.append(tok) or self.USAGE)
        self.assertIsNone(pct)
        self.assertEqual(calls, [])  # never hits the network without a token

    def test_fetch_and_cache(self):
        self.creds()
        calls = []
        fetch = lambda tok: calls.append(tok) or self.USAGE
        self.assertEqual(sl.fable_weekly(self.dir, fetch=fetch)[0], 7.0)
        self.assertEqual(calls, ["tok"])
        self.assertTrue(self.cache.exists())
        # Second call within the TTL is served from cache: one fetch total.
        self.assertEqual(sl.fable_weekly(self.dir, fetch=fetch)[0], 7.0)
        self.assertEqual(calls, ["tok"])

    def test_stale_cache_survives_fetch_failure(self):
        self.creds()
        sl.fable_weekly(self.dir, fetch=lambda tok: self.USAGE)
        os.utime(self.cache, (1, 1))  # expire it

        def boom(tok):
            raise OSError("network down")

        self.assertEqual(sl.fable_weekly(self.dir, fetch=boom)[0], 7.0)  # stale beats blank

    def test_e2e_renders_wlf_from_cache(self):
        self.cache.parent.mkdir(parents=True)
        self.cache.write_text(json.dumps(self.USAGE), encoding="utf-8")
        r = run("{}", config_dir=str(self.dir))
        self.assertEqual(r.returncode, 0)
        self.assertIn("WLF: \033[32m7%\033[0m", r.stdout)


class TestEndToEnd(unittest.TestCase):
    def test_full_payload(self):
        far_future = 4_000_000_000  # any run date: still in the future
        payload = {
            "model": {"display_name": "Fable 5"},
            "context_window": {
                "used_percentage": 40,
                "context_window_size": 200_000,
                "current_usage": {"input_tokens": 73_711, "cache_read": 6_289},
            },
            "rate_limits": {
                "five_hour": {"used_percentage": 12, "resets_at": far_future},
                "seven_day": {"used_percentage": 85, "resets_at": far_future},
            },
        }
        r = run(json.dumps(payload))
        self.assertEqual(r.returncode, 0)
        for piece in ["Fable 5", "12%", "85%", "(200k)", "↻", "📊", "📅", "CTX"]:
            self.assertIn(piece, r.stdout)
        self.assertIn("\033[32m", r.stdout)  # 12% renders green...
        self.assertIn("\033[31m", r.stdout)  # ...and 85% renders red, end to end

    def test_never_breaks(self):
        # The line must render with exit 0 whatever stdin holds — including
        # schema drift: wrong types where the docs promise objects/numbers.
        payloads = [
            "",
            "not json {",
            "{}",
            "[1, 2, 3]",
            '"just a string"',
            '{"rate_limits": null}',
            '{"rate_limits": "unavailable"}',
            '{"context_window": "n/a"}',
            '{"rate_limits": {"five_hour": [1, 2]}}',
            '{"context_window": {"current_usage": 42}}',
            '{"rate_limits": {"five_hour": {"used_percentage": "n/a"}}}',
            '{"rate_limits": {"five_hour": {"used_percentage": 45, "resets_at": "2026-07-06T12:00:00Z"}}}',
        ]
        for stdin in payloads:
            r = run(stdin)
            self.assertEqual(r.returncode, 0, f"crashed on stdin={stdin!r}\n{r.stderr}")
            self.assertIn("🧠 Model: Claude", r.stdout)
            self.assertIn("—", r.stdout)  # em-dash fallback for absent data
            self.assertNotIn("█", r.stdout)  # plain percentages, no gauges

    def test_string_numbers_still_render(self):
        r = run('{"rate_limits": {"five_hour": {"used_percentage": "45"}}}')
        self.assertEqual(r.returncode, 0)
        self.assertIn("45%", r.stdout)

    def test_docs_example_payload_golden(self):
        # The docs' documented example payload must render this exact line.
        # Schema drift on Anthropic's side = update the fixture deliberately;
        # format drift on our side = update this expected string deliberately.
        fixture = pathlib.Path(__file__).resolve().parent / "fixtures/statusline_payload.json"
        r = run(fixture.read_text(encoding="utf-8"))
        G, X = "\033[32m", "\033[0m"
        expected = (
            "🧠 Model: Sonnet 5 • "
            f"CTX: {G}8%{X} (200k) • "
            f"📊 HL: {G}24%{X} ↻ now • "
            f"📅 WL: {G}41%{X} ↻ now • "
            "🔮 WLF: —"
        )
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), expected)

    def test_windows_independently_absent(self):
        payload = {"rate_limits": {"five_hour": {"used_percentage": 30}}}
        r = run(json.dumps(payload))
        self.assertEqual(r.returncode, 0)
        self.assertIn("30%", r.stdout)
        self.assertIn("—", r.stdout)  # seven_day absent → em-dash
        self.assertNotIn("↻", r.stdout)  # no resets_at anywhere


if __name__ == "__main__":
    unittest.main()
