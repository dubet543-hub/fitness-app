import React, { useMemo, useState } from 'react';
import { Bar, Line } from 'react-chartjs-2';
import { monitorSeriesForAthlete } from '../utils/flutterWorkloadMonitorData';
import { buildDailyRecords, buildFlutterSeries } from '../utils/acwr';
import { fmtDate, fmtNum } from '../utils/fmt';
import { CHART_OPTS, ACWR_OPTS } from '../utils/chartDefaults';
import { Card, EmptyState, Icon, Metric } from './ui';

// Workload Monitor — the mobile app's Training / Skill / Daily Total view,
// computed from any athlete's logged sessions.

const TABS = [
  { id: 'training', label: 'Training',    accent: '#38BDF8', title: 'Training Session Exertion' },
  { id: 'skill',    label: 'Skill',       accent: '#34D399', title: 'Skill Session Exertion' },
  { id: 'total',    label: 'Daily Total', accent: '#A78BFA', title: 'Daily Total Load & Exertion' },
];

const RANGES = [
  { key: 'today',     label: 'Latest day' },
  { key: 'yesterday', label: 'Day before' },
  { key: '1w',        label: '1 Week' },
  { key: '2w',        label: '2 Weeks' },
  { key: '28d',       label: '28 Days' },
  { key: 'all',       label: 'All' },
];

export function acwrZone(v) {
  if (!v || v <= 0) return { color: '#8B949E', label: 'No data' };
  if (v < 0.8)  return { color: '#60A5FA', label: 'Undertraining' };
  if (v <= 1.3) return { color: '#34D399', label: 'Sweet spot' };
  if (v <= 1.5) return { color: '#FBBF24', label: 'Caution' };
  return { color: '#F87171', label: 'Danger zone' };
}

const zColor = z => (Math.abs(z) > 2 ? '#F87171' : '#2DD4BF');

// Exertion colour scale on the 0–10 grade (matches the app / sheet).
function exertionColor(v) {
  if (v >= 9)   return '#F87171';
  if (v >= 7.5) return '#FB923C';
  if (v >= 5.5) return '#4ADE80';
  if (v >= 3.5) return '#86EFAC';
  return '#8B949E';
}
const exertionOf = load => (load > 0 ? (Math.log(load) / Math.log(1000)) * 10 : 0);

const dayStart = d => { const x = new Date(d); x.setHours(0, 0, 0, 0); return x; };

// Ranges are anchored on the athlete's most recent logged day, so a quiet week
// never leaves the view empty; the caption states which day that is.
function applyRange(series, range) {
  if (!series.length || range === 'all') return series;
  const last = dayStart(series[series.length - 1].date);
  const back = n => { const d = new Date(last); d.setDate(d.getDate() - n); return d; };
  if (range === 'today')     return series.filter(d => +dayStart(d.date) === +last);
  if (range === 'yesterday') return series.filter(d => +dayStart(d.date) === +back(1));
  const days = range === '1w' ? 7 : range === '2w' ? 14 : 28;
  const cutoff = back(days - 1);
  return series.filter(d => dayStart(d.date) >= cutoff);
}

export function buildSeries(athlete, sessions, tab) {
  const demo = monitorSeriesForAthlete(athlete);
  if (demo) return demo[tab] || [];
  const getLoad = tab === 'training' ? r => r.trainingLoad : tab === 'skill' ? r => r.skillLoad : r => r.totalLoad;
  // buildFlutterSeries names it zScore; the demo series and this view use z.
  return buildFlutterSeries(buildDailyRecords(sessions), getLoad).map(d => ({ ...d, z: d.z ?? d.zScore ?? 0 }));
}

export default function WorkloadMonitor({ athlete, sessions }) {
  const [tab, setTab] = useState('total');
  const [range, setRange] = useState('28d');
  const active = TABS.find(t => t.id === tab);

  const fullSeries = useMemo(() => buildSeries(athlete, sessions, tab), [athlete, sessions, tab]);
  const series = useMemo(() => applyRange(fullSeries, range), [fullSeries, range]);
  const lastDay = fullSeries.length ? fullSeries[fullSeries.length - 1].date : null;

  return (
    <Card
      title="Workload Monitor"
      subtitle={lastDay ? `Most recent logged day: ${fmtDate(lastDay)}` : 'No sessions logged yet'}
      bodyClassName="p-5 space-y-5"
    >
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-3">
        <div role="tablist" aria-label="Load type" className="flex gap-1 border-b border-bdr">
          {TABS.map(t => (
            <button
              key={t.id}
              role="tab"
              aria-selected={tab === t.id}
              onClick={() => setTab(t.id)}
              className="px-4 py-2.5 text-sm font-semibold transition-colors border-b-2 -mb-px"
              style={tab === t.id ? { borderColor: t.accent, color: t.accent } : { borderColor: 'transparent', color: '#8B949E' }}
            >
              {t.label}
            </button>
          ))}
        </div>
        <div className="flex gap-1.5 flex-wrap" role="group" aria-label="Date range">
          {RANGES.map(r => (
            <button
              key={r.key}
              aria-pressed={range === r.key}
              onClick={() => setRange(r.key)}
              className={`px-3 h-8 rounded-lg text-xs font-semibold transition-colors border ${
                range === r.key ? 'bg-accent border-accent text-white' : 'border-bdr text-ts hover:text-tp hover:border-ts'
              }`}
            >
              {r.label}
            </button>
          ))}
        </div>
      </div>

      {series.length
        ? <SectionView series={series} accent={active.accent} title={active.title} />
        : <EmptyState icon="chart" title="No load in this range"
                      hint={fullSeries.length ? 'Pick a wider date range to see earlier sessions.' : 'This athlete has not logged any sessions yet.'} />}
    </Card>
  );
}

function SectionView({ series, accent, title }) {
  const latest = series[series.length - 1];
  const zone = acwrZone(latest.acwr);
  const exertion = exertionOf(latest.load);
  const targetLow = Math.round(latest.chronic * 0.8);
  const targetHigh = Math.round(latest.chronic * 1.3);
  const z = latest.z ?? 0;
  const gc = !latest.load ? '#8B949E' : latest.load < targetLow ? '#60A5FA' : latest.load <= targetHigh ? '#34D399' : '#FBBF24';

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <span className="w-1 h-5 rounded-full" style={{ background: accent }} />
        <h3 className="text-sm font-bold text-tp">{title}</h3>
        <span className="text-xs text-ts">· {fmtDate(latest.date)}</span>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        <Metric label="Session Load"   value={fmtNum(latest.load)}       sub="AU"            color={accent} />
        <Metric label="Exertion"       value={exertion.toFixed(1)}       sub="0–10 grade"    color={exertionColor(exertion)} />
        <Metric label="7-day Acute"    value={fmtNum(latest.acute, 1)}   sub="Rolling"       color="#38BDF8" />
        <Metric label="Chronic (EWMA)" value={fmtNum(latest.chronic, 1)} sub="28-day"        color="#FBBF24" />
        <Metric label="ACWR"           value={latest.acwr > 0 ? latest.acwr.toFixed(2) : '—'} sub={zone.label} color={zone.color} />
        <Metric label="Z-Score"        value={z.toFixed(2)}              sub={Math.abs(z) > 2 ? 'Flagged — unusual load' : 'Normal'} color={zColor(z)} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="rounded-xl px-4 py-4 flex items-center gap-3" style={{ background: `${gc}12`, border: `1px solid ${gc}55` }}>
          <span style={{ color: gc }}><Icon name="target" className="w-6 h-6" /></span>
          <div className="flex-1 min-w-0">
            <div className="text-[11px] text-ts">Tomorrow's Load Target</div>
            <div className="text-2xl font-extrabold tabular-nums" style={{ color: gc }}>{targetLow} – {targetHigh}</div>
          </div>
          <div className="text-right text-[11px] text-ts shrink-0">
            <div>80% – 130%</div>
            <div>of chronic {latest.chronic.toFixed(0)}</div>
          </div>
        </div>
        <div className="bg-card border border-bdr rounded-xl px-4 py-3">
          <div className="text-[11px] text-ts mb-2">ACWR Zone</div>
          <AcwrGauge value={latest.acwr} />
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <Panel title="Load History" legend={
          <Legend items={[
            { label: 'Session load', color: accent, swatch: 'box' },
            { label: '7-day acute', color: '#38BDF8' },
            { label: 'Chronic', color: '#FBBF24', dashed: true },
            { label: 'Exertion', color: '#F472B6' },
          ]} />
        }>
          <div className="h-56"><LoadHistoryChart series={series} accent={accent} /></div>
        </Panel>
        <Panel title="ACWR Trend" legend={
          <Legend items={[
            { label: '0.8 under', color: '#60A5FA', dashed: true },
            { label: '1.3 sweet', color: '#34D399', dashed: true },
            { label: '1.5 caution', color: '#F87171', dashed: true },
          ]} />
        }>
          <div className="h-56"><AcwrTrendChart series={series} accent={accent} /></div>
        </Panel>
      </div>

      <Panel title={`Daily log (latest ${Math.min(10, series.length)})`}>
        <div className="overflow-x-auto -mx-4">
          <table>
            <thead><tr>{['Date', 'Load', 'Exertion', 'Acute', 'Chronic', 'ACWR', 'Z-Score'].map(h => <th key={h}>{h}</th>)}</tr></thead>
            <tbody>
              {[...series].slice(-10).reverse().map(d => {
                const zz = d.z ?? 0, zn = acwrZone(d.acwr), ex = exertionOf(d.load);
                return (
                  <tr key={String(d.date)}>
                    <td className="whitespace-nowrap text-tp">{d.label || fmtDate(d.date)}</td>
                    <td className="tabular-nums">{fmtNum(d.load)}</td>
                    <td className="tabular-nums" style={{ color: exertionColor(ex) }}>{ex.toFixed(1)}</td>
                    <td className="tabular-nums">{fmtNum(d.acute, 1)}</td>
                    <td className="tabular-nums">{d.chronic.toFixed(1)}</td>
                    <td className="tabular-nums font-semibold" style={{ color: zn.color }}>{d.acwr > 0 ? d.acwr.toFixed(2) : '—'}</td>
                    <td className="tabular-nums" style={{ color: zColor(zz) }}>{zz.toFixed(2)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </Panel>
    </div>
  );
}

function Panel({ title, legend, children }) {
  return (
    <div className="bg-card border border-bdr rounded-xl p-4">
      <div className="flex items-start justify-between gap-3 mb-3 flex-wrap">
        <div className="text-sm font-bold text-tp">{title}</div>
        {legend}
      </div>
      {children}
    </div>
  );
}

function Legend({ items }) {
  return (
    <div className="flex gap-3 text-[10px] text-ts flex-wrap">
      {items.map(i => (
        <span key={i.label} className="inline-flex items-center gap-1">
          {i.swatch === 'box'
            ? <span className="inline-block w-2.5 h-2.5 rounded-sm" style={{ background: i.color }} />
            : <span className={`inline-block w-4 border-t-2 ${i.dashed ? 'border-dashed' : ''}`} style={{ borderColor: i.color }} />}
          {i.label}
        </span>
      ))}
    </div>
  );
}

export function AcwrGauge({ value }) {
  const zone = acwrZone(value);
  const pct = (Math.max(0, Math.min(2, value || 0)) / 2) * 100;
  return (
    <div>
      <div className="relative">
        <div className="h-3 rounded-full overflow-hidden flex">
          <div className="bg-blue-400/80"  style={{ flex: 40 }} />
          <div className="bg-green-400/85" style={{ flex: 25 }} />
          <div className="bg-amber-400/85" style={{ flex: 10 }} />
          <div className="bg-red-500/80"   style={{ flex: 25 }} />
        </div>
        {value > 0 && (
          <span className="absolute -top-1 w-1.5 h-5 rounded-full bg-white shadow ring-2 ring-bg -translate-x-1/2"
                style={{ left: `${pct}%` }} aria-hidden="true" />
        )}
      </div>
      <div className="relative h-4 mt-1 text-[10px] text-ts tabular-nums">
        {[0, 0.8, 1.3, 1.5, 2].map(t => (
          <span key={t} className="absolute -translate-x-1/2 first:translate-x-0 last:-translate-x-full" style={{ left: `${t * 50}%` }}>
            {t === 2 ? '2.0+' : t}
          </span>
        ))}
      </div>
      <div className="mt-2 text-xs font-semibold" style={{ color: zone.color }}>
        {value > 0 ? `ACWR ${value.toFixed(2)} — ${zone.label}` : 'No sessions logged yet'}
      </div>
    </div>
  );
}

function LoadHistoryChart({ series, accent }) {
  const labels = series.map(d => d.label || fmtDate(d.date));
  const data = {
    labels,
    datasets: [
      { type: 'bar', label: 'Session load', data: series.map(d => Math.round(d.load)), backgroundColor: `${accent}B3`, borderRadius: 3, order: 3 },
      { type: 'line', label: '7-day acute', data: series.map(d => Math.round(d.acute * 10) / 10), borderColor: '#38BDF8', tension: 0.4, cubicInterpolationMode: 'monotone', pointRadius: 2, borderWidth: 2, order: 1 },
      { type: 'line', label: 'Chronic', data: series.map(d => Math.round(d.chronic * 10) / 10), borderColor: '#FBBF24', tension: 0.4, cubicInterpolationMode: 'monotone', borderDash: [5, 3], pointRadius: 0, borderWidth: 1.5, order: 2 },
      { type: 'line', label: 'Exertion', data: series.map(d => (d.load > 0 ? Math.round(exertionOf(d.load) * 10) / 10 : null)), borderColor: '#F472B6', tension: 0.4, cubicInterpolationMode: 'monotone', pointRadius: 2, borderWidth: 2, yAxisID: 'y1', order: 0, spanGaps: true },
    ],
  };
  const opts = {
    ...CHART_OPTS,
    scales: {
      ...CHART_OPTS.scales,
      y: { ...CHART_OPTS.scales.y, title: { display: true, text: 'Load (AU)', color: '#8B949E', font: { size: 10 } } },
      y1: {
        type: 'linear', position: 'right', min: 0, max: 10,
        ticks: { color: '#F472B6', font: { size: 10 }, stepSize: 2 },
        grid: { drawOnChartArea: false },
        title: { display: true, text: 'Exertion', color: '#F472B6', font: { size: 10 } },
      },
    },
  };
  return <Bar data={data} options={opts} />;
}

function AcwrTrendChart({ series, accent }) {
  const n = series.length;
  const data = {
    labels: series.map(d => d.label || fmtDate(d.date)),
    datasets: [
      { label: 'ACWR', data: series.map(d => Math.min(d.acwr, 2.5)), borderColor: accent, backgroundColor: `${accent}1A`, tension: 0.4, cubicInterpolationMode: 'monotone', pointRadius: 2, borderWidth: 2, fill: true },
      { label: 'Caution', data: Array(n).fill(1.5), borderColor: '#F87171', borderDash: [6, 4], borderWidth: 1.5, pointRadius: 0, fill: false },
      { label: 'Sweet spot', data: Array(n).fill(1.3), borderColor: '#34D399', borderDash: [6, 4], borderWidth: 1.5, pointRadius: 0, fill: false },
      { label: 'Under', data: Array(n).fill(0.8), borderColor: '#60A5FA', borderDash: [6, 4], borderWidth: 1.5, pointRadius: 0, fill: false },
    ],
  };
  return <Line data={data} options={ACWR_OPTS} />;
}
