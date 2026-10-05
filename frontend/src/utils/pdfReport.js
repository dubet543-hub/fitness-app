import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { Chart } from 'chart.js';
import { buildSeries, acwrZone, exertionStatus } from '../components/WorkloadMonitor';
import { computeBCA, interpret } from './bodyComposition';
import { dayKey } from './acwr';
import {
  SERIES, STATUS, loadRamp, themeName, setChartTheme, chartOptions, lineDataset, barDataset, thresholdDataset,
} from './adminCharts';

// PDF reports for the coach console. Numbers come from the same functions the
// console uses (buildSeries / acwrZone / computeBCA), so a printed ACWR always
// matches the screen. Charts are rendered with Chart.js off-screen in the
// light palette (it prints well) and placed as images.

const PAGE_W = 210, PAGE_H = 297, M = 14, CONTENT_W = PAGE_W - M * 2;
const INK = [22, 22, 26], MUTED = [95, 95, 102], HAIR = [227, 227, 223], PAPER = [246, 246, 244];
const BRAND = [194, 65, 12]; // light-theme accent, AA on white
const BAND = [17, 17, 19];

const rgb = hex => { const h = hex.replace('#', ''); return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16)); };
const dfmt = d => new Date(d).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
const dshort = d => new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' });
const n0 = v => (v == null || Number.isNaN(v) ? '—' : Math.round(v).toLocaleString('en-IN'));
const n1 = v => (v == null || Number.isNaN(v) ? '—' : Number(v).toFixed(1));
const n2 = v => (v == null || Number.isNaN(v) ? '—' : Number(v).toFixed(2));
const mean = (rows, key) => { const v = rows.map(r => r[key]).filter(x => x != null); return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null; };
const types = s => clean([...(s.primaryTypes || []), ...(s.skillTypes || [])].join(', ')) || '—';
// The PDF's built-in Helvetica only covers Latin-1/WinAnsi; anything else
// (≥, →, curly quotes…) breaks letter spacing for the whole line.
const clean = v => String(v ?? '')
  .replace(/≥/g, '>=').replace(/≤/g, '<=').replace(/→/g, '->').replace(/←/g, '<-')
  .replace(/[‘’]/g, "'").replace(/[“”]/g, '"').replace(/…/g, '...')
  .replace(/[^\u0000-\u00FF–—•‘’“”€™]/g, '');
const slug = s => (s || 'report').replace(/[^a-z0-9]+/gi, '_').replace(/^_|_$/g, '');

export const REPORT_PERIODS = [
  { value: '7', label: '7 days' }, { value: '14', label: '14 days' }, { value: '28', label: '28 days' },
  { value: '90', label: '90 days' }, { value: 'all', label: 'All time' },
];
const periodStart = p => (p === 'all' ? null : (() => { const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - (Number(p) - 1)); return d; })());
const periodLabel = p => (p === 'all' ? 'All recorded history' : `Last ${p} days`);

// ── Chart → image ─────────────────────────────────────────────────────────────
const whiteBg = {
  id: 'pdfWhite',
  beforeDraw(chart) {
    const { ctx, width, height } = chart;
    ctx.save(); ctx.globalCompositeOperation = 'destination-over'; ctx.fillStyle = '#FFFFFF'; ctx.fillRect(0, 0, width, height); ctx.restore();
  },
};

function chartImage({ type, data, options, w = 760, h = 250 }) {
  const holder = document.createElement('div');
  holder.style.cssText = `position:fixed;left:-10000px;top:0;width:${w}px;height:${h}px;`;
  const canvas = document.createElement('canvas');
  canvas.width = w; canvas.height = h;
  canvas.style.width = `${w}px`; canvas.style.height = `${h}px`;
  holder.appendChild(canvas);
  document.body.appendChild(holder);
  const chart = new Chart(canvas.getContext('2d'), {
    type, data,
    options: {
      ...options, responsive: false, maintainAspectRatio: false, animation: false, devicePixelRatio: 2.5,
      plugins: { ...options.plugins, legend: { display: false }, tooltip: { enabled: false } },
    },
    plugins: [whiteBg],
  });
  const url = canvas.toDataURL('image/png');
  chart.destroy();
  holder.remove();
  return url;
}

// Builds chart configs in the light palette regardless of the console theme.
function withLightPalette(fn) {
  const prev = themeName();
  setChartTheme('light');
  try { return fn(); } finally { setChartTheme(prev); }
}

// ── Page furniture ────────────────────────────────────────────────────────────
function header(doc, title, subtitle, right) {
  doc.setFillColor(...BAND); doc.rect(0, 0, PAGE_W, 26, 'F');
  doc.setFillColor(...BRAND); doc.rect(0, 26, PAGE_W, 1.2, 'F');
  doc.setTextColor(255, 255, 255); doc.setFont('helvetica', 'bold'); doc.setFontSize(15);
  doc.text('SOLIDCORE', M, 12);
  doc.setFont('helvetica', 'normal'); doc.setFontSize(8.5); doc.setTextColor(190, 190, 195);
  doc.text('COACH CONSOLE', M, 17.5);
  doc.setTextColor(255, 255, 255); doc.setFont('helvetica', 'bold'); doc.setFontSize(11);
  doc.text(title, PAGE_W - M, 12, { align: 'right' });
  doc.setFont('helvetica', 'normal'); doc.setFontSize(8.5); doc.setTextColor(190, 190, 195);
  doc.text(subtitle, PAGE_W - M, 17.5, { align: 'right' });
  if (right) doc.text(right, PAGE_W - M, 22, { align: 'right' });
  return 36;
}

function footers(doc, who) {
  const pages = doc.getNumberOfPages();
  for (let i = 1; i <= pages; i += 1) {
    doc.setPage(i);
    doc.setDrawColor(...HAIR); doc.setLineWidth(0.2); doc.line(M, PAGE_H - 13, PAGE_W - M, PAGE_H - 13);
    doc.setFont('helvetica', 'normal'); doc.setFontSize(7.5); doc.setTextColor(...MUTED);
    doc.text(`SOLIDCORE Coach Console · ${who} · Generated ${new Date().toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}`, M, PAGE_H - 8);
    doc.text(`Page ${i} of ${pages}`, PAGE_W - M, PAGE_H - 8, { align: 'right' });
    doc.setFontSize(6.5);
    doc.text('Training-load and wellness estimates for coaching use only — not a medical assessment.', M, PAGE_H - 4.5);
  }
}

function section(doc, y, title, sub) {
  doc.setFont('helvetica', 'bold'); doc.setFontSize(12); doc.setTextColor(...INK);
  doc.text(title.toUpperCase(), M, y);
  doc.setDrawColor(...BRAND); doc.setLineWidth(0.8); doc.line(M, y + 2, M + 10, y + 2);
  let ny = y + 7;
  if (sub) { doc.setFont('helvetica', 'normal'); doc.setFontSize(8.5); doc.setTextColor(...MUTED); doc.text(sub, M, ny); ny += 5; }
  return ny;
}

// Row of headline boxes: [{ label, value, note, color }]
function kpis(doc, y, items) {
  const gap = 3, w = (CONTENT_W - gap * (items.length - 1)) / items.length, h = 25;
  items.forEach((k, i) => {
    const x = M + i * (w + gap);
    doc.setFillColor(...PAPER); doc.setDrawColor(...HAIR); doc.setLineWidth(0.2); doc.roundedRect(x, y, w, h, 1.5, 1.5, 'FD');
    doc.setFont('helvetica', 'normal'); doc.setFontSize(7); doc.setTextColor(...MUTED);
    doc.text(k.label.toUpperCase(), x + 3, y + 5.5);
    doc.setFont('helvetica', 'bold'); doc.setFontSize(15); doc.setTextColor(...INK);
    doc.text(String(k.value), x + 3, y + 13.5);
    if (k.note) {
      if (k.color) { doc.setFillColor(...rgb(k.color)); doc.circle(x + 4, y + 18.3, 1, 'F'); }
      doc.setFont('helvetica', 'normal'); doc.setFontSize(7.5); doc.setTextColor(...(k.color ? INK : MUTED));
      doc.text(doc.splitTextToSize(clean(k.note), w - (k.color ? 9 : 6)).slice(0, 2), x + (k.color ? 6.5 : 3), y + 19.2, { lineHeightFactor: 1.15 });
    }
  });
  return y + h + 7;
}

function image(doc, y, url, h, caption) {
  doc.addImage(url, 'PNG', M, y, CONTENT_W, h, undefined, 'FAST');
  let ny = y + h;
  if (caption) { doc.setFont('helvetica', 'normal'); doc.setFontSize(7.5); doc.setTextColor(...MUTED); doc.text(caption, M, ny + 4); ny += 5; }
  return ny + 5;
}

function ensure(doc, y, need) {
  if (y + need <= PAGE_H - 18) return y;
  doc.addPage();
  return 18;
}

function legend(doc, y, items) {
  let x = M;
  doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(...INK);
  items.forEach(({ label, color, kind }) => {
    doc.setFillColor(...rgb(color)); doc.setDrawColor(...rgb(color));
    if (kind === 'box') doc.rect(x, y - 2.4, 3, 3, 'F');
    else { doc.setLineWidth(kind === 'dash' ? 0.4 : 0.8); if (kind === 'dash') doc.setLineDashPattern([1, 0.8], 0); doc.line(x, y - 1, x + 5, y - 1); doc.setLineDashPattern([], 0); }
    doc.text(label, x + (kind === 'box' ? 4.5 : 6.5), y);
    x += doc.getTextWidth(label) + (kind === 'box' ? 9 : 11);
  });
  return y + 3;
}

const tableStyle = {
  theme: 'plain',
  styles: { font: 'helvetica', fontSize: 8, textColor: INK, cellPadding: { top: 2, bottom: 2, left: 2, right: 2 }, lineColor: HAIR, lineWidth: { bottom: 0.15 } },
  headStyles: { fontStyle: 'bold', fontSize: 7, textColor: MUTED, fillColor: PAPER, lineWidth: { bottom: 0.3 } },
  margin: { left: M, right: M },
};

// ── Athlete report ────────────────────────────────────────────────────────────
// options: { period: '7'|'14'|'28'|'90'|'all', sections: { workload, recovery, body, log }, condition }
export function downloadAthleteReport(athlete, { sessions = [], bodyComposition = null, period = '28', sections = {}, condition = null } = {}) {
  const want = { workload: true, recovery: true, body: true, log: true, ...sections };
  const start = periodStart(period);
  const inPeriod = d => !start || new Date(d) >= start;
  const pSessions = sessions.filter(s => inPeriod(s.date)).sort((a, b) => new Date(a.date) - new Date(b.date));
  const full = buildSeries(athlete, sessions, 'total');
  const series = full.filter(d => inPeriod(d.date));
  const latest = full[full.length - 1];
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });

  let y = header(doc, 'Athlete performance report', `${periodLabel(period)}${start ? ` · ${dfmt(start)} – ${dfmt(new Date())}` : ''}`);

  // Identity + condition
  doc.setFont('helvetica', 'bold'); doc.setFontSize(20); doc.setTextColor(...INK);
  doc.text(clean(athlete.name) || 'Athlete', M, y + 2);
  doc.setFont('helvetica', 'normal'); doc.setFontSize(9); doc.setTextColor(...MUTED);
  doc.text(clean([athlete.sport || 'General', athlete.email].filter(Boolean).join('  ·  ')), M, y + 8);
  if (condition) {
    const label = athlete.active === false ? 'Inactive' : condition.label;
    const color = withLightPalette(() => (athlete.active === false ? '#6B6B72' : condition.color));
    doc.setFont('helvetica', 'bold'); doc.setFontSize(11); doc.setTextColor(...INK);
    doc.text(label, PAGE_W - M, y + 1.2, { align: 'right' });
    doc.setFillColor(...rgb(color));
    doc.circle(PAGE_W - M - doc.getTextWidth(label) - 3, y, 1.6, 'F');
    if (condition.reasons?.length && condition.key !== 'ready') {
      doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(...MUTED);
      doc.text(doc.splitTextToSize(clean(condition.reasons.join(' · ')), 100), PAGE_W - M, y + 7, { align: 'right' });
    }
  }
  y += 16;

  const zone = latest ? acwrZone(latest.acwr) : null;
  const readiness = mean(pSessions, 'readinessPercent');
  const avgEx = mean(pSessions, 'scaledGrade');
  const tone = v => (v == null ? undefined : v >= 70 ? STATUS.good : v >= 50 ? STATUS.warning : STATUS.critical);
  y = withLightPalette(() => kpis(doc, y, [
    { label: 'ACWR (latest)', value: latest?.acwr > 0 ? n2(latest.acwr) : '—', note: zone?.label, color: zone?.color },
    { label: 'Avg readiness', value: readiness != null ? `${Math.round(readiness)}%` : '—', note: readiness == null ? 'No check-ins' : readiness >= 70 ? 'Fresh' : readiness >= 50 ? 'Some fatigue' : 'Fatigued', color: tone(readiness) },
    { label: 'Sessions', value: pSessions.length, note: periodLabel(period).toLowerCase() },
    { label: 'Total load', value: n0(pSessions.reduce((a, s) => a + (s.totalLoad || 0), 0)), note: 'AU' },
    { label: 'Avg exertion', value: avgEx != null ? n1(avgEx) : '—', note: avgEx != null ? exertionStatus(avgEx).label : undefined, color: avgEx != null ? exertionStatus(avgEx).color : undefined },
  ]));

  // Workload
  if (want.workload && series.length) {
    const imgs = withLightPalette(() => {
      const labels = series.map(d => dshort(d.date));
      const load = chartImage({
        type: 'bar',
        data: { labels, datasets: [
          { ...lineDataset('7-day acute', series.map(d => d.acute), SERIES.acute), order: 1 },
          { ...lineDataset('Chronic', series.map(d => d.chronic), SERIES.chronic), order: 2 },
          { ...barDataset('Session load', series.map(d => Math.round(d.load)), SERIES.load), order: 3 },
        ] },
        options: chartOptions({ xTicks: 10 }),
      });
      const n = series.length;
      const acwr = chartImage({
        type: 'line',
        data: { labels, datasets: [
          lineDataset('ACWR', series.map(d => Math.min(d.acwr, 2.5)), SERIES.load, { fill: true }),
          thresholdDataset('1.5', 1.5, n, STATUS.critical),
          thresholdDataset('1.3', 1.3, n, STATUS.good),
          thresholdDataset('0.8', 0.8, n, STATUS.info),
        ] },
        options: chartOptions({ yMin: 0, yMax: 2.5, xTicks: 10 }),
      });
      return { load, acwr, colors: { load: SERIES.load, acute: SERIES.acute, chronic: SERIES.chronic, good: STATUS.good, critical: STATUS.critical, info: STATUS.info } };
    });
    y = ensure(doc, y, 80);
    y = section(doc, y, 'Training load', 'Daily load with 7-day acute and 28-day chronic workload, in arbitrary units (AU)');
    y = legend(doc, y, [{ label: 'Session load', color: imgs.colors.load, kind: 'box' }, { label: '7-day acute', color: imgs.colors.acute }, { label: 'Chronic', color: imgs.colors.chronic }]);
    y = image(doc, y + 1, imgs.load, 58);
    y = ensure(doc, y, 72);
    y = section(doc, y, 'Acute : chronic workload ratio', 'Sweet spot 0.8–1.3 · caution 1.3–1.5 · danger above 1.5');
    y = legend(doc, y, [{ label: 'ACWR', color: imgs.colors.load }, { label: '0.8', color: imgs.colors.info, kind: 'dash' }, { label: '1.3', color: imgs.colors.good, kind: 'dash' }, { label: '1.5', color: imgs.colors.critical, kind: 'dash' }]);
    y = image(doc, y + 1, imgs.acwr, 52);
  }

  // Recovery
  if (want.recovery && pSessions.length) {
    const byDay = new Map();
    pSessions.forEach(s => { const k = dayKey(s.date); byDay.set(k, [...(byDay.get(k) || []), s]); });
    const days = [...byDay.entries()].sort(([a], [b]) => (a < b ? -1 : 1));
    const fields = [['sleep', 'Sleep'], ['wellness', 'Wellness'], ['soreness', 'Soreness'], ['fatigue', 'Fatigue']];
    const imgs = withLightPalette(() => ({
      readiness: chartImage({
        type: 'line',
        data: { labels: pSessions.map(s => dshort(s.date)), datasets: [{ ...lineDataset('Readiness', pSessions.map(s => (s.readinessPercent == null ? null : Math.round(s.readinessPercent))), SERIES.load, { fill: true }), pointRadius: 1.5 }] },
        options: chartOptions({ yMin: 0, yMax: 100, xTicks: 10 }),
        h: 200,
      }),
      minis: fields.map(([key]) => chartImage({
        type: 'line',
        data: { labels: days.map(([k]) => dshort(k)), datasets: [lineDataset(key, days.map(([, rs]) => mean(rs, key)), SERIES.load)] },
        options: chartOptions({ yMin: 1, yMax: 5, yStep: 1, reverse: true, xTicks: 4 }),
        w: 380, h: 210,
      })),
    }));
    y = ensure(doc, y, 64);
    y = section(doc, y, 'Readiness', 'Readiness % from each wellness check-in');
    y = image(doc, y, imgs.readiness, 44);
    y = ensure(doc, y, 92);
    y = section(doc, y, 'Wellness ratings', 'Daily average · 1 = best, 5 = worst · higher on the chart is better');
    const mw = (CONTENT_W - 4) / 2, mh = mw * (210 / 380);
    fields.forEach(([key, label], i) => {
      const x = M + (i % 2) * (mw + 4), yy = y + Math.floor(i / 2) * (mh + 8);
      doc.setFont('helvetica', 'bold'); doc.setFontSize(8.5); doc.setTextColor(...INK); doc.text(label, x, yy + 3);
      doc.setFont('helvetica', 'normal'); doc.setTextColor(...MUTED); doc.text(`avg ${n1(mean(pSessions, key))}`, x + mw, yy + 3, { align: 'right' });
      doc.addImage(imgs.minis[i], 'PNG', x, yy + 4.5, mw, mh, undefined, 'FAST');
    });
    y += 2 * (mh + 8) + 2;
    y = ensure(doc, y, 26);
    autoTable(doc, {
      ...tableStyle, startY: y,
      head: [['Sleep', 'Wellness', 'Soreness', 'Fatigue', 'Sleep hours', 'Sleep efficiency', 'Readiness']],
      body: [[n1(mean(pSessions, 'sleep')), n1(mean(pSessions, 'wellness')), n1(mean(pSessions, 'soreness')), n1(mean(pSessions, 'fatigue')),
        n1(mean(pSessions, 'sleepDuration')), mean(pSessions, 'sleepEfficiency') != null ? `${Math.round(mean(pSessions, 'sleepEfficiency'))}%` : '—',
        readiness != null ? `${Math.round(readiness)}%` : '—']],
    });
    doc.setFont('helvetica', 'normal'); doc.setFontSize(7.5); doc.setTextColor(...MUTED);
    doc.text(`Averages over ${pSessions.length} check-in${pSessions.length === 1 ? '' : 's'} in the period.`, M, doc.lastAutoTable.finalY + 4);
    y = doc.lastAutoTable.finalY + 10;
  }

  // Body composition
  const bLatest = bodyComposition?.latest;
  const bca = bLatest ? computeBCA(bLatest) : null;
  if (want.body && bca) {
    const ip = interpret(bca);
    y = ensure(doc, y, 70);
    y = section(doc, y, 'Body composition', clean(`Latest estimate ${dfmt(bLatest.date)} · overall profile: ${ip.overallLabel}`));
    const lbmPct = 100 - bca.bfPercent;
    const pct = kg => (kg / bca.weightKg) * 100;
    const layers = [
      ['Body fat', bca.bfPercent, '#EF4444'], ['Skeletal muscle', bca.smmPercent, '#4AADFF'], ['Organs', pct(bca.essentialOrgans), '#A78BFA'],
      ['Lean fluids', pct(bca.nonMuscleFluid), '#38BDF8'], ['Skin & connective', pct(bca.skinConnective), '#FBBF24'], ['Bone mineral', pct(bca.bmc), '#9CA3AF'],
    ];
    let x = M;
    layers.forEach(([, p, c]) => { const w = (CONTENT_W * p) / 100; doc.setFillColor(...rgb(c)); doc.rect(x, y, Math.max(0, w - 0.5), 6, 'F'); x += w; });
    y += 9;
    let lx = M;
    doc.setFontSize(7.5);
    layers.forEach(([l, p, c]) => {
      const t = `${l} ${n1(p)}%`;
      if (lx + doc.getTextWidth(t) + 6 > PAGE_W - M) { lx = M; y += 4.5; }
      doc.setFillColor(...rgb(c)); doc.rect(lx, y - 2.3, 2.5, 2.5, 'F'); doc.setTextColor(...INK); doc.text(t, lx + 3.5, y);
      lx += doc.getTextWidth(t) + 8;
    });
    y += 5;
    autoTable(doc, {
      ...tableStyle, startY: y,
      head: [['Weight', 'Body fat', 'Lean mass', 'Skeletal muscle', 'SMI', 'FFMI', 'Limb muscle', 'Core muscle']],
      body: [[`${n1(bca.weightKg)} kg`, `${n1(bca.bfPercent)}%`, `${n1(bca.lbm)} kg (${n1(lbmPct)}%)`, `${n1(bca.smmPercent)}%`, n2(bca.smi), n1(bca.ffmi), `${n1(bca.appendicularToTotal)}%`, `${n1(bca.axialToTotal)}%`]],
    });
    y = doc.lastAutoTable.finalY + 6;
    const history = (bodyComposition?.history || []).map(h => ({ h, c: computeBCA(h) }));
    if (history.length) {
      const pts = [{ h: bLatest, c: bca }, ...history].map(({ h, c }) => ({ date: h.date, bf: h.bfPercent ?? c?.bfPercent, smm: h.smmPercent ?? c?.smmPercent, w: h.weightKg }))
        .sort((a, b) => new Date(a.date) - new Date(b.date));
      const img = withLightPalette(() => ({
        url: chartImage({
          type: 'line',
          data: { labels: pts.map(p => dshort(p.date)), datasets: [
            { ...lineDataset('Body fat %', pts.map(p => p.bf), SERIES.acute), pointRadius: 4 },
            { ...lineDataset('Skeletal muscle %', pts.map(p => p.smm), SERIES.load), pointRadius: 4 },
          ] },
          options: chartOptions({ yTitle: '% of body weight', zero: false }),
          h: 200,
        }),
        a: SERIES.acute, l: SERIES.load,
      }));
      y = ensure(doc, y, 56);
      doc.setFont('helvetica', 'bold'); doc.setFontSize(9); doc.setTextColor(...INK);
      doc.text(`Progress · ${pts.length} measurements`, M, y); y += 4;
      y = legend(doc, y + 1, [{ label: 'Body fat %', color: img.a }, { label: 'Skeletal muscle %', color: img.l }]);
      y = image(doc, y + 1, img.url, 44);
    }
    if (ip.actions?.length) {
      y = ensure(doc, y, 20);
      doc.setFont('helvetica', 'bold'); doc.setFontSize(9); doc.setTextColor(...INK); doc.text('Suggestions', M, y); y += 4.5;
      doc.setFont('helvetica', 'normal'); doc.setFontSize(8.5);
      ip.actions.forEach((a, i) => {
        const lines = doc.splitTextToSize(`${i + 1}. ${clean(a)}`, CONTENT_W);
        y = ensure(doc, y, lines.length * 4);
        doc.text(lines, M, y); y += lines.length * 4 + 1;
      });
      y += 4;
    }
  }

  // Session log
  if (want.log && pSessions.length) {
    y = ensure(doc, y, 30);
    y = section(doc, y, 'Session log', `${pSessions.length} session${pSessions.length === 1 ? '' : 's'} · newest first`);
    autoTable(doc, {
      ...tableStyle, startY: y,
      head: [['Date', 'Types', 'Load (AU)', 'Exertion', 'Readiness', 'Sleep', 'Wellness', 'Soreness', 'Fatigue']],
      body: [...pSessions].reverse().map(s => [
        dfmt(s.date), types(s), n0(s.totalLoad), s.scaledGrade != null ? n1(s.scaledGrade) : '—',
        s.readinessPercent != null ? `${Math.round(s.readinessPercent)}%` : '—', s.sleep ?? '—', s.wellness ?? '—', s.soreness ?? '—', s.fatigue ?? '—',
      ]),
      columnStyles: { 1: { cellWidth: 46 } },
      alternateRowStyles: { fillColor: [251, 251, 250] },
    });
  }

  footers(doc, athlete.name || 'Athlete');
  doc.save(`${slug(athlete.name)}_report_${new Date().toISOString().slice(0, 10)}.pdf`);
}

// ── Team report ───────────────────────────────────────────────────────────────
// roster: athletes with `cond` (from athleteCondition); recent: sessions for every athlete.
export function downloadTeamReport({ roster = [], recent = [], days = 21 } = {}) {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  const active = roster.filter(a => a.active);
  const flagged = active.filter(a => a.cond && (a.cond.key === 'risk' || a.cond.key === 'monitor'))
    .sort((a, b) => a.cond.rank - b.cond.rank || (a.cond.readiness ?? 101) - (b.cond.readiness ?? 101));
  const risk = flagged.filter(a => a.cond.key === 'risk').length;
  const rv = active.map(a => a.cond?.readiness ?? a.lastReadiness).filter(v => v != null);
  const avgR = rv.length ? rv.reduce((a, b) => a + b, 0) / rv.length : null;
  const av = active.map(a => a.cond?.acwr).filter(v => v != null);
  const teamAcwr = av.length ? av.reduce((a, b) => a + b, 0) / av.length : null;
  const week = recent.filter(s => Date.now() - new Date(s.date) < 7 * 864e5).length;

  let y = header(doc, 'Team report', `${active.length} active athletes · ${dfmt(new Date())}`);

  y = withLightPalette(() => {
    const zone = teamAcwr != null ? acwrZone(teamAcwr) : null;
    return kpis(doc, y, [
      { label: 'Active athletes', value: active.length, note: `${roster.length} on the roster` },
      { label: 'Need attention', value: flagged.length, note: `${risk} at risk · ${flagged.length - risk} to monitor`, color: risk ? STATUS.critical : flagged.length ? STATUS.warning : STATUS.good },
      { label: 'Avg readiness', value: avgR != null ? `${Math.round(avgR)}%` : '—', note: avgR == null ? 'No check-ins' : avgR >= 70 ? 'Team is fresh' : avgR >= 50 ? 'Carrying fatigue' : 'Fatigued', color: avgR == null ? undefined : avgR >= 70 ? STATUS.good : avgR >= 50 ? STATUS.warning : STATUS.critical },
      { label: 'Sessions · 7 days', value: week, note: 'all athletes' },
      { label: 'Team ACWR', value: teamAcwr != null ? n2(teamAcwr) : '—', note: zone?.label, color: zone?.color },
    ]);
  });

  // Needs attention
  y = section(doc, y, 'Needs attention', "From each athlete's latest ACWR, readiness, Z-score and training gaps");
  if (!flagged.length) {
    doc.setFont('helvetica', 'normal'); doc.setFontSize(9); doc.setTextColor(...INK);
    doc.text('No one is flagged — every active athlete is inside their normal ranges.', M, y + 2); y += 10;
  } else {
    const colors = withLightPalette(() => flagged.map(a => rgb(a.cond.color)));
    autoTable(doc, {
      ...tableStyle, startY: y,
      head: [['Athlete', 'Condition', 'Why', 'Last session']],
      body: flagged.map(a => [clean(a.name), a.cond.label, clean(a.cond.reasons.join(' · ')), a.lastSession ? dfmt(a.lastSession) : '—']),
      columnStyles: { 0: { cellWidth: 38, fontStyle: 'bold' }, 1: { cellWidth: 24 }, 3: { cellWidth: 28 } },
      didParseCell: d => { if (d.section === 'body' && d.column.index === 1) { d.cell.styles.textColor = colors[d.row.index]; d.cell.styles.fontStyle = 'bold'; } },
    });
    y = doc.lastAutoTable.finalY + 10;
  }

  // Load board (heat map)
  const byAth = new Map();
  recent.forEach(r => { const id = r.athlete?._id || r.athlete; byAth.set(id, [...(byAth.get(id) || []), r]); });
  const dayList = Array.from({ length: days }, (_, i) => { const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - (days - 1 - i)); return d; });
  const rows = active.slice().sort((a, b) => (a.cond?.rank ?? 9) - (b.cond?.rank ?? 9) || a.name.localeCompare(b.name)).map(a => {
    const m = new Map();
    (byAth.get(a._id) || []).forEach(s => { const k = dayKey(s.date); m.set(k, (m.get(k) || 0) + (s.totalLoad || 0)); });
    return { a, loads: dayList.map(d => m.get(dayKey(d)) || 0) };
  });
  const nz = rows.flatMap(r => r.loads).filter(v => v > 0).sort((p, q) => p - q);
  const q = p => nz[Math.min(nz.length - 1, Math.floor(p * nz.length))] ?? 0;
  const cuts = [1, 2, 3, 4, 5].map(i => q(i / 6));
  const ramp = withLightPalette(() => loadRamp().map(rgb));
  const nameW = 38, acwrW = 14, cell = (CONTENT_W - nameW - acwrW) / days, rowH = 5.2;
  y = ensure(doc, y, 22 + rows.length * rowH);
  y = section(doc, y, 'Team load board', `Daily training load, last ${days} days · paler = lighter day, darker = heavier day`);
  doc.setFont('helvetica', 'normal'); doc.setFontSize(6.5); doc.setTextColor(...MUTED);
  dayList.forEach((d, i) => { if (i % 7 === 6 || i === days - 1) doc.text(i === days - 1 ? 'Today' : dshort(d), M + nameW + (i + 1) * cell, y, { align: 'right' }); });
  doc.text('ACWR', PAGE_W - M, y, { align: 'right' });
  y += 2;
  rows.forEach(({ a, loads }) => {
    if (y + rowH > PAGE_H - 18) { doc.addPage(); y = 18; }
    const c = withLightPalette(() => rgb(a.cond?.color || '#6B6B72'));
    doc.setFillColor(...c); doc.circle(M + 1.2, y + rowH / 2, 0.9, 'F');
    doc.setFontSize(7.5); doc.setTextColor(...INK); doc.text(doc.splitTextToSize(a.name, nameW - 5)[0], M + 3.5, y + rowH / 2 + 1.2);
    loads.forEach((v, i) => {
      const col = v > 0 ? ramp[cuts.filter(cc => v > cc).length] : [236, 236, 232];
      doc.setFillColor(...col); doc.rect(M + nameW + i * cell + 0.3, y + 0.4, cell - 0.6, rowH - 0.8, 'F');
    });
    doc.setFont('helvetica', 'bold'); doc.text(a.cond?.acwr != null ? n2(a.cond.acwr) : '—', PAGE_W - M, y + rowH / 2 + 1.2, { align: 'right' });
    doc.setFont('helvetica', 'normal');
    y += rowH;
  });
  y += 4;
  doc.setFontSize(7); doc.setTextColor(...MUTED); doc.text('Less', M + nameW, y + 2.2);
  ramp.forEach((c, i) => { doc.setFillColor(...c); doc.rect(M + nameW + 7 + i * 4.5, y, 3.5, 3, 'F'); });
  doc.text('More', M + nameW + 7 + ramp.length * 4.5 + 1, y + 2.2);
  y += 10;

  // Roster table
  y = ensure(doc, y, 30);
  y = section(doc, y, 'Roster', 'Every athlete, worst condition first');
  const colors = withLightPalette(() => roster.map(a => rgb(a.active ? a.cond?.color || '#6B6B72' : '#6B6B72')));
  const sorted = roster.map((a, i) => ({ a, i })).sort((p, q2) => (p.a.active ? p.a.cond?.rank ?? 9 : 10) - (q2.a.active ? q2.a.cond?.rank ?? 9 : 10) || p.a.name.localeCompare(q2.a.name));
  autoTable(doc, {
    ...tableStyle, startY: y,
    head: [['Athlete', 'Sport', 'Condition', 'ACWR', 'Readiness', `Load · ${days}d (AU)`, 'Last session']],
    body: sorted.map(({ a }) => {
      const total = (byAth.get(a._id) || []).filter(s => Date.now() - new Date(s.date) < days * 864e5).reduce((t, s) => t + (s.totalLoad || 0), 0);
      const r = a.cond?.readiness ?? a.lastReadiness;
      return [a.name, a.sport || 'General', a.active ? a.cond?.label || '—' : 'Inactive', a.cond?.acwr != null ? n2(a.cond.acwr) : '—',
        r != null ? `${Math.round(r)}%` : '—', n0(total), a.lastSession ? dfmt(a.lastSession) : '—'];
    }),
    columnStyles: { 0: { fontStyle: 'bold' } },
    didParseCell: d => { if (d.section === 'body' && d.column.index === 2) { d.cell.styles.textColor = colors[sorted[d.row.index].i]; d.cell.styles.fontStyle = 'bold'; } },
  });

  footers(doc, 'Team report');
  doc.save(`SOLIDCORE_team_report_${new Date().toISOString().slice(0, 10)}.pdf`);
}
