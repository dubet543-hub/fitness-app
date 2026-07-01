import React, { useState, useMemo } from 'react';
import { Bar, Line } from 'react-chartjs-2';
import { monitorSeriesForAthlete } from '../utils/flutterWorkloadMonitorData';
import { buildDailyRecords, buildFlutterSeries } from '../utils/acwr';
import { fmtDate, fmtNum } from '../utils/fmt';
import { CHART_OPTS, ACWR_OPTS } from '../utils/chartDefaults';

// ── Zone pill for chart legend ─────────────────────────────────────────────────
function ZonePill({ color, label, zone }) {
  return (
    <span className="inline-flex items-center gap-1 text-[10px]">
      <span className="inline-block w-5 border-t-2 border-dashed" style={{ borderColor: color }} />
      <span style={{ color }} className="font-semibold">{label}</span>
      <span className="text-ts">({zone})</span>
    </span>
  );
}

// ── Zone helpers ───────────────────────────────────────────────────────────────
function acwrZone(v) {
  if (!v || v <= 0) return { color: '#6B7280', label: 'No Data' };
  if (v < 0.8)  return { color: '#60A5FA', label: 'Undertraining' };
  if (v <= 1.3) return { color: '#34D399', label: 'Sweet Spot ✓' };
  if (v <= 1.5) return { color: '#FBBF24', label: 'Caution' };
  return { color: '#F87171', label: 'Danger Zone' };
}

function zColor(z) {
  return Math.abs(z) > 2 ? '#F87171' : '#2DD4BF';
}

// Exertion color scale (matches Google Sheet conditional formatting on the 0–10 grade)
function exertionColor(v) {
  if (v >= 9)   return '#FF0000'; // red       — ≥ 9
  if (v >= 7.5) return '#E69138'; // orange    — 7.5–9
  if (v >= 5.5) return '#38761D'; // dark green — 5.5–7.5
  if (v >= 3.5) return '#93C47D'; // light green — 3.5–5.5
  return '#CCCCCC';               // gray      — < 3.5
}

const FILTERS = [
  { key: 'today',     label: 'Today' },
  { key: 'yesterday', label: 'Yesterday' },
  { key: '1w',        label: '1 Week' },
  { key: '2w',        label: '2 Weeks' },
  { key: '28d',       label: '28 Days' },
];

function parseSeriesDate(d) {
  if (d.date) return new Date(d.date);
  if (d.label) {
    const [day, month] = d.label.split('/').map(Number);
    return new Date(2025, month - 1, day);
  }
  return null;
}

function applyRange(series, range) {
  if (!series.length || range === '28d') return series;
  const lastDate = parseSeriesDate(series[series.length - 1]);
  if (!lastDate) return series;
  const sameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  if (range === 'today') {
    return series.filter(d => { const dt = parseSeriesDate(d); return dt && sameDay(dt, lastDate); });
  }
  if (range === 'yesterday') {
    const yest = new Date(lastDate); yest.setDate(yest.getDate() - 1);
    return series.filter(d => { const dt = parseSeriesDate(d); return dt && sameDay(dt, yest); });
  }
  const days = range === '1w' ? 7 : 14;
  const cutoff = new Date(lastDate);
  cutoff.setDate(cutoff.getDate() - days + 1);
  cutoff.setHours(0, 0, 0, 0);
  return series.filter(d => { const dt = parseSeriesDate(d); return dt && dt >= cutoff; });
}

// ── Metric card (Flutter MetricCard equivalent) ────────────────────────────────
function MetricCard({ label, value, sub, color }) {
  return (
    <div
      className="rounded-xl p-3 flex-1 min-w-0"
      style={{
        background: `${color}14`,
        border: `1px solid ${color}4D`,
      }}
    >
      <div className="text-[11px] text-ts mb-1">{label}</div>
      <div className="text-xl font-extrabold leading-tight truncate" style={{ color }}>{value}</div>
      {sub && <div className="text-[10px] text-ts mt-0.5 truncate">{sub}</div>}
    </div>
  );
}

// ── ACWR gauge (Flutter AcwrGauge equivalent) ──────────────────────────────────
function AcwrGauge({ value }) {
  const clamped = Math.max(0, Math.min(2, value || 0));
  const zone = acwrZone(value);
  const pct = (clamped / 2) * 100;

  return (
    <div className="space-y-2">
      {/* Color bar */}
      <div className="h-4 rounded-md overflow-hidden flex">
        <div className="bg-blue-400/80"   style={{ flex: 40 }} />
        <div className="bg-green-400/85"  style={{ flex: 50 }} />
        <div className="bg-amber-400/85"  style={{ flex: 10 }} />
        <div className="bg-red-500/80"    style={{ flex: 100 }} />
      </div>
      {/* Tick labels */}
      <div className="flex justify-between text-[10px] text-ts px-0.5">
        <span>0</span><span>0.8</span><span>1.3</span><span>1.5</span><span>2.0+</span>
      </div>
      {/* Pointer */}
      <div className="relative h-5">
        <div
          className="absolute -translate-x-1/2 text-white text-base leading-none"
          style={{ left: `${pct}%` }}
        >▼</div>
      </div>
      {/* Badge */}
      <div className="flex justify-center">
        <span
          className="px-4 py-1.5 rounded-full text-xs font-bold"
          style={{
            color: zone.color,
            background: `${zone.color}26`,
            border: `1px solid ${zone.color}80`,
          }}
        >
          {value > 0 ? `ACWR ${value.toFixed(2)} — ${zone.label}` : 'No sessions logged yet'}
        </span>
      </div>
      {/* Zone legend */}
      <div className="flex justify-around text-[10px] text-center mt-1">
        <span className="text-blue-400">Under<br/>Training</span>
        <span className="text-green-400">Sweet<br/>Spot ✓</span>
        <span className="text-amber-400">Caution</span>
        <span className="text-red-400">Danger<br/>Zone</span>
      </div>
    </div>
  );
}

// ── Load History chart ─────────────────────────────────────────────────────────
function LoadHistoryChart({ series, accentColor }) {
  const labels = series.map(d => d.label || fmtDate(d.date));
  const data = {
    labels,
    datasets: [
      {
        type: 'bar',
        label: 'Session Load',
        data: series.map(d => Math.round(d.load)),
        backgroundColor: `${accentColor}B3`,
        borderRadius: 3,
        order: 3,
      },
      {
        type: 'line',
        label: '7-day Acute',
        data: series.map(d => Math.round(d.acute * 10) / 10),
        borderColor: '#38BDF8',
        backgroundColor: 'transparent',
        tension: 0.4,
        cubicInterpolationMode: 'monotone',
        pointRadius: 2,
        borderWidth: 2,
        order: 1,
      },
      {
        type: 'line',
        label: 'Chronic EWMA',
        data: series.map(d => Math.round(d.chronic * 10) / 10),
        borderColor: '#FBBF24',
        backgroundColor: 'transparent',
        tension: 0.4,
        cubicInterpolationMode: 'monotone',
        borderDash: [5, 3],
        pointRadius: 0,
        borderWidth: 1.5,
        order: 2,
      },
      {
        type: 'line',
        label: 'Exertion',
        data: series.map(d => d.load > 0 ? Math.round((Math.log(d.load) / Math.log(1000)) * 100) / 10 : null),
        borderColor: '#F472B6',
        backgroundColor: 'transparent',
        tension: 0.4,
        cubicInterpolationMode: 'monotone',
        pointRadius: 2,
        borderWidth: 2,
        yAxisID: 'y1',
        order: 0,
        spanGaps: true,
      },
    ],
  };
  const opts = {
    ...CHART_OPTS,
    plugins: { ...CHART_OPTS.plugins, legend: { display: true, position: 'bottom', labels: { color: '#8B949E', font: { size: 9 }, boxWidth: 10, padding: 8 } } },
    scales: {
      ...CHART_OPTS.scales,
      y1: {
        type: 'linear',
        position: 'right',
        min: 0,
        max: 10,
        ticks: { color: '#8B949E', font: { size: 9 }, stepSize: 2 },
        grid: { drawOnChartArea: false, color: '#21262D' },
        title: { display: true, text: 'Exertion', color: '#F472B6', font: { size: 9 } },
      },
    },
  };
  return (
    <div className="h-52">
      <Bar data={data} options={opts} />
    </div>
  );
}

// ── ACWR Trend chart ──────────────────────────────────────────────────────────
function AcwrTrendChart({ series, accentColor }) {
  const labels = series.map(d => d.label || fmtDate(d.date));
  const data = {
    labels,
    datasets: [
      {
        data: series.map(d => Math.min(d.acwr, 2.5)),
        borderColor: accentColor,
        backgroundColor: `${accentColor}1A`,
        tension: 0.4,
        cubicInterpolationMode: 'monotone',
        pointRadius: 2,
        borderWidth: 2,
        fill: true,
      },
      { data: Array(series.length).fill(1.5), borderColor: '#F87171', borderDash: [6, 4], borderWidth: 2, pointRadius: 0, fill: false },
      { data: Array(series.length).fill(1.3), borderColor: '#34D399', borderDash: [6, 4], borderWidth: 2, pointRadius: 0, fill: false },
      { data: Array(series.length).fill(0.8), borderColor: '#60A5FA', borderDash: [6, 4], borderWidth: 2, pointRadius: 0, fill: false },
    ],
  };
  return (
    <div className="h-44">
      <Line data={data} options={{ ...ACWR_OPTS, plugins: { ...ACWR_OPTS.plugins, legend: { display: false } } }} />
    </div>
  );
}

// ── Tab panel (Training / Skill / Daily Total) ─────────────────────────────────
function SectionView({ series, sectionTitle, accentColor }) {
  const latest = series[series.length - 1];
  if (!latest) return <div className="py-16 text-center text-ts text-sm">No data available.</div>;

  const zone = acwrZone(latest.acwr);
  const exertion = latest.load > 0 ? (Math.log(latest.load) / Math.log(1000)) * 10 : 0;
  const targetLow  = Math.round(latest.chronic * 0.8);
  const targetHigh = Math.round(latest.chronic * 1.3);

  function guidanceColor(load) {
    if (!load) return '#6B7280';
    if (load < targetLow)  return '#60A5FA';
    if (load <= targetHigh) return '#34D399';
    return '#FBBF24';
  }
  const gc = guidanceColor(latest.load);

  return (
    <div className="space-y-4">
      {/* Section label bar */}
      <div className="flex items-center gap-2">
        <div className="w-1 h-5 rounded-full" style={{ background: accentColor }} />
        <span className="text-sm font-bold text-tp">{sectionTitle}</span>
      </div>

      {/* Metric Row 1 */}
      <div className="flex gap-3">
        <MetricCard label="Session Load"    value={fmtNum(latest.load)}         color={accentColor} />
        <MetricCard label="Exertion"        value={exertion.toFixed(1)}          color={exertionColor(exertion)} />
        <MetricCard label="7-day Acute"     value={fmtNum(latest.acute, 1)}      color="#38BDF8" />
      </div>

      {/* Metric Row 2 */}
      <div className="flex gap-3">
        <MetricCard label="Chronic (EWMA)" value={fmtNum(latest.chronic, 1)}    color="#FBBF24" />
        <MetricCard label="ACWR"           value={latest.acwr > 0 ? latest.acwr.toFixed(2) : '—'} sub={zone.label} color={zone.color} />
        <MetricCard label="Z-Score"        value={(latest.z ?? 0).toFixed(2)}   sub={Math.abs(latest.z ?? 0) > 2 ? '⚠ Flagged' : 'Normal'} color={zColor(latest.z ?? 0)} />
      </div>

      {/* Load Guidance panel */}
      <div
        className="rounded-xl px-4 py-3 flex items-center gap-3"
        style={{ background: `${gc}14`, border: `1px solid ${gc}66` }}
      >
        <svg className="w-5 h-5 shrink-0" fill="none" stroke={gc} strokeWidth="2" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/>
          <line x1="12" y1="3" x2="12" y2="1"/><line x1="12" y1="21" x2="12" y2="23"/>
          <line x1="3" y1="12" x2="1" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/>
        </svg>
        <div className="flex-1 min-w-0">
          <div className="text-[11px] text-ts">Tomorrow's Load Target</div>
          <div className="text-lg font-extrabold mt-0.5" style={{ color: gc }}>
            {targetLow} – {targetHigh}
          </div>
        </div>
        <div className="text-right text-[11px] text-ts shrink-0">
          <div>80% – 130%</div>
          <div>of Chronic {latest.chronic.toFixed(0)}</div>
        </div>
      </div>

      {/* ACWR Gauge */}
      <Panel title="ACWR Zone">
        <AcwrGauge value={latest.acwr} />
      </Panel>

      {/* Load History chart */}
      <Panel title="Load History" legend={
        <div className="flex gap-4 text-[10px] text-ts flex-wrap">
          <span><span className="inline-block w-2.5 h-2.5 rounded-sm mr-1" style={{ background: accentColor }} />Session Load</span>
          <span><span className="inline-block w-4 h-0.5 bg-sky-400 mr-1 align-middle" />7-day Acute</span>
          <span><span className="inline-block w-4 border-t border-dashed border-amber-400 mr-1 align-middle" />Chronic EWMA</span>
          <span><span className="inline-block w-4 h-0.5 mr-1 align-middle" style={{ background: '#F472B6' }} />Exertion</span>
        </div>
      }>
        <LoadHistoryChart series={series} accentColor={accentColor} />
      </Panel>

      {/* ACWR Trend chart */}
      <Panel title="ACWR Trend" sub={
        <span className="flex items-center gap-2 flex-wrap">
          <ZonePill color="#60A5FA" label="0.8" zone="Under" />
          <ZonePill color="#34D399" label="1.3" zone="Sweet" />
          <ZonePill color="#F87171" label="1.5" zone="Caution" />
        </span>
      }>
        <AcwrTrendChart series={series} accentColor={accentColor} />
      </Panel>

      {/* Session log */}
      <Panel title="Session Log (latest 10)">
        <div className="space-y-2">
          {[...series].slice(-10).reverse().map((d, i) => (
            <SessionRow key={i} d={d} accentColor={accentColor} />
          ))}
        </div>
      </Panel>
    </div>
  );
}

function Panel({ title, sub, legend, children }) {
  return (
    <div className="bg-card border border-bdr rounded-xl p-4">
      <div className="flex items-start justify-between gap-2 mb-3">
        <div>
          <div className="text-sm font-bold text-tp">{title}</div>
          {sub && <div className="text-[11px] text-ts mt-0.5">{sub}</div>}
        </div>
        {legend}
      </div>
      {children}
    </div>
  );
}

function SessionRow({ d, accentColor }) {
  const zone = acwrZone(d.acwr);
  return (
    <div className="flex items-center gap-2 bg-bg rounded-lg px-3 py-2 border border-bdr">
      <span className="text-xs font-bold text-ts w-12 shrink-0">{d.label || fmtDate(d.date)}</span>
      <div className="w-px h-6 bg-bdr shrink-0" />
      <div className="flex flex-1 gap-1 min-w-0">
        {[
          { l: 'Load',    v: fmtNum(d.load),          c: accentColor },
          { l: 'Acute',   v: fmtNum(d.acute, 1),       c: '#38BDF8' },
          { l: 'Chronic', v: d.chronic.toFixed(1),      c: '#FBBF24' },
          { l: 'ACWR',    v: d.acwr > 0 ? d.acwr.toFixed(2) : '—', c: zone.color },
          { l: 'Z',       v: (d.z ?? 0).toFixed(2),    c: zColor(d.z ?? 0) },
        ].map(({ l, v, c }) => (
          <div key={l} className="flex-1 text-center min-w-0">
            <div className="text-[9px] text-ts">{l}</div>
            <div className="text-[11px] font-bold truncate" style={{ color: c }}>{v}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Main page ──────────────────────────────────────────────────────────────────
const TABS = [
  { id: 'training', label: 'Training',    accent: '#38BDF8' },
  { id: 'skill',    label: 'Skill',       accent: '#34D399' },
  { id: 'total',    label: 'Daily Total', accent: '#A78BFA' },
];

const SECTION_TITLES = {
  training: 'Training Session Exertion',
  skill:    'Skill Session Exertion',
  total:    'Daily Total Load & Exertion',
};

export default function WorkloadMonitorPage({ athletes = [], sessions = [], athlete = null }) {
  const [tab, setTab] = useState('total');
  const [athleteKey, setAthleteKey] = useState('ats001');
  const [filter, setFilter] = useState('28d');

  // Build series — prefer static monitor data (ATS-001/002), fall back to live sessions
  const series = useMemo(() => {
    // Static athlete selected
    if (athleteKey === 'ats001') {
      const data = monitorSeriesForAthlete({ name: 'ATS-2025-001', email: 'ats-001' });
      return data?.[tab] || [];
    }
    if (athleteKey === 'ats002') {
      const data = monitorSeriesForAthlete({ name: 'ATS-2025-002', email: 'ats-002' });
      return data?.[tab] || [];
    }
    // Live athlete with static data
    if (athlete) {
      const monitor = monitorSeriesForAthlete(athlete);
      if (monitor) return monitor[tab] || [];
    }
    // Compute from sessions — normalize zScore → z to match static data shape
    const records = buildDailyRecords(sessions);
    const getLoad =
      tab === 'training' ? r => r.trainingLoad :
      tab === 'skill'    ? r => r.skillLoad :
      r => r.totalLoad;
    return buildFlutterSeries(records, getLoad).map(d => ({ ...d, z: d.z ?? d.zScore ?? 0 }));
  }, [tab, athleteKey, athlete, sessions]);

  const activeTab = TABS.find(t => t.id === tab);
  const filteredSeries = useMemo(() => applyRange(series, filter), [series, filter]);

  return (
    <div className="space-y-5">
      {/* Athlete selector */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="text-sm font-bold text-tp">Workload Monitor</div>
        <div className="flex gap-1 bg-card border border-bdr rounded-xl p-1">
          {[
            { key: 'ats001', label: 'ATS-001' },
            { key: 'ats002', label: 'ATS-002' },
          ].map(({ key, label }) => (
            <button
              key={key}
              onClick={() => setAthleteKey(key)}
              className="px-3 py-1.5 rounded-lg text-xs font-bold transition"
              style={athleteKey === key
                ? { background: '#FF6B35', color: '#fff' }
                : { color: '#8B949E' }}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      {/* Tab bar */}
      <div className="flex gap-1 border-b border-bdr pb-0">
        {TABS.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className="px-4 py-2.5 text-sm font-semibold transition border-b-2 -mb-px"
            style={tab === t.id
              ? { borderColor: t.accent, color: t.accent }
              : { borderColor: 'transparent', color: '#8B949E' }}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Filter bar */}
      <div className="flex gap-1.5 flex-wrap">
        {FILTERS.map(f => (
          <button
            key={f.key}
            onClick={() => setFilter(f.key)}
            className="px-3 py-1.5 rounded-lg text-xs font-semibold transition"
            style={filter === f.key
              ? { background: '#FF6B35', color: '#fff', border: '1px solid #FF6B35' }
              : { background: 'transparent', color: '#8B949E', border: '1px solid #30363D' }}
          >
            {f.label}
          </button>
        ))}
      </div>

      {/* Content */}
      <SectionView
        series={filteredSeries}
        sectionTitle={SECTION_TITLES[tab]}
        accentColor={activeTab.accent}
      />
    </div>
  );
}
