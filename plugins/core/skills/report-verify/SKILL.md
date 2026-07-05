---
name: report-verify
description: Verify declared figures in a report against the actual hyperlinks in the document - count links, group by domain, and cross-check claimed publication or content counts. Use when checking media reports, activity reports, or any document whose claimed numbers should match its links.
disable-model-invocation: true
argument-hint: "[path to report file]"
---

Verify the report: $ARGUMENTS

1. Run the extractor (supports .docx, .html, .md, .txt):

   `python3 ${CLAUDE_SKILL_DIR}/scripts/extract_links.py "<file>"`

   It prints: total link occurrences, unique links, duplicates, counts grouped by domain, and the full URL list.

2. Read the report text and list every declared figure (e.g., "45 publications", "12 TV appearances", "30 posts on site X"), quoting each claim exactly as written.

3. Build a comparison table: declared claim -> matching link count. Match domains to claim types sensibly: site publications -> that site's domain; TV -> broadcaster domains or their YouTube; social media -> t.me / instagram.com / facebook.com; etc. State your domain-to-claim mapping so it can be checked.

4. Flag explicitly:
   - claims with fewer links than declared (and the gap)
   - duplicate links that inflate counts
   - links present in the document but not covered by any claim
   - claims with no supporting links at all

5. Verdict per claim: ✅ matches / ⚠️ partial (state the gap) / ❌ mismatch. Never "fix" the declared numbers yourself — report discrepancies for a human decision. If asked to spot-check content, fetch a sample of links and confirm they thematically match the claim.
