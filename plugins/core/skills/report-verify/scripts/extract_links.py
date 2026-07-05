#!/usr/bin/env python3
"""Extract and count hyperlinks from .docx, .html, .md, or .txt reports.

Zero dependencies: .docx is read as a zip (hyperlinks live in the XML
and .rels parts), everything else is scanned as plain text.

Usage: python3 extract_links.py <report.docx|.html|.md|.txt>
"""
import collections
import pathlib
import re
import sys
import urllib.parse
import zipfile

URL_RE = re.compile(r'https?://[^\s<>"\')\]}]+')


def links_from_docx(path: pathlib.Path) -> list[str]:
    urls: list[str] = []
    with zipfile.ZipFile(path) as z:
        for name in z.namelist():
            if name.endswith((".xml", ".rels")):
                text = z.read(name).decode("utf-8", "ignore")
                urls += URL_RE.findall(text)
    return urls


def links_from_text(path: pathlib.Path) -> list[str]:
    return URL_RE.findall(path.read_text(encoding="utf-8", errors="ignore"))


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: extract_links.py <report.docx|.html|.md|.txt>")
    path = pathlib.Path(sys.argv[1])
    if not path.exists():
        sys.exit(f"file not found: {path}")

    raw = links_from_docx(path) if path.suffix.lower() == ".docx" else links_from_text(path)
    # strip trailing punctuation and XML-escaped ampersands
    urls = [u.rstrip('.,;:!?)»"\'').replace("&amp;", "&") for u in raw]
    unique = sorted(set(urls))
    domains = collections.Counter(
        urllib.parse.urlparse(u).netloc.lower().removeprefix("www.") for u in unique
    )

    print(f"TOTAL LINK OCCURRENCES: {len(urls)}")
    print(f"UNIQUE LINKS: {len(unique)}")
    dups = len(urls) - len(unique)
    if dups:
        print(f"DUPLICATED OCCURRENCES: {dups}")
    print("\nBY DOMAIN:")
    for domain, count in domains.most_common():
        print(f"  {count:4d}  {domain}")
    print("\nUNIQUE URLS:")
    for u in unique:
        print(f"  {u}")


if __name__ == "__main__":
    main()
