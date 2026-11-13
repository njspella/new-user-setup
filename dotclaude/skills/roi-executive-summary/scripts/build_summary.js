#!/usr/bin/env node
/*
 * build_summary.js — generate a capital-investment / automation ROI executive
 * summary as a polished .docx.
 *
 * Usage:  node build_summary.js <config.json>
 *
 * The config JSON is the single source of truth. See references/example-config.json
 * for a fully-worked example and the SKILL.md for the field-by-field contract.
 *
 * Financials (totals, cumulative cash flow, payback, ROI) are computed from the
 * data. Payback can be overridden with `paybackYearsOverride` when a company ROI
 * calculator is authoritative — always match the customer's own number.
 */
const fs = require("fs");
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  AlignmentType, HeadingLevel, BorderStyle, WidthType, ShadingType,
  VerticalAlign, Footer, PageNumber, LevelFormat,
} = require("docx");

// ---------- Load config ----------
const cfgPath = process.argv[2];
if (!cfgPath) {
  console.error("Usage: node build_summary.js <config.json>");
  process.exit(1);
}
const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));

// ---------- Palette (override via cfg.theme) ----------
const theme = Object.assign(
  { navy: "1F3864", blue: "2E5496", light: "DCE6F1", lighter: "EDF2F9", green: "548235", red: "C00000", grey: "808080" },
  cfg.theme || {}
);
const { navy: NAVY, blue: BLUE, light: LIGHT, lighter: LIGHTER, green: GREEN, red: RED, grey: GREY } = theme;
const CONTENT_W = 9360; // US Letter, 1" side margins

// ---------- Financial computation ----------
const investment = cfg.investment || []; // [[label, cost], ...]
const totalInvestment = investment.reduce((s, r) => s + r[1], 0);

const savings = cfg.savings || []; // [[periodLabel, amount], ...]
const savingsVals = savings.map((r) => r[1]);
const totalSavings = savingsVals.reduce((s, v) => s + v, 0);
const netGain = totalSavings - totalInvestment;
const roiPct = totalInvestment ? Math.round((netGain / totalInvestment) * 100) : 0;

// cumulative net position after each period
let running = -totalInvestment;
const ledger = savings.map(([label, amt]) => {
  const before = running;
  running += amt;
  return { label, amt, cumSavings: totalSavings === 0 ? 0 : null, cumNet: running, before };
});
// cumulative savings
let cs = 0;
ledger.forEach((row) => { cs += row.amt; row.cumSavings = cs; });

// Undiscounted payback, Year-0-as-time-zero convention (matches typical company
// ROI calculators): after Year 0's savings, elapsed time = 0; crossing in period
// i gives elapsed = (i - 1) + fractionIntoPeriod.
function computePayback() {
  for (let i = 0; i < savingsVals.length; i++) {
    const before = i === 0 ? -totalInvestment : ledger[i].before;
    const after = ledger[i].cumNet;
    if (after >= 0) {
      const frac = savingsVals[i] ? (-before) / savingsVals[i] : 0;
      return Math.max(0, i - 1 + frac);
    }
  }
  return null; // never pays back within the horizon
}
const paybackComputed = computePayback();
const paybackYears = (cfg.paybackYearsOverride != null) ? cfg.paybackYearsOverride : paybackComputed;
const paybackLabel = paybackYears == null
  ? "> horizon"
  : (Number(paybackYears).toFixed(2) + " yrs");
const paybackKind = cfg.paybackKind || "undiscounted";

// ---------- Formatting helpers ----------
const usd = (n) => "$" + Math.round(n).toLocaleString("en-US");
const usdCum = (n) => (n < 0 ? "(" + usd(Math.abs(n)) + ")" : usd(n));

const border = { style: BorderStyle.SINGLE, size: 1, color: "BFBFBF" };
const borders = { top: border, bottom: border, left: border, right: border };
const cellMargins = { top: 60, bottom: 60, left: 120, right: 120 };

function tc(text, o = {}) {
  const { bold = false, fill = null, color = "000000", align = AlignmentType.LEFT, width, size = 20, colSpan } = o;
  return new TableCell({
    borders, columnSpan: colSpan,
    width: { size: width, type: WidthType.DXA },
    shading: fill ? { fill, type: ShadingType.CLEAR } : undefined,
    margins: cellMargins, verticalAlign: VerticalAlign.CENTER,
    children: [new Paragraph({ alignment: align, children: [new TextRun({ text: String(text), bold, color, size, font: "Arial" })] })],
  });
}

function headingBar(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2, children: [new TextRun(text)],
    border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: BLUE, space: 2 } },
  });
}

function bullet(text, lead) {
  const runs = [];
  if (lead) runs.push(new TextRun({ text: lead + " ", bold: true, font: "Arial", size: 22 }));
  runs.push(new TextRun({ text, font: "Arial", size: 22 }));
  return new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 80 }, children: runs });
}

function note(text) {
  return new Paragraph({ spacing: { after: 40 }, children: [new TextRun({ text, size: 16, italics: true, color: GREY, font: "Arial" })] });
}

// ---------- KPI strip ----------
function kpiCard(value, label, accent, w) {
  return new TableCell({
    borders: { top: { style: BorderStyle.SINGLE, size: 4, color: accent }, bottom: { style: BorderStyle.SINGLE, size: 4, color: accent }, left: { style: BorderStyle.SINGLE, size: 4, color: accent }, right: { style: BorderStyle.SINGLE, size: 4, color: accent } },
    width: { size: w, type: WidthType.DXA },
    shading: { fill: LIGHTER, type: ShadingType.CLEAR },
    margins: { top: 120, bottom: 120, left: 80, right: 80 }, verticalAlign: VerticalAlign.CENTER,
    children: [
      new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: value, bold: true, size: 30, color: accent, font: "Arial" })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: label, size: 16, color: "404040", font: "Arial" })] }),
    ],
  });
}
const kpis = cfg.kpis || [
  { value: usd(totalInvestment), label: "Total Investment", accent: NAVY },
  { value: paybackLabel, label: "Payback (" + paybackKind + ")", accent: BLUE },
  { value: usd(totalSavings), label: (savings.length ? savings.length : "") + "-Period Gross Savings", accent: GREEN },
  { value: usd(netGain), label: "Net Gain", accent: GREEN },
];
const kpiW = Math.floor(CONTENT_W / kpis.length);
const kpiStrip = new Table({
  width: { size: CONTENT_W, type: WidthType.DXA },
  columnWidths: kpis.map(() => kpiW),
  borders: { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE }, insideHorizontal: { style: BorderStyle.NONE }, insideVertical: { style: BorderStyle.NONE } },
  rows: [new TableRow({ children: kpis.map((k) => kpiCard(k.value, k.label, k.accent || BLUE, kpiW)) })],
});

// ---------- Investment table ----------
const invNote = cfg.investmentNote;
const investmentTable = new Table({
  width: { size: CONTENT_W, type: WidthType.DXA }, columnWidths: [7000, 2360],
  rows: [
    new TableRow({ tableHeader: true, children: [tc("Capital Item", { bold: true, fill: NAVY, color: "FFFFFF", width: 7000 }), tc("Cost", { bold: true, fill: NAVY, color: "FFFFFF", align: AlignmentType.RIGHT, width: 2360 })] }),
    ...investment.map((r, i) => new TableRow({ children: [tc(r[0], { width: 7000, fill: i % 2 ? LIGHTER : "FFFFFF" }), tc(usd(r[1]), { width: 2360, align: AlignmentType.RIGHT, fill: i % 2 ? LIGHTER : "FFFFFF" })] })),
    new TableRow({ children: [tc(cfg.investmentTotalLabel || "Total Installed Investment", { bold: true, width: 7000, fill: LIGHT }), tc(usd(totalInvestment), { bold: true, width: 2360, align: AlignmentType.RIGHT, fill: LIGHT })] }),
  ],
});

// ---------- Cash-flow / ledger table ----------
const cfCols = [1800, 2520, 2520, 2520];
const cashflowTable = new Table({
  width: { size: CONTENT_W, type: WidthType.DXA }, columnWidths: cfCols,
  rows: [
    new TableRow({ tableHeader: true, children: [
      tc("Period", { bold: true, fill: NAVY, color: "FFFFFF", width: cfCols[0] }),
      tc(cfg.savingsColLabel || "Savings", { bold: true, fill: NAVY, color: "FFFFFF", align: AlignmentType.RIGHT, width: cfCols[1] }),
      tc("Cumulative Savings", { bold: true, fill: NAVY, color: "FFFFFF", align: AlignmentType.RIGHT, width: cfCols[2] }),
      tc("Cumulative Net Position", { bold: true, fill: NAVY, color: "FFFFFF", align: AlignmentType.RIGHT, width: cfCols[3] }),
    ] }),
    new TableRow({ children: [
      tc("Investment", { bold: true, width: cfCols[0], fill: LIGHT }),
      tc("—", { width: cfCols[1], align: AlignmentType.RIGHT, fill: LIGHT }),
      tc("—", { width: cfCols[2], align: AlignmentType.RIGHT, fill: LIGHT }),
      tc(usdCum(-totalInvestment), { bold: true, color: RED, width: cfCols[3], align: AlignmentType.RIGHT, fill: LIGHT }),
    ] }),
    ...ledger.map((row, i) => new TableRow({ children: [
      tc(row.label, { width: cfCols[0], fill: i % 2 ? LIGHTER : "FFFFFF" }),
      tc(usd(row.amt), { width: cfCols[1], align: AlignmentType.RIGHT, fill: i % 2 ? LIGHTER : "FFFFFF" }),
      tc(usd(row.cumSavings), { width: cfCols[2], align: AlignmentType.RIGHT, fill: i % 2 ? LIGHTER : "FFFFFF" }),
      tc(usdCum(row.cumNet), { bold: true, color: row.cumNet >= 0 ? GREEN : RED, width: cfCols[3], align: AlignmentType.RIGHT, fill: i % 2 ? LIGHTER : "FFFFFF" }),
    ] })),
  ],
});

// ---------- Optional detail table (e.g. weldments) ----------
let detailBlock = [];
if (cfg.detailTable && cfg.detailTable.rows && cfg.detailTable.columns) {
  const dt = cfg.detailTable;
  const n = dt.columns.length;
  const first = 2160;
  const rest = Math.floor((CONTENT_W - first) / (n - 1));
  const widths = [first, ...Array(n - 1).fill(rest)];
  widths[widths.length - 1] += CONTENT_W - widths.reduce((s, w) => s + w, 0); // fix rounding
  const rows = [
    new TableRow({ tableHeader: true, children: dt.columns.map((c, j) => tc(c, { bold: true, fill: NAVY, color: "FFFFFF", width: widths[j], size: 18, align: j === 0 ? AlignmentType.LEFT : AlignmentType.RIGHT })) }),
    ...dt.rows.map((r, i) => new TableRow({ children: r.map((v, j) => tc(v, { width: widths[j], size: 18, align: j === 0 ? AlignmentType.LEFT : AlignmentType.RIGHT, fill: i % 2 ? LIGHTER : "FFFFFF" })) })),
  ];
  if (dt.totalLabel != null) {
    const spanW = widths.slice(0, n - 1).reduce((s, w) => s + w, 0);
    rows.push(new TableRow({ children: [
      tc(dt.totalLabel, { bold: true, width: spanW, fill: LIGHT, size: 18, colSpan: n - 1 }),
      tc(dt.totalValue != null ? dt.totalValue : "", { bold: true, width: widths[n - 1], align: AlignmentType.RIGHT, fill: LIGHT, size: 18 }),
    ] }));
  }
  detailBlock = [
    headingBar(dt.title || "Detail"),
    new Table({ width: { size: CONTENT_W, type: WidthType.DXA }, columnWidths: widths, rows }),
  ];
  if (dt.note) detailBlock.push(new Paragraph({ spacing: { before: 60 }, children: [new TextRun({ text: dt.note, size: 16, italics: true, color: GREY, font: "Arial" })] }));
}

// ---------- Recommendation (auto-generated if not supplied) ----------
const recommendation = cfg.recommendation ||
  ("Approve the capital investment. Against a total installed cost of " + usd(totalInvestment) +
   ", the project returns " + usd(totalSavings) + " in gross savings over " + savings.length +
   " periods, pays back in " + paybackLabel + " (" + paybackKind + "), and delivers a net gain of " +
   usd(netGain) + " — a " + roiPct + "% return over the horizon.");

// ---------- Assemble document ----------
const children = [
  new Paragraph({ spacing: { after: 40 }, children: [new TextRun({ text: "EXECUTIVE SUMMARY", bold: true, size: 20, color: BLUE, font: "Arial" })] }),
  new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { after: 20 }, children: [new TextRun(cfg.title || "Capital Investment")] }),
  new Paragraph({ border: { bottom: { style: BorderStyle.SINGLE, size: 12, color: NAVY, space: 4 } }, spacing: { after: 160 }, children: [new TextRun({ text: cfg.subtitle || "", size: 20, italics: true, color: "595959", font: "Arial" })] }),
  kpiStrip,
  new Paragraph({ spacing: { after: 160 }, children: [] }),
  headingBar("Recommendation"),
  new Paragraph({ spacing: { after: 120 }, children: [new TextRun({ text: recommendation, font: "Arial", size: 22 })] }),
  headingBar("Investment Breakdown"),
  investmentTable,
];
if (invNote) children.push(note(invNote));

children.push(headingBar("Financial Return"), cashflowTable, new Paragraph({ spacing: { before: 100, after: 40 }, children: [] }));
children.push(bullet(paybackLabel + " (" + paybackKind + ")" + (cfg.paybackYearsOverride != null ? ", per the company ROI model" : "") + "; the cumulative net position turns positive in the ledger above.", "Payback:"));
children.push(bullet(usd(totalSavings) + " in gross savings against " + usd(totalInvestment) + " invested = " + usd(netGain) + " net, a " + roiPct + "% return over the period.", "ROI:"));
if (savings.length >= 2) children.push(bullet("Savings run from " + usd(savingsVals[1]) + " to " + usd(savingsVals[savingsVals.length - 1]) + " across the horizon, so returns strengthen over the asset's life.", "Trend:"));

if (cfg.operationalBullets && cfg.operationalBullets.length) {
  children.push(headingBar("Operational Impact"));
  cfg.operationalBullets.forEach((b) => children.push(Array.isArray(b) ? bullet(b[1], b[0]) : bullet(b)));
}

detailBlock.forEach((el) => children.push(el));

if (cfg.assumptions && cfg.assumptions.length) {
  children.push(headingBar(cfg.assumptionsTitle || "Key Assumptions & Notes"));
  cfg.assumptions.forEach((a) => children.push(bullet(a)));
}

const footerText = cfg.footerText || (cfg.title ? cfg.title + "  |  Confidential  —  Page " : "Confidential  —  Page ");
const doc = new Document({
  creator: cfg.author || "Automation Engineering",
  numbering: { config: [{ reference: "bullets", levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 500, hanging: 260 } } } }] }] },
  styles: {
    default: { document: { run: { font: "Arial", size: 22 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 34, bold: true, font: "Arial", color: NAVY }, paragraph: { spacing: { before: 120, after: 120 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 26, bold: true, font: "Arial", color: BLUE }, paragraph: { spacing: { before: 260, after: 100 }, outlineLevel: 1 } },
    ],
  },
  sections: [{
    properties: { page: { size: { width: 12240, height: 15840 }, margin: { top: 1080, right: 1440, bottom: 1080, left: 1440 } } },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, border: { top: { style: BorderStyle.SINGLE, size: 4, color: "BFBFBF", space: 4 } }, children: [new TextRun({ text: footerText, size: 16, color: GREY }), new TextRun({ children: [PageNumber.CURRENT], size: 16, color: GREY })] })] }) },
    children,
  }],
});

const outPath = cfg.outputPath || "Executive_Summary.docx";
Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(outPath, buf);
  console.log("Wrote " + outPath + " (" + buf.length + " bytes)");
  console.log("  investment=" + usd(totalInvestment) + "  savings=" + usd(totalSavings) + "  net=" + usd(netGain) + "  payback=" + paybackLabel + "  roi=" + roiPct + "%");
});
