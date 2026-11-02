#!/usr/bin/env python3
"""English -> Uzbek for /core:grill-me, through Gemini. Standard library only.

  translate.py               English markdown on stdin -> Uzbek on stdout
  translate.py --status      one line, offline: on | off | unset | broken: <why>
  translate.py --setup yes|no  record the choice in <config dir>/.env (idempotent)
  translate.py --check       one real API call; prints a sample translation

Settings (process environment wins over <config dir>/.env, where <config dir>
is $CLAUDE_CONFIG_DIR or ~/.claude):
  GRILL_ME_UZ=1|0   opt-in switch; unset means the user was never asked
  GEMINI_API_KEY    https://aistudio.google.com/apikey
  GEMINI_MODEL      overrides MODEL below

Code spans, fenced blocks and URLs never leave the machine: they are swapped
for ⟦n⟧ tokens before the request and restored from the original afterwards,
so the model cannot alter them. The prompt (prompt-uz.md) keeps the rest of
the technical vocabulary, names and acronyms in English.
"""
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# shortcut: Google deprecated gemini-3.5-flash and routes it to gemini-3.6-flash;
# kept because it was asked for. Set GEMINI_MODEL (or edit this) to move on.
MODEL = "gemini-3.5-flash"
ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent"
PROMPT_FILE = pathlib.Path(__file__).with_name("prompt-uz.md")
SETTINGS = ("GRILL_ME_UZ", "GEMINI_API_KEY", "GEMINI_MODEL")
SAMPLE = "Should `retry_count` live in `config.yaml`, or be read from the environment?"

SPANS = re.compile(r"```.*?```|`[^`\n]+`|https?://[^\s)>\]]*[^\s)>\].,;:!?]", re.S)
TOKEN = re.compile(r"⟦(\d+)⟧")


class Fail(Exception):
    pass


class Transient(Fail):
    """429, 5xx or a network error: worth retrying."""


def env_file():
    return pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR") or pathlib.Path.home() / ".claude") / ".env"


def read_env(path):
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError:
        return {}
    out = {}
    for line in text.splitlines():
        key, eq, value = line.strip().partition("=")
        if eq and not key.startswith("#"):
            # shortcut: no '#' inside a value; fine for API keys and flags.
            out[key.strip()] = re.sub(r"\s+#.*$", "", value.strip()).strip("\"'")
    return out


def config():
    return {**read_env(env_file()), **{k: os.environ[k] for k in SETTINGS if os.environ.get(k)}}


def status(cfg):
    flag = cfg.get("GRILL_ME_UZ")
    if flag is None:
        return "unset"
    if flag.lower() not in ("1", "true", "yes", "on"):
        return "off"
    if not cfg.get("GEMINI_API_KEY"):
        return f"broken: GEMINI_API_KEY is empty - paste your key into {env_file()}"
    return "on"


def mask(text):
    spans = []

    def keep(m):
        spans.append(m.group(0))
        return f"⟦{len(spans) - 1}⟧"

    return SPANS.sub(keep, text), spans


def api_error(e):
    try:
        return json.load(e)["error"]["message"]
    except (ValueError, KeyError, TypeError, OSError):
        return e.reason


def post(req):
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        kind = Transient if e.code == 429 or e.code >= 500 else Fail
        raise kind(f"Gemini HTTP {e.code}: {api_error(e)}") from None
    except ValueError:
        raise Fail("Gemini answered with something that is not JSON") from None
    except OSError as e:  # URLError, timeouts, resets
        raise Transient(f"network error: {e}") from None


def send(req):
    for delay in (1, 2):
        try:
            return post(req)
        except Transient:
            time.sleep(delay)
    return post(req)


def call(text, cfg):
    body = {
        "systemInstruction": {"parts": [{"text": PROMPT_FILE.read_text(encoding="utf-8")}]},
        "contents": [{"role": "user", "parts": [{"text": text}]}],
        # No temperature: Gemini 3.x is tuned for its default and 3.6+ ignores it.
        "generationConfig": {"thinkingConfig": {"thinkingLevel": "LOW"}},
    }
    req = urllib.request.Request(
        ENDPOINT.format(urllib.parse.quote(cfg.get("GEMINI_MODEL") or MODEL, safe="")),
        json.dumps(body).encode(),
        # Key in a header, not the URL, so it cannot surface in an error message.
        {"Content-Type": "application/json", "x-goog-api-key": cfg["GEMINI_API_KEY"]},
    )
    data = send(req)
    cand = (data.get("candidates") or [{}])[0]
    out = "".join(p.get("text", "") for p in cand.get("content", {}).get("parts", []) if not p.get("thought"))
    if not out.strip():
        raise Fail(f"empty response (finishReason={cand.get('finishReason')}, feedback={data.get('promptFeedback')})")
    return out.strip()


def translate(text, cfg):
    masked, spans = mask(text)
    want = sorted(TOKEN.findall(masked))
    for _ in range(2):
        out = call(masked, cfg)
        if sorted(TOKEN.findall(out)) == want:
            return TOKEN.sub(lambda m: spans[int(m.group(1))], out)
    raise Fail("Gemini dropped or altered protected code spans twice")


def setup(answer):
    path = env_file()
    have = read_env(path)
    want = "1" if answer == "yes" else "0"
    add = [] if have.get("GRILL_ME_UZ") == want else [f"GRILL_ME_UZ={want}"]
    if answer == "yes" and "GEMINI_API_KEY" not in have:  # never touch an existing key
        add.append("GEMINI_API_KEY=")
    if add:
        old = path.read_bytes() if path.exists() else b""
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "ab") as f:
            f.write((b"\n" if old and not old.endswith(b"\n") else b"") + "\n".join(add).encode() + b"\n")
        try:
            path.chmod(0o600)
        except OSError:
            pass
    print(f"{path}: grill-me Uzbek mode {'on' if answer == 'yes' else 'off'}")
    if answer == "yes" and not config().get("GEMINI_API_KEY"):
        print("Paste your Gemini API key after GEMINI_API_KEY= in that file (free key: https://aistudio.google.com/apikey), then run --check.")


def main(argv):
    for stream in (sys.stdin, sys.stdout):  # Windows pipes default to the ANSI codepage
        stream.reconfigure(encoding="utf-8")  # pyright: ignore[reportAttributeAccessIssue]
    arg = argv[0] if argv else ""
    try:
        if arg == "--status":
            print(status(config()))
        elif arg == "--setup" and argv[1:] in (["yes"], ["no"]):
            setup(argv[1])
        elif arg in ("", "--check"):
            cfg = config()
            if not cfg.get("GEMINI_API_KEY"):
                raise Fail(f"GEMINI_API_KEY is not set - paste your key into {env_file()}")
            text = SAMPLE if arg else sys.stdin.read()
            if not text.strip():
                raise Fail("no text on stdin")
            print(translate(text, cfg))
        else:
            raise Fail("usage: translate.py [--status | --setup yes|no | --check] (else English on stdin)")
    except Fail as e:
        print(f"translate.py: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
