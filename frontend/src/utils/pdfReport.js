import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { computeStats } from './acwr';
import { computeBCA, interpret } from './bodyComposition';
import { fmtDate, fmtNum } from './fmt';

const ACCENT = [255, 107, 53]; // brand orange
const INK = [30, 30, 30];
const MUTED = [110, 110, 110];

function avg(sessions, key) {
  const vals = sessions.map(s => s[key]).filter(v => v != null);
  if (!vals.length) return null;
  return vals.reduce((a, b) => a + b, 0) / vals.length;
}

function sectionTitle(doc, y, text) {
  doc.setFontSize(12);
  doc.setTextColor(...INK);
  doc.setFont(undefined, 'bold');
  doc.text(text, 14, y);
  doc.setFont(undefined, 'normal');
  return y + 6;
}

// Builds and downloads a single-athlete PDF report covering summary load
// stats, recovery averages, body composition (if synced), and the session
// log — everything visible across Athletes/Analytics/Recovery for that
// athlete, so it can be shared without opening the admin site.
export function downloadAthleteReport(athlete, { sessions = [], bodyComposition = null } = {}) {
  const doc = new jsPDF();
  const sorted = [...sessions].sort((a, b) => new Date(b.date) - new Date(a.date));

  doc.setFontSize(18);
  doc.setTextColor(...ACCENT);
  doc.setFont(undefined, 'bold');
  doc.text('SolidCore AMS — Athlete Report', 14, 18);

  doc.setFontSize(10);
  doc.setTextColor(...MUTED);
  doc.setFont(undefined, 'normal');
  doc.text(`Generated ${new Date().toLocaleString('en-GB')}`, 14, 25);

  doc.setFontSize(13);
  doc.setTextColor(...INK);
  doc.setFont(undefined, 'bold');
  doc.text(athlete.name || 'Athlete', 14, 36);
  doc.setFont(undefined, 'normal');
  doc.setFontSize(10);
  doc.setTextColor(...MUTED);
  doc.text(`${athlete.email || '—'}  ·  ${athlete.sport || 'General'}`, 14, 42);

  let y = 52;

  // ── Load summary ──────────────────────────────────────────────────────
  const stats = computeStats(sessions);
  y = sectionTitle(doc, y, 'Load Summary');
  autoTable(doc, {
    startY: y,
    theme: 'grid',
    head: [['Acute Load (7d)', 'Chronic Load (EWMA 28d)', 'ACWR', 'Z-Score', 'Sessions']],
    body: [[
      fmtNum(stats.acuteLoad), fmtNum(stats.chronicLoad, 1), fmtNum(stats.acwr, 2),
      stats.zScore != null ? fmtNum(stats.zScore, 2) : '—', sessions.length,
    ]],
    headStyles: { fillColor: ACCENT },
    margin: { left: 14, right: 14 },
  });
  y = doc.lastAutoTable.finalY + 10;

  // ── Recovery averages ────────────────────────────────────────────────
  y = sectionTitle(doc, y, 'Recovery (averages over selected sessions)');
  autoTable(doc, {
    startY: y,
    theme: 'grid',
    head: [['Sleep', 'Wellness', 'Soreness', 'Fatigue', 'Sleep Dur. (h)', 'Sleep Eff. (%)', 'Readiness (%)']],
    body: [[
      fmtNum(avg(sessions, 'sleep'), 1),
      fmtNum(avg(sessions, 'wellness'), 1),
      fmtNum(avg(sessions, 'soreness'), 1),
      fmtNum(avg(sessions, 'fatigue'), 1),
      fmtNum(avg(sessions, 'sleepDuration'), 1),
      fmtNum(avg(sessions, 'sleepEfficiency'), 0),
      fmtNum(avg(sessions, 'readinessPercent'), 0),
    ]],
    headStyles: { fillColor: ACCENT },
    margin: { left: 14, right: 14 },
  });
  y = doc.lastAutoTable.finalY + 10;

  // ── Body composition ─────────────────────────────────────────────────
  const latest = bodyComposition?.latest;
  const bca = latest ? computeBCA(latest) : null;
  if (bca) {
    const ip = interpret(bca);
    if (y > 250) { doc.addPage(); y = 18; }
    y = sectionTitle(doc, y, `Body Composition (as of ${fmtDate(latest.date)}) — ${ip.overallLabel}`);
    autoTable(doc, {
      startY: y,
      theme: 'grid',
      head: [['Body Fat %', 'Lean Mass (kg)', 'Skeletal Muscle %', 'FFMI', 'Appendicular %', 'Axial %']],
      body: [[
        fmtNum(bca.bfPercent, 1), fmtNum(bca.lbm, 1), fmtNum(bca.smmPercent, 1),
        fmtNum(bca.ffmi, 1), fmtNum(bca.appendicularToTotal, 1), fmtNum(bca.axialToTotal, 1),
      ]],
      headStyles: { fillColor: ACCENT },
      margin: { left: 14, right: 14 },
    });
    y = doc.lastAutoTable.finalY + 10;
  }

  // ── Session log ───────────────────────────────────────────────────────
  if (y > 240) { doc.addPage(); y = 18; }
  y = sectionTitle(doc, y, 'Session Log');
  autoTable(doc, {
    startY: y,
    theme: 'striped',
    head: [['Date', 'Load', 'Grade', 'Readiness', 'Sleep', 'Wellness', 'Soreness', 'Fatigue']],
    body: sorted.map(s => [
      fmtDate(s.date),
      fmtNum(s.totalLoad),
      s.scaledGrade != null ? fmtNum(s.scaledGrade, 1) : '—',
      s.readinessPercent != null ? `${fmtNum(s.readinessPercent)}%` : '—',
      s.sleep ?? '—', s.wellness ?? '—', s.soreness ?? '—', s.fatigue ?? '—',
    ]),
    headStyles: { fillColor: ACCENT },
    styles: { fontSize: 8 },
    margin: { left: 14, right: 14 },
  });

  const filename = `${(athlete.name || 'athlete').replace(/[^a-z0-9]+/gi, '_')}_report_${new Date().toISOString().slice(0, 10)}.pdf`;
  doc.save(filename);
}
