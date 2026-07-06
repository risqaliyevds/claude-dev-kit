#!/usr/bin/env python3
"""Claude Code statusLine:  🧠 <model> • CTX <bar> • 📊 <bar> N% • 📅 <bar> M% ↻ Xd Yh

Reads the REAL rate-limit data Claude Code passes on stdin (v2.1.80+, Pro/Max).
Schema (https://code.claude.com/docs/en/statusline):
    rate_limits.five_hour.used_percentage   0-100  → 📊  (5-hour rolling window)
    rate_limits.five_hour.resets_at         unix epoch seconds
    rate_limits.seven_day.used_percentage   0-100  → 📅  (weekly / 7-day window)
    rate_limits.seven_day.resets_at         unix epoch seconds  → "↻ Xd Yh"

`rate_limits` appears only for Claude.ai subscribers (Pro/Max) AFTER the first API
response in the session, and each window can be independently absent — handled with
an em-dash fallback so the line never breaks.
"""
import json
import sys
import time

BARS = 10

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


def bar(pct):
    if pct is None:
        return DIM + "─" * BARS + RESET
    pct = max(0.0, min(100.0, float(pct)))
    fill = int(round(pct / 100.0 * BARS))
    return color_for(pct) + "█" * fill + "░" * (BARS - fill) + RESET


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

    # Context window: used % + tokens-in-context / window size. Prefer the
    # documented totals (v2.1.132+: tokens currently in context, cache
    # included); fall back to summing current_usage on older versions.
    ctx_pct = num(cw.get("used_percentage"))
    size = num(cw.get("context_window_size"))
    tot_in = num(cw.get("total_input_tokens"))
    used_tok = tot_in + (num(cw.get("total_output_tokens")) or 0) if tot_in else None
    if used_tok is None:
        cur = as_dict(cw.get("current_usage"))
        used_tok = sum(v for v in cur.values() if isinstance(v, (int, float))) if cur else None

    five = as_dict(rl.get("five_hour"))
    week = as_dict(rl.get("seven_day"))
    fh = num(five.get("used_percentage"))
    sd = num(week.get("used_percentage"))
    fh_reset = reset_str(five.get("resets_at"))
    sd_reset = reset_str(week.get("resets_at"))

    ctx = f"CTX: {bar(ctx_pct)} {pctstr(ctx_pct)}"
    if used_tok is not None and size:
        ctx += f" {tok(used_tok)}/{tok(size)}"

    hl = f"📊 HL: {bar(fh)} {pctstr(fh)}"
    if fh_reset:
        hl += f" ↻ {fh_reset}"
    wl = f"📅 WL: {bar(sd)} {pctstr(sd)}"
    if sd_reset:
        wl += f" ↻ {sd_reset}"

    print(f"🧠 Model: {model} • {ctx} • {hl} • {wl}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("🧠 Model: Claude")  # last resort: a status line must always render
