#!/usr/bin/env python3
"""Tests for skills/grill-me/scripts/translate.py. No network: urlopen is faked.

A live check against the real API runs only when GEMINI_API_KEY is set.
"""
import importlib.util
import io
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest
import urllib.error
from email.message import Message
from unittest import mock

SCRIPT = (
    pathlib.Path(__file__).resolve().parents[1]
    / "plugins/core/skills/grill-me/scripts/translate.py"
)
spec = importlib.util.spec_from_file_location("translate", SCRIPT)
assert spec and spec.loader
tr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tr)

CFG = {"GEMINI_API_KEY": "k-123"}


class Resp:
    def __init__(self, payload):
        self.raw = json.dumps(payload).encode()

    def read(self, *_):
        return self.raw

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False


def gemini(text):
    return Resp({"candidates": [{"content": {"parts": [{"text": text}]}}]})


def http_error(code, message="boom"):
    body = io.BytesIO(json.dumps({"error": {"message": message}}).encode())
    return urllib.error.HTTPError("https://x", code, "err", Message(), body)


class Sandbox(unittest.TestCase):
    """Private config dir, no GEMINI_*/GRILL_ME_* in the environment, no sleeping."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        env = mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": tmp.name})
        env.start()
        self.addCleanup(env.stop)
        for key in tr.SETTINGS:
            os.environ.pop(key, None)
        sleep = mock.patch.object(tr.time, "sleep")
        sleep.start()
        self.addCleanup(sleep.stop)
        self.env = pathlib.Path(tmp.name) / ".env"


class TestMask(unittest.TestCase):
    def test_code_and_urls_are_cut_out_and_trailing_punctuation_stays(self):
        text = "Run `pytest -q` then see https://a.com/x. Or:\n```py\nx = 1\n```\nDone."
        masked, spans = tr.mask(text)
        for secret in ("pytest", "a.com", "x = 1"):
            self.assertNotIn(secret, masked)
        self.assertEqual(spans, ["`pytest -q`", "https://a.com/x", "```py\nx = 1\n```"])
        self.assertIn("⟦1⟧.", masked)


class TestTranslate(Sandbox):
    def run_translate(self, text, replies, cfg=CFG):
        seen = []

        def fake(req, **_):
            seen.append(req)
            reply = replies[len(seen) - 1]
            if isinstance(reply, Exception):
                raise reply
            return reply

        with mock.patch.object(tr.urllib.request, "urlopen", fake):
            try:
                return tr.translate(text, cfg), seen
            except tr.Fail as e:
                return e, seen

    def test_request_contract(self):
        _, seen = self.run_translate("Hello `x`", [gemini("Salom ⟦0⟧")])
        req = seen[0]
        self.assertTrue(req.full_url.endswith("/models/gemini-3.5-flash:generateContent"))
        self.assertNotIn("k-123", req.full_url)  # key travels in a header only
        self.assertEqual(dict(req.header_items())["X-goog-api-key"], "k-123")
        body = json.loads(req.data)
        self.assertIn("Never translate", body["systemInstruction"]["parts"][0]["text"])
        self.assertEqual(body["contents"][0]["role"], "user")
        self.assertEqual(body["generationConfig"], {"thinkingConfig": {"thinkingLevel": "LOW"}})

    def test_model_can_be_overridden(self):
        _, seen = self.run_translate("Hi", [gemini("Salom")], {**CFG, "GEMINI_MODEL": "gemini-3.6-flash"})
        self.assertIn("/models/gemini-3.6-flash:generateContent", seen[0].full_url)

    def test_code_never_leaves_the_machine_and_comes_back_verbatim(self):
        out, seen = self.run_translate(
            "Set `retry_count` in https://x.dev/y now", [gemini("⟦0⟧ ni ⟦1⟧ da qoʻying")]
        )
        sent = json.loads(seen[0].data)["contents"][0]["parts"][0]["text"]
        self.assertNotIn("retry_count", sent)
        self.assertNotIn("x.dev", sent)
        self.assertEqual(out, "`retry_count` ni https://x.dev/y da qoʻying")

    def test_thought_parts_are_skipped(self):
        reply = Resp({"candidates": [{"content": {"parts": [{"text": "hmm", "thought": True}, {"text": "Salom"}]}}]})
        out, _ = self.run_translate("Hi", [reply])
        self.assertEqual(out, "Salom")

    def test_dropped_token_is_retried(self):
        out, seen = self.run_translate("See `a`", [gemini("Qarang"), gemini("Qarang ⟦0⟧")])
        self.assertEqual((out, len(seen)), ("Qarang `a`", 2))

    def test_dropped_token_twice_fails(self):
        out, seen = self.run_translate("See `a`", [gemini("Qarang"), gemini("Qarang")])
        self.assertIsInstance(out, tr.Fail)
        self.assertEqual(len(seen), 2)

    def test_invented_token_is_rejected(self):
        out, _ = self.run_translate("Hi", [gemini("Salom ⟦7⟧"), gemini("Salom ⟦7⟧")])
        self.assertIsInstance(out, tr.Fail)

    def test_permanent_error_fails_fast_with_the_api_message(self):
        out, seen = self.run_translate("Hi", [http_error(400, "API key not valid")])
        self.assertIsInstance(out, tr.Fail)
        self.assertIn("400", str(out))
        self.assertIn("API key not valid", str(out))
        self.assertNotIn("k-123", str(out))
        self.assertEqual(len(seen), 1)

    def test_rate_limit_and_network_errors_are_retried(self):
        replies = [http_error(429), urllib.error.URLError("reset"), gemini("Salom")]
        out, seen = self.run_translate("Hi", replies)
        self.assertEqual((out, len(seen)), ("Salom", 3))

    def test_persistent_server_error_gives_up_after_three_tries(self):
        out, seen = self.run_translate("Hi", [http_error(503)] * 3)
        self.assertIsInstance(out, tr.Fail)
        self.assertEqual(len(seen), 3)

    def test_empty_answer_is_an_error(self):
        out, _ = self.run_translate("Hi", [Resp({"candidates": [{"finishReason": "SAFETY"}]})])
        self.assertIn("SAFETY", str(out))


class TestConfig(Sandbox):
    def test_dotenv_parsing(self):
        self.env.write_bytes(
            b'\xef\xbb\xbf# comment\nGEMINI_API_KEY="abc"  # trailing\n\nGRILL_ME_UZ = 1\nnot a pair\n'
        )
        self.assertEqual(tr.read_env(self.env), {"GEMINI_API_KEY": "abc", "GRILL_ME_UZ": "1"})

    def test_process_env_wins_but_empty_does_not_mask_the_file(self):
        self.env.write_text("GEMINI_API_KEY=file\nGEMINI_MODEL=m1\n")
        os.environ["GEMINI_API_KEY"] = "proc"
        os.environ["GEMINI_MODEL"] = ""
        self.assertEqual(tr.config(), {"GEMINI_API_KEY": "proc", "GEMINI_MODEL": "m1"})

    def test_status(self):
        self.assertEqual(tr.status(tr.config()), "unset")
        for text, want in (("GRILL_ME_UZ=0", "off"), ("GRILL_ME_UZ=1\nGEMINI_API_KEY=k", "on"), ("GRILL_ME_UZ=true\nGEMINI_API_KEY=k", "on")):
            self.env.write_text(text)
            self.assertEqual(tr.status(tr.config()), want)
        self.env.write_text("GRILL_ME_UZ=1\nGEMINI_API_KEY=")
        broken = tr.status(tr.config())
        self.assertTrue(broken.startswith("broken:") and str(self.env) in broken)
        os.environ["GEMINI_API_KEY"] = "from-shell"  # a key in the shell satisfies it
        self.assertEqual(tr.status(tr.config()), "on")


class TestCli(Sandbox):
    def cli(self, *args, stdin=""):
        env = {k: v for k, v in os.environ.items() if k not in tr.SETTINGS}
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args], input=stdin, capture_output=True,
            encoding="utf-8", env=env, timeout=20,
        )

    def test_setup_yes_asks_for_a_key_and_is_idempotent(self):
        r = self.cli("--setup", "yes")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(str(self.env), r.stdout)
        self.assertIn("Paste your Gemini API key", r.stdout)
        self.assertEqual(self.env.read_text(), "GRILL_ME_UZ=1\nGEMINI_API_KEY=\n")
        self.assertTrue(self.cli("--status").stdout.startswith("broken:"))
        self.cli("--setup", "yes")
        self.assertEqual(self.env.read_text(), "GRILL_ME_UZ=1\nGEMINI_API_KEY=\n")

    def test_setup_never_overwrites_an_existing_key_or_other_settings(self):
        self.env.write_text("OTHER=1\nGEMINI_API_KEY=secret")  # no trailing newline
        r = self.cli("--setup", "yes")
        self.assertNotIn("Paste", r.stdout)
        self.assertEqual(self.env.read_text(), "OTHER=1\nGEMINI_API_KEY=secret\nGRILL_ME_UZ=1\n")
        self.assertEqual(self.cli("--status").stdout.strip(), "on")

    def test_setup_no_records_the_decline_and_keeps_the_key(self):
        self.cli("--setup", "no")
        self.assertEqual(self.env.read_text(), "GRILL_ME_UZ=0\n")
        self.env.write_text("GRILL_ME_UZ=1\nGEMINI_API_KEY=secret\n")
        self.cli("--setup", "no")
        self.assertIn("GEMINI_API_KEY=secret", self.env.read_text())
        self.assertEqual(self.cli("--status").stdout.strip(), "off")

    def test_missing_key_fails_clearly_even_with_non_ascii_stdin(self):
        for args in ((), ("--check",)):
            r = self.cli(*args, stdin="Savol — oʻzgartirish ⟦0⟧")
            self.assertEqual(r.returncode, 1)
            self.assertIn("GEMINI_API_KEY", r.stderr)
            self.assertNotIn("Traceback", r.stderr)

    def test_bad_usage(self):
        r = self.cli("--setup", "maybe")
        self.assertEqual(r.returncode, 1)
        self.assertIn("usage", r.stderr)


class TestEncoding(Sandbox):
    def test_main_reads_and_writes_utf8_whatever_the_console_codepage(self):
        stdin = io.TextIOWrapper(io.BytesIO("Savol — é".encode("utf-8")), encoding="ascii")
        stdout = io.TextIOWrapper(io.BytesIO(), encoding="ascii", newline="\n")
        with mock.patch.object(sys, "stdin", stdin), mock.patch.object(sys, "stdout", stdout), \
                mock.patch.object(tr, "config", return_value=CFG), \
                mock.patch.object(tr, "translate", return_value="Oʻzbekcha — ok") as t:
            self.assertEqual(tr.main([]), 0)
            stdout.flush()
            t.assert_called_once_with("Savol — é", CFG)
            self.assertEqual(stdout.buffer.getvalue().decode("utf-8"), "Oʻzbekcha — ok\n")


@unittest.skipUnless(os.environ.get("GEMINI_API_KEY"), "set GEMINI_API_KEY to hit the real API")
class TestLive(unittest.TestCase):
    def test_terms_and_names_stay_english_and_script_is_latin(self):
        out = tr.translate(
            "Should `retry_count` live in the Redis cache or in the PostgreSQL database? "
            "I recommend the database for durability.",
            {"GEMINI_API_KEY": os.environ["GEMINI_API_KEY"]},
        )
        for kept in ("`retry_count`", "Redis", "PostgreSQL"):
            self.assertIn(kept, out)
        self.assertFalse(re.search("[Ѐ-ӿ]", out), out)


if __name__ == "__main__":
    unittest.main()
