#!/usr/bin/env python3
"""Claude Code statusLine:  🧠 <model> • CTX: N% (size) • 📊 HL: N% ↻ Xh • 📅 WL: M% ↻ Xd Yh • 🔮 WLF: F%

Reads the REAL rate-limit data Claude Code passes on stdin (v2.1.80+, Pro/Max).
Schema (https://code.claude.com/docs/en/statusline):
    rate_limits.five_hour.used_percentage   0-100  → 📊  (5-hour rolling window)
    rate_limits.five_hour.resets_at         unix epoch seconds
    rate_limits.seven_day.used_percentage   0-100  → 📅  (weekly / 7-day window)
    rate_limits.seven_day.resets_at         unix epoch seconds  → "↻ Xd Yh"

`rate_limits` appears only for Claude.ai subscribers (Pro/Max) AFTER the first API
response in the session, and each window can be independently absent — handled with
an em-dash fallback so the line never breaks.

🔮 WLF is the per-model weekly Fable window. Claude Code shows it in /usage but
does NOT pass it on stdin, so we fetch GET /api/oauth/usage ourselves with the
OAuth token from <config>/.credentials.json (config = $CLAUDE_CONFIG_DIR or
~/.claude) and cache it in <config>/statusline-cache/fable.json. Without a token
(API-key login, macOS Keychain storage) it renders "—".
"""
import datetime
import json
import os
import pathlib
import sys
import time
import urllib.request

USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
CACHE_TTL = 120  # seconds; the line re-renders on every event, so do not hammer the API

GREEN, YELLOW, RED, DIM, RESET = "\033[32m", "\033[33m", "\033[31m", "\033[2m", "\033[0m"


def as_dict(x):
    """Schema drift (a string/list where an object is expected) must not crash."""
    return x if isinstance(x, dict) else {}


def num(x):
    """Coerce to float; None for anything non-numeric (renders as em-dash)."""
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def color_for(pct):
    if pct is None:
        return DIM
    if pct >= 80:
        return RED
    if pct >= 50:
        return YELLOW
    return GREEN


def pctstr(pct):
    if pct is None:
        return "—"
    return f"{color_for(pct)}{float(pct):.0f}%{RESET}"


def reset_str(epoch, now=None):
    """Unix-epoch reset time → 'Xd Yh' (or 'Yh Zm' under a day)."""
    epoch = num(epoch)
    if not epoch:
        return ""
    if now is None:
        now = time.time()
    delta = int(epoch) - int(now)
    if delta <= 0:
        return "now"
    d, rem = divmod(delta, 86400)
    h, rem = divmod(rem, 3600)
    if d > 0:
        return f"{d}d {h}h"
    return f"{h}h {rem // 60}m"


def tok(n):
    """73711 → '74k', 1000000 → '1M'."""
    if n is None:
        return "—"
    n = int(n)
    if n >= 1_000_000:
        v = n / 1_000_000
        return f"{v:.1f}M".replace(".0M", "M")
    if n >= 1_000:
        return f"{round(n / 1_000)}k"
    return str(n)


def config_dir():
    return pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR") or pathlib.Path.home() / ".claude")


def fetch_usage(token):
    req = urllib.request.Request(
        USAGE_URL,
        headers={"Authorization": f"Bearer {token}", "anthropic-beta": "oauth-2025-04-20"},
    )
    with urllib.request.urlopen(req, timeout=3) as r:
        return json.load(r)


def fable_window(usage):
    """usage JSON -> (used_pct, resets_at_epoch) of the weekly_scoped 'Fable' limit."""
    for lim in as_dict(usage).get("limits") or []:
        lim = as_dict(lim)
        model = as_dict(as_dict(lim.get("scope")).get("model"))
        if lim.get("kind") == "weekly_scoped" and str(model.get("display_name", "")).lower() == "fable":
            reset = None
            try:
                reset = datetime.datetime.fromisoformat(str(lim.get("resets_at"))).timestamp()
            except (TypeError, ValueError):
                pass
            return num(lim.get("percent")), reset
    return None, None


def fable_weekly(cfg, fetch=fetch_usage):
    """(used_pct, resets_at) with a TTL cache; a stale cache beats a blank on failure."""
    cache = pathlib.Path(cfg) / "statusline-cache" / "fable.json"
    try:
        if time.time() - cache.stat().st_mtime < CACHE_TTL:
            return fable_window(json.loads(cache.read_text(encoding="utf-8")))
    except (OSError, ValueError):
        pass
    try:
        creds = json.loads((pathlib.Path(cfg) / ".credentials.json").read_text(encoding="utf-8"))
        token = as_dict(as_dict(creds).get("claudeAiOauth")).get("accessToken")
    except (OSError, ValueError):
        token = None
    if not token:
        return None, None
    try:
        usage = fetch(token)
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps(usage), encoding="utf-8")
        return fable_window(usage)
    except Exception:
        try:
            return fable_window(json.loads(cache.read_text(encoding="utf-8")))
        except (OSError, ValueError):
            return None, None


def main():
    model = "Claude"
    rl, cw = {}, {}
    try:
        p = as_dict(json.load(sys.stdin))
        model = as_dict(p.get("model")).get("display_name") or model
        rl = as_dict(p.get("rate_limits"))
        cw = as_dict(p.get("context_window"))
    except Exception:
        pass

    # Context window: used % + window size in parentheses. The used token count
    # is implied by the percentage, so it is not repeated.
    ctx_pct = num(cw.get("used_percentage"))
    size = num(cw.get("context_window_size"))

    five = as_dict(rl.get("five_hour"))
    week = as_dict(rl.get("seven_day"))
    fh = num(five.get("used_percentage"))
    sd = num(week.get("used_percentage"))
    fh_reset = reset_str(five.get("resets_at"))
    sd_reset = reset_str(week.get("resets_at"))
    try:
        wf, wf_reset_epoch = fable_weekly(config_dir())
    except Exception:
        wf, wf_reset_epoch = None, None
    wf_reset = reset_str(wf_reset_epoch)

    ctx = f"CTX: {pctstr(ctx_pct)}"
    if size:
        ctx += f" ({tok(size)})"

    hl = f"📊 HL: {pctstr(fh)}"
    if fh_reset:
        hl += f" ↻ {fh_reset}"
    wl = f"📅 WL: {pctstr(sd)}"
    if sd_reset:
        wl += f" ↻ {sd_reset}"
    wlf = f"🔮 WLF: {pctstr(wf)}"
    if wf_reset:
        wlf += f" ↻ {wf_reset}"

    print(f"🧠 Model: {model} • {ctx} • {hl} • {wl} • {wlf}")


if __name__ == "__main__":
    # Windows pipes default to the ANSI code page (cp1251/cp1252), where 🧠 and •
    # raise UnicodeEncodeError → an empty status line. Force UTF-8 before
    # anything prints, including the last-resort fallback below.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    try:
        main()
    except Exception:
        print("🧠 Model: Claude")  # last resort: a status line must always render
