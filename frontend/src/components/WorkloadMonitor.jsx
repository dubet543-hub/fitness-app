import React, { useMemo, useState } from 'react';
import { Bar, Line } from 'react-chartjs-2';
import { monitorSeriesForAthlete } from '../utils/flutterWorkloadMonitorData';
import { buildDailyRecords, buildFlutterSeries } from '../utils/acwr';
import { fmtDate, fmtNum } from '../utils/fmt';
import { SERIES, STATUS, shortDate, chartOptions, lineDataset, barDataset, thresholdDataset } from '../utils/adminCharts';
import { Card, EmptyState, Icon, Metric, StatusValue } from './ui';

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

// ACWR zones are states, so they wear the reserved status scale — always with
// an icon and a word next to them.
export function acwrZone(v) {
  if (!v || v <= 0) return { color: STATUS.none, label: 'No data', short: '—', icon: 'info' };
  if (v < 0.8)  return { color: STATUS.info,     label: 'Undertraining', short: 'Under',   icon: 'arrowDown' };
  if (v <= 1.3) return { color: STATUS.good,     label: 'Sweet spot',    short: 'Sweet',   icon: 'check' };
  if (v <= 1.5) return { color: STATUS.warning,  label: 'Caution',       short: 'Caution', icon: 'alert' };
  return              { color: STATUS.critical, label: 'Danger zone',   short: 'Danger',  icon: 'alert' };
}

const zStatus = z => (Math.abs(z) > 2
  ? { color: STATUS.serious, label: 'Flagged — unusual load', short: 'Flag', icon: 'alert' }
  : { color: STATUS.good,    label: 'Normal',                 short: '',     icon: 'check' });

// Exertion band on the 0–10 grade (same cut-offs as the app).
function exertionStatus(v) {
  if (v >= 9)   return { color: STATUS.critical, label: 'Very high', icon: 'alert' };
  if (v >= 7.5) return { color: STATUS.serious,  label: 'High',      icon: 'alert' };
  if (v >= 5.5) return { color: STATUS.good,     label: 'Moderate',  icon: 'check' };
  if (v >= 3.5) return { color: STATUS.good,     label: 'Light',     icon: 'check' };
  return              { color: STATUS.none,     label: 'Minimal',   icon: 'info' };
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
              className="px-4 min-h-[44px] text-sm font-semibold transition-colors border-b-2 -mb-px"
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
              className={`px-3 h-11 sm:h-8 rounded-lg text-xs font-semibold transition-colors border ${
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
  const load = Math.round(latest.load);
  const target = !latest.load ? { color: STATUS.none, label: 'No load logged on the latest day', icon: 'info' }
    : latest.load < targetLow ? { color: STATUS.info, label: `Latest load ${load} is below this range`, icon: 'arrowDown' }
    : latest.load <= targetHigh ? { color: STATUS.good, label: `Latest load ${load} is inside this range`, icon: 'check' }
    : { color: STATUS.warning, label: `Latest load ${load} is above this range`, icon: 'alert' };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <span className="w-1 h-5 rounded-full" style={{ background: accent }} />
        <h3 className="text-sm font-bold text-tp">{title}</h3>
        <span className="text-xs text-ts">· {fmtDate(latest.date)}</span>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        <Metric label="Session load"   value={fmtNum(latest.load)}       sub="AU"           color={SERIES.load} />
        <Metric label="Exertion"       value={exertion.toFixed(1)}       status={exertionStatus(exertion)} color={STATUS.none} />
        <Metric label="7-day acute"    value={fmtNum(latest.acute, 1)}   sub="AU · rolling" color={SERIES.acute} />
        <Metric label="Chronic (EWMA)" value={fmtNum(latest.chronic, 1)} sub="AU · 28-day"  color={SERIES.chronic} />
        <Metric label="ACWR"           value={latest.acwr > 0 ? latest.acwr.toFixed(2) : '—'} status={zone} color={STATUS.none} />
        <Metric label="Z-score"        value={z.toFixed(2)}              status={zStatus(z)} color={STATUS.none} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-bg border border-bdr rounded-xl px-4 py-4 flex items-center gap-3">
          <span className="w-10 h-10 rounded-full bg-card flex items-center justify-center text-tp shrink-0"><Icon name="target" className="w-5 h-5" /></span>
          <div className="flex-1 min-w-0">
            <div className="text-xs text-ts">Tomorrow&apos;s load target · 80–130% of chronic {latest.chronic.toFixed(0)}</div>
            <div className="text-2xl font-bold text-tp">{targetLow} – {targetHigh} <span className="text-sm font-medium text-ts">AU</span></div>
            <div className="flex items-center gap-1 text-xs font-semibold mt-0.5" style={{ color: target.color }}>
              <Icon name={target.icon} className="w-3 h-3" />{target.label}
            </div>
          </div>
        </div>
        <div className="bg-bg border border-bdr rounded-xl px-4 py-3">
          <div className="text-xs text-ts mb-2">ACWR zone</div>
          <AcwrGauge value={latest.acwr} />
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <Panel title="Load history" sub="Daily load with 7-day acute and 28-day chronic, AU" legend={
          <Legend items={[
            { label: 'Session load', color: SERIES.load, swatch: 'box' },
            { label: '7-day acute', color: SERIES.acute },
            { label: 'Chronic', color: SERIES.chronic },
          ]} />
        }>
          <div className="h-60"><LoadHistoryChart series={series} /></div>
        </Panel>
        <Panel title="ACWR trend" sub="Acute ÷ chronic, with zone thresholds" legend={
          <Legend items={[
            { label: 'ACWR', color: SERIES.load },
            { label: '0.8 under', color: STATUS.info, dashed: true },
            { label: '1.3 sweet', color: STATUS.good, dashed: true },
            { label: '1.5 danger', color: STATUS.critical, dashed: true },
          ]} />
        }>
          <div className="h-60"><AcwrTrendChart series={series} /></div>
        </Panel>
      </div>

      <Panel title={`Daily log (latest ${Math.min(10, series.length)})`} sub="Table view of the charts above">
        <div className="overflow-x-auto -mx-4">
          <table className="static">
            <thead><tr>{['Date', 'Load', 'Exertion', 'Acute', 'Chronic', 'ACWR', 'Z-score'].map(h => <th key={h}>{h}</th>)}</tr></thead>
            <tbody>
              {[...series].slice(-10).reverse().map(d => {
                const zz = d.z ?? 0, zn = acwrZone(d.acwr), ex = exertionOf(d.load), zs = zStatus(zz);
                return (
                  <tr key={String(d.date)}>
                    <td className="whitespace-nowrap text-tp">{d.label || fmtDate(d.date)}</td>
                    <td className="text-tp">{fmtNum(d.load)}</td>
                    <td>{ex.toFixed(1)}</td>
                    <td>{fmtNum(d.acute, 1)}</td>
                    <td>{d.chronic.toFixed(1)}</td>
                    <td><StatusValue value={d.acwr > 0 ? d.acwr.toFixed(2) : '—'} status={zn} /></td>
                    <td>{zs.short
                      ? <StatusValue value={zz.toFixed(2)} status={zs} />
                      : <span className="text-ts">{zz.toFixed(2)}</span>}</td>
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

function Panel({ title, sub, legend, children }) {
  return (
    <div className="bg-card border border-bdr rounded-xl p-4">
      <div className="flex items-start justify-between gap-3 mb-3 flex-wrap">
        <div>
          <div className="text-sm font-bold text-tp">{title}</div>
          {sub && <div className="text-xs text-ts mt-0.5">{sub}</div>}
        </div>
        {legend}
      </div>
      {children}
    </div>
  );
}

function Legend({ items }) {
  return (
    <div className="flex gap-3 text-[11px] text-ts flex-wrap">
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
        <div className="h-3 rounded-full overflow-hidden flex gap-[2px]">
          <div style={{ flex: 40, background: STATUS.info }} />
          <div style={{ flex: 25, background: STATUS.good }} />
          <div style={{ flex: 10, background: STATUS.warning }} />
          <div style={{ flex: 25, background: STATUS.critical }} />
        </div>
        {value > 0 && (
          <span className="absolute -top-1 w-1.5 h-5 rounded-full bg-white shadow ring-2 ring-bg -translate-x-1/2"
                style={{ left: `${pct}%` }} aria-hidden="true" />
        )}
      </div>
      <div className="relative h-4 mt-1 text-[11px] text-ts tabular-nums">
        {[0, 0.8, 1.3, 1.5, 2].map(t => (
          <span key={t} className="absolute -translate-x-1/2 first:translate-x-0 last:-translate-x-full" style={{ left: `${t * 50}%` }}>
            {t === 2 ? '2.0+' : t}
          </span>
        ))}
      </div>
      <div className="mt-2 flex items-center gap-1.5 text-xs font-semibold" style={{ color: zone.color }}>
        <Icon name={zone.icon} className="w-3.5 h-3.5" />
        <span className="text-tp">{value > 0 ? `ACWR ${value.toFixed(2)}` : 'No sessions logged yet'}</span>
        {value > 0 && <span>· {zone.label}</span>}
      </div>
    </div>
  );
}

function LoadHistoryChart({ series }) {
  const data = {
    labels: series.map(d => d.label || shortDate(d.date)),
    datasets: [
      { ...lineDataset('7-day acute', series.map(d => Math.round(d.acute * 10) / 10), SERIES.acute), order: 1 },
      { ...lineDataset('Chronic', series.map(d => Math.round(d.chronic * 10) / 10), SERIES.chronic), order: 2 },
      { ...barDataset('Session load', series.map(d => Math.round(d.load)), SERIES.load), order: 3 },
    ],
  };
  return <Bar data={data} options={chartOptions()} role="img" aria-label="Load history chart; values are in the daily log table" />;
}

function AcwrTrendChart({ series }) {
  const n = series.length;
  const data = {
    labels: series.map(d => d.label || shortDate(d.date)),
    datasets: [
      lineDataset('ACWR', series.map(d => Math.min(Number(d.acwr.toFixed(2)), 2.5)), SERIES.load, { fill: true }),
      thresholdDataset('Danger above 1.5', 1.5, n, STATUS.critical),
      thresholdDataset('Sweet spot to 1.3', 1.3, n, STATUS.good),
      thresholdDataset('Under below 0.8', 0.8, n, STATUS.info),
    ],
  };
  return <Line data={data} options={chartOptions({ yMin: 0, yMax: 2.5 })} role="img" aria-label="ACWR trend chart; values are in the daily log table" />;
}
