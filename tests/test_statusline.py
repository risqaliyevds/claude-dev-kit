#!/usr/bin/env python3
"""Unit + end-to-end tests for plugins/core/statusline/statusline.py."""
import importlib.util
import json
import pathlib
import subprocess
import sys
import unittest

sys.dont_write_bytecode = True  # keep __pycache__ out of the plugin tree

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "plugins/core/statusline/statusline.py"
spec = importlib.util.spec_from_file_location("statusline", SCRIPT)
sl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sl)


def run(stdin: str):
    return subprocess.run(
        [sys.executable, str(SCRIPT)], input=stdin, capture_output=True, text=True, timeout=10
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
        # The gauge is exactly 10 cells and the palette is the ANSI
        # green/yellow/red traffic light — user-visible contract, not
        # implementation detail: changing either must fail this suite.
        self.assertEqual(sl.BARS, 10)
        self.assertEqual(
            (sl.GREEN, sl.YELLOW, sl.RED, sl.DIM),
            ("\033[32m", "\033[33m", "\033[31m", "\033[2m"),
        )

    def test_bar_fill_and_clamping(self):
        self.assertIn("░" * 10, sl.bar(0))
        self.assertIn("█" * 10, sl.bar(100))
        self.assertIn("█" * 10, sl.bar(250))  # clamped high
        self.assertIn("░" * 10, sl.bar(-5))  # clamped low
        self.assertIn("█" * 5 + "░" * 5, sl.bar(50))  # exactly proportional
        self.assertIn("█" * 3 + "░" * 7, sl.bar(30))
        self.assertEqual(sl.bar(None), sl.DIM + "─" * 10 + sl.RESET)

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
        for piece in ["Fable 5", "12%", "85%", "80k/200k", "↻", "📊", "📅", "CTX"]:
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
            f"CTX: {G}█░░░░░░░░░{X} {G}8%{X} 17k/200k • "
            f"📊 HL: {G}██░░░░░░░░{X} {G}24%{X} ↻ now • "
            f"📅 WL: {G}████░░░░░░{X} {G}41%{X} ↻ now"
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
