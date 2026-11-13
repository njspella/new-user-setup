---
name: roi-executive-summary
description: >-
  Build a polished one-to-two page executive summary / business case for a
  capital-equipment or automation investment as a Word (.docx) document —
  investment breakdown, multi-year savings, payback, ROI, and a KPI strip.
  Use this whenever the user wants an executive summary, business case, ROI
  writeup, or investment justification for buying a machine, cobot, robot,
  cell, or automation package — e.g. a Vectis/Universal Robots cobot, a weld
  cell, a PLC/servo retrofit — even if they just paste a quote and some
  labor-savings numbers and say "put together a summary." Trigger on mentions
  of payback period, break-even years, ROI, labor savings, cost justification,
  or "make this into an exec summary for leadership."
---

# ROI Executive Summary

Turn a capital quote plus savings data into a clean, leadership-ready one-to-two
page Word document. The deliverable is almost always a `.docx` (that's what gets
attached to a business case and circulated), so default to that via the bundled
generator rather than hand-building a document.

## What this produces

A single-section US-Letter `.docx` with, in order:

1. **Title block** — "EXECUTIVE SUMMARY" eyebrow, title, italic subtitle, rule.
2. **KPI strip** — four bordered cards: Total Investment, Payback, Gross Savings, Net Gain.
3. **Recommendation** — one decisive paragraph (auto-written from the numbers unless supplied).
4. **Investment Breakdown** — line-item capital table with a total row.
5. **Financial Return** — a cash-flow ledger (savings, cumulative savings, cumulative net position) plus payback/ROI/trend bullets.
6. **Operational Impact** — optional labor/capacity/quality bullets.
7. **Detail table** — optional (e.g. the per-part / per-weldment breakdown).
8. **Key Assumptions & Notes** — the caveats that keep the number honest.

## Workflow

1. **Gather the inputs.** You need: the capital line items and costs, the savings by
   period (Year 0..N), and — if the customer has one — their ROI-calculator payback
   number. Pull as much as possible from what the user already gave you (quotes,
   spreadsheet photos, pasted figures) before asking. A photo of a spreadsheet is a
   normal input; read the numbers off it.

2. **Confirm the output format only if unclear.** Default to `.docx`. Offer
   PowerPoint / Excel / inline text if the user might want the business case in
   another shape, but don't belabor it.

3. **Write a config JSON** following `references/example-config.json` (a complete,
   real example). Fields are documented inline below.

4. **Ensure `docx` is available**, then run the generator:
   ```bash
   npm ls docx >/dev/null 2>&1 || npm install docx
   node <skill>/scripts/build_summary.js /path/to/config.json
   ```
   The script prints the computed totals, payback, and ROI so you can sanity-check
   them against the source data.

5. **Validate** the file is well-formed before delivering (a corrupt .docx is worse
   than none):
   ```bash
   mkdir -p /tmp/docxcheck && unzip -o -q <output>.docx -d /tmp/docxcheck \
     && xmllint --noout /tmp/docxcheck/word/document.xml && echo "well-formed"
   ```
   If LibreOffice is installed you can also render a PDF preview
   (`soffice --headless --convert-to pdf`); if not, the well-formed check is enough.

6. **Deliver** the file and give a short recap of the headline numbers (investment,
   payback, ROI, net gain), plus any judgment calls worth flagging.

## The financial math (what the script computes)

- **Total investment** = sum of investment line items.
- **Gross savings** = sum of per-period savings.
- **Net gain** = gross savings − investment. **ROI %** = net gain ÷ investment.
- **Cumulative net position** starts at −investment and adds each period's savings;
  the ledger shows where it crosses zero.
- **Payback (undiscounted)** uses the *Year-0-as-time-zero* convention: Year 0's
  savings land at elapsed time 0, so a crossing during period *i* gives
  `(i − 1) + fractionIntoPeriod` years.

### Payback conventions matter — match the customer's calculator

This is the easiest way to look wrong. The same cash flow yields different payback
numbers depending on where you start the clock:

- **Year-0-as-time-zero** (most company ROI calculators, and the script default):
  the first savings year is "Year 0" at t=0. → smaller number.
- **Elapsed-from-start-of-Year-0**: the first year of operation still takes a full
  year to elapse. → about 1.0 year larger.

If the user cites a payback figure from their own ROI calculator (e.g. "3.93
break-even years, undiscounted"), that number is authoritative — set
`paybackYearsOverride` to it and match `paybackKind` ("undiscounted" /
"discounted"). Don't argue the model into a different figure; reconcile to theirs.
The cash-flow ledger stays an honest record either way — it's only the headline
years-to-payback that shifts with the convention.

## Config contract

Full worked example: `references/example-config.json`. Key fields:

| Field | Required | Purpose |
|-------|----------|---------|
| `title`, `subtitle` | yes | Header text. |
| `outputPath` | recommended | Where to write the .docx. |
| `investment` | yes | Array of `[label, cost]`. Total row is auto-added. |
| `investmentNote` | no | Italic caveat under the investment table (e.g. "estimate pending quote"). |
| `savings` | yes | Array of `[periodLabel, amount]`, in order (Year 0..N). |
| `savingsColLabel` | no | Header for the savings column (default "Savings"). |
| `paybackYearsOverride` | no | Force the payback figure to match a company ROI calculator. |
| `paybackKind` | no | "undiscounted" (default) or "discounted" — labels the KPI/bullet. |
| `recommendation` | no | Override the auto-written recommendation paragraph. |
| `operationalBullets` | no | Array of `[lead, text]` (or plain strings). |
| `detailTable` | no | `{title, columns, rows, totalLabel, totalValue, note}` — first column left-aligned, rest right-aligned. |
| `assumptions` | no | Array of caveat strings. |
| `kpis`, `theme` | no | Override the four KPI cards or the color palette. |

## Notes on judgment

- **Auto-generation is a floor, not a ceiling.** The recommendation paragraph and
  KPI labels are generated so a bare config still produces something complete, but a
  tailored recommendation that names the specific parts, the operator redeployment,
  or the strategic reason usually reads better — write one and pass `recommendation`.
- **Keep assumptions visible.** Estimates (an un-quoted PLC cost), ramp-year effects,
  and "direct labor only" scoping belong in the Assumptions section. They protect the
  number's credibility and pre-empt the obvious pushback.
- **Numbers in the detail table are strings** — format them as you want them shown
  (e.g. "64.50", "0.0834"); the script right-aligns everything but the first column.
