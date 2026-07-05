---
name: announcement
description: Draft an internal team announcement (Telegram-style) in Uzbek, with optional Russian version. Use when asked to write or draft an announcement, e'lon, xabar, or internal message for the team.
disable-model-invocation: true
argument-hint: "[topic, key facts, deadline]"
---

Draft an internal announcement about: $ARGUMENTS

Style rules:
- Language: Uzbek (Latin script) by default; add a Russian version only if asked.
- Tone: concise and professionally warm — friendly, but official.
- Structure: (1) short greeting + what's happening, (2) why it matters in one line, (3) concrete details — dates, links, requirements — as short lines, (4) a clear call to action with the deadline, (5) a closing line.
- Emojis: 3-6 total, purposeful (📌 deadlines, ✅ actions, 📚 courses, ⏰ dates), never more than one per line.
- The deadline must be explicit and visually prominent. If completion is mandatory or tied to KPI, say so plainly but kindly.
- Length: fits one Telegram message (under ~900 characters) unless a long version is requested.
- End with an offer of help or a contact point.

Process:
1. If the deadline, target audience, or required action is missing from the input, ask for it first — an announcement without a deadline and a concrete action is not finished.
2. When tone could reasonably differ, offer 2 variants (e.g., "friendly reminder" vs. "firm final call") and let the user pick.
3. After the draft, list in one line which facts you assumed vs. which were provided, so nothing invented slips into an official message.
