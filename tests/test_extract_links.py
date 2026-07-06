#!/usr/bin/env python3
"""Tests for skills/report-verify/scripts/extract_links.py (run as a subprocess)."""
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPT = (
    pathlib.Path(__file__).resolve().parents[1]
    / "plugins/core/skills/report-verify/scripts/extract_links.py"
)


def run(*argv):
    return subprocess.run(
        [sys.executable, str(SCRIPT), *map(str, argv)], capture_output=True, text=True, timeout=10
    )


class TestExtractLinks(unittest.TestCase):
    def test_markdown_counts_dedup_and_cleanup(self):
        text = (
            "First https://a.com/x. then https://a.com/x again,\n"
            "escaped http://b.org/y?p=1&amp;q=2 and wrapped (https://c.net/z).\n"
        )
        with tempfile.TemporaryDirectory() as d:
            f = pathlib.Path(d) / "report.md"
            f.write_text(text, encoding="utf-8")
            r = run(f)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("TOTAL LINK OCCURRENCES: 4", r.stdout)
        self.assertIn("UNIQUE LINKS: 3", r.stdout)
        self.assertIn("DUPLICATED OCCURRENCES: 1", r.stdout)
        self.assertIn("http://b.org/y?p=1&q=2", r.stdout)  # &amp; unescaped
        self.assertIn("https://c.net/z", r.stdout)
        self.assertNotIn("https://c.net/z)", r.stdout)  # ')' not swallowed
        self.assertNotIn("https://a.com/x.", r.stdout)  # trailing '.' stripped
        for domain in ["a.com", "b.org", "c.net"]:
            # Exact domain line: counts UNIQUE links per domain (a.com has 2
            # occurrences but 1 unique link — the count must read 1).
            self.assertRegex(r.stdout, rf"(?m)^\s+1\s+{re.escape(domain)}$")

    def test_docx_links_read_from_zip_parts(self):
        with tempfile.TemporaryDirectory() as d:
            f = pathlib.Path(d) / "report.docx"
            with zipfile.ZipFile(f, "w") as z:
                z.writestr("word/document.xml", '<w:t>see https://docs.example.com/page</w:t>')
                z.writestr(
                    "word/_rels/document.xml.rels",
                    '<Relationship Target="https://www.linked.example.org/a"/>',
                )
            r = run(f)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("https://docs.example.com/page", r.stdout)
        self.assertIn("UNIQUE LINKS: 2", r.stdout)
        # www. prefix stripped in the BY DOMAIN section (exact line — a bare
        # substring check would also match the unstripped domain).
        self.assertRegex(r.stdout, r"(?m)^\s+1\s+linked\.example\.org$")

    def test_usage_errors(self):
        self.assertNotEqual(run().returncode, 0)  # no argument
        self.assertNotEqual(run("/nonexistent/report.md").returncode, 0)


if __name__ == "__main__":
    unittest.main()
