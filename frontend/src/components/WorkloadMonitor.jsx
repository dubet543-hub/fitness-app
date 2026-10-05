import React, { useEffect, useId, useMemo, useState } from 'react';
import InteractiveChart, { LegendToggle } from './InteractiveChart';
import { monitorSeriesForAthlete } from '../utils/flutterWorkloadMonitorData';
import { buildDailyRecords, buildFlutterSeries, dayKey } from '../utils/acwr';
import { fmtDate, fmtNum } from '../utils/fmt';
import { SERIES, STATUS, shortDate, chartOptions, lineDataset, barDataset, thresholdDataset } from '../utils/adminCharts';
import { Button, Card, EmptyState, Icon, Metric, StatusValue } from './ui';

// Workload Monitor — the mobile app's Training / Skill / Daily Total view,
// computed from any athlete's logged sessions.

// Tabs share the brand accent; colour is reserved for the data.
const BRAND = 'rgb(var(--c-accent))';
const TABS = [
  { id: 'training', label: 'Training',    accent: BRAND, title: 'Training Session Exertion' },
  { id: 'skill',    label: 'Skill',       accent: BRAND, title: 'Skill Session Exertion' },
  { id: 'total',    label: 'Daily Total', accent: BRAND, title: 'Daily Total Load & Exertion' },
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
export function exertionStatus(v) {
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

const fullDate = d => new Date(d).toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' });

export default function WorkloadMonitor({ athlete, sessions, onSession, initialDay }) {
  const [tab, setTab] = useState('total');
  const [range, setRange] = useState('28d');
  const [picked, setPicked] = useState(initialDay || null); // dayKey of the focused day
  const active = TABS.find(t => t.id === tab);
  const group = `wm-${useId()}`;

  const fullSeries = useMemo(() => buildSeries(athlete, sessions, tab), [athlete, sessions, tab]);
  const series = useMemo(() => applyRange(fullSeries, range), [fullSeries, range]);
  const lastDay = fullSeries.length ? fullSeries[fullSeries.length - 1].date : null;

  // Arriving with a day outside the default window (e.g. from the load board) widens it.
  useEffect(() => { if (initialDay) setPicked(initialDay); }, [initialDay]);
  useEffect(() => {
    if (picked && !series.some(d => dayKey(d.date) === picked) && fullSeries.some(d => dayKey(d.date) === picked)) setRange('all');
  }, [picked, fullSeries]);

  return (
    <Card
      title="Workload Monitor"
      subtitle={lastDay ? `Most recent logged day: ${fmtDate(lastDay)} · click any day on a chart to inspect it` : 'No sessions logged yet'}
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
              style={tab === t.id ? { borderColor: t.accent, color: 'rgb(var(--c-tp))' } : { borderColor: 'transparent', color: 'rgb(var(--c-ts))' }}
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
        ? <SectionView series={series} accent={active.accent} title={active.title} group={group}
                       sessions={sessions} picked={picked} onPick={setPicked} onSession={onSession} />
        : <EmptyState icon="chart" title="No load in this range"
                      hint={fullSeries.length ? 'Pick a wider date range to see earlier sessions.' : 'This athlete has not logged any sessions yet.'} />}
    </Card>
  );
}

function SectionView({ series, accent, title, group, sessions, picked, onPick, onSession }) {
  const [hidden, setHidden] = useState({});
  const [zones, setZones] = useState(true);
  const pickedIdx = picked ? series.findIndex(d => dayKey(d.date) === picked) : -1;
  const focus = pickedIdx >= 0 ? series[pickedIdx] : series[series.length - 1];
  const isLatest = focus === series[series.length - 1];

  const zone = acwrZone(focus.acwr);
  const exertion = exertionOf(focus.load);
  const targetLow = Math.round(focus.chronic * 0.8);
  const targetHigh = Math.round(focus.chronic * 1.3);
  const z = focus.z ?? 0;
  const load = Math.round(focus.load);
  const target = !focus.load ? { color: STATUS.none, label: 'No load logged that day', icon: 'info' }
    : focus.load < targetLow ? { color: STATUS.info, label: `Load ${load} was below this range`, icon: 'arrowDown' }
    : focus.load <= targetHigh ? { color: STATUS.good, label: `Load ${load} was inside this range`, icon: 'check' }
    : { color: STATUS.warning, label: `Load ${load} was above this range`, icon: 'alert' };

  const pick = idx => onPick(idx == null ? null : dayKey(series[idx].date));
  const toggle = k => setHidden(h => ({ ...h, [k]: !h[k] }));
  const daySessions = picked ? (sessions || []).filter(s => dayKey(s.date) === picked) : [];

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 flex-wrap">
        <span className="w-1 h-5 rounded-full" style={{ background: accent }} />
        <h3 className="display text-[17px] text-tp">{title}</h3>
        <span className="text-sm text-ts">· {fullDate(focus.date)}</span>
        {!isLatest && (
          <button onClick={() => onPick(null)} className="ml-1 inline-flex items-center gap-1 text-xs font-semibold text-accent hover:underline min-h-[32px]">
            <Icon name="back" className="w-3.5 h-3.5" /> Back to latest day
          </button>
        )}
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        <Metric label="Session load"   value={fmtNum(focus.load)}       sub="AU"           color={SERIES.load} />
        <Metric label="Exertion"       value={exertion.toFixed(1)}      status={exertionStatus(exertion)} color={STATUS.none} />
        <Metric label="7-day acute"    value={fmtNum(focus.acute, 1)}   sub="AU · rolling" color={SERIES.acute} />
        <Metric label="Chronic (EWMA)" value={fmtNum(focus.chronic, 1)} sub="AU · 28-day"  color={SERIES.chronic} />
        <Metric label="ACWR"           value={focus.acwr > 0 ? focus.acwr.toFixed(2) : '—'} status={zone} color={STATUS.none} />
        <Metric label="Z-score"        value={z.toFixed(2)}             status={zStatus(z)} color={STATUS.none} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-bg border border-bdr rounded-xl px-4 py-4 flex items-center gap-3">
          <span className="w-10 h-10 rounded-full bg-card flex items-center justify-center text-tp shrink-0"><Icon name="target" className="w-5 h-5" /></span>
          <div className="flex-1 min-w-0">
            <div className="text-xs text-ts">{isLatest ? 'Tomorrow’s load target' : 'Next-day target'} · 80–130% of chronic {focus.chronic.toFixed(0)}</div>
            <div className="num text-[28px] leading-tight text-tp">{targetLow} – {targetHigh} <span className="text-sm font-medium text-ts">AU</span></div>
            <div className="flex items-center gap-1 text-xs font-semibold mt-0.5" style={{ color: target.color }}>
              <Icon name={target.icon} className="w-3 h-3" />{target.label}
            </div>
          </div>
        </div>
        <div className="bg-bg border border-bdr rounded-xl px-4 py-3">
          <div className="text-xs text-ts mb-2">ACWR zone</div>
          <AcwrGauge value={focus.acwr} />
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <Panel title="Load history" sub="Daily load, 7-day acute and 28-day chronic (AU)" legend={
          <LegendToggle items={[
            { key: 'load', label: 'Session load', color: SERIES.load, kind: 'box', on: !hidden.load, onToggle: () => toggle('load') },
            { key: 'acute', label: '7-day acute', color: SERIES.acute, on: !hidden.acute, onToggle: () => toggle('acute') },
            { key: 'chronic', label: 'Chronic', color: SERIES.chronic, on: !hidden.chronic, onToggle: () => toggle('chronic') },
          ]} />
        }>
          <LoadHistoryChart series={series} group={group} selected={pickedIdx >= 0 ? pickedIdx : null} onPick={pick} hidden={hidden} />
        </Panel>
        <Panel title="ACWR trend" sub="Acute ÷ chronic against the training zones" legend={
          <LegendToggle items={[
            { key: 'acwr', label: 'ACWR', color: SERIES.load, on: true },
            { key: 'zones', label: 'Zone lines', color: STATUS.good, kind: 'dash', on: zones, onToggle: () => setZones(v => !v) },
          ]} />
        }>
          <AcwrTrendChart series={series} group={group} selected={pickedIdx >= 0 ? pickedIdx : null} onPick={pick} zones={zones} />
        </Panel>
      </div>

      {picked && (
        <DayDetail dateKey={picked} point={pickedIdx >= 0 ? series[pickedIdx] : null} sessions={daySessions}
                   onSession={onSession} onClose={() => onPick(null)} />
      )}

      <Panel title={`Daily log (latest ${Math.min(10, series.length)})`} sub="Table view of the charts · select a day to inspect it">
        <div className="overflow-x-auto -mx-4">
          <table>
            <thead><tr>{['Date', 'Load', 'Exertion', 'Acute', 'Chronic', 'ACWR', 'Z-score'].map(h => <th key={h}>{h}</th>)}</tr></thead>
            <tbody>
              {[...series].slice(-10).reverse().map(d => {
                const zz = d.z ?? 0, zn = acwrZone(d.acwr), ex = exertionOf(d.load), zs = zStatus(zz);
                const key = dayKey(d.date);
                const on = key === picked;
                return (
                  <tr key={key} onClick={() => onPick(on ? null : key)} tabIndex={0} aria-selected={on}
                      onKeyDown={e => e.key === 'Enter' && onPick(on ? null : key)}
                      className={on ? '!bg-accent/10' : ''}>
                    <td className="whitespace-nowrap text-tp">{on && <span className="inline-block w-1.5 h-1.5 rounded-full bg-accent mr-2 align-middle" />}{d.label || fmtDate(d.date)}</td>
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

// What happened on one day: the computed numbers plus every session logged.
function DayDetail({ dateKey, point, sessions, onSession, onClose }) {
  const [y, m, d] = dateKey.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  const ref = React.useRef(null);
  useEffect(() => { ref.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' }); }, [dateKey]);
  return (
    <section ref={ref} className="rounded-xl border border-accent/40 bg-accent/[0.04] p-4 scroll-mt-6" aria-label={`Details for ${fullDate(date)}`}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="label-caps text-accent">Selected day</div>
          <div className="display text-[20px] text-tp mt-0.5">{fullDate(date)}</div>
          {point && (
            <div className="text-sm text-ts mt-1">
              Load <span className="text-tp font-semibold">{fmtNum(point.load)} AU</span> · ACWR <span className="text-tp font-semibold">{point.acwr > 0 ? point.acwr.toFixed(2) : '—'}</span>
              {' '}· {acwrZone(point.acwr).label}
            </div>
          )}
        </div>
        <button onClick={onClose} aria-label="Close day details" className="w-11 h-11 -mr-2 -mt-2 rounded-md flex items-center justify-center text-ts hover:text-tp hover:bg-card">
          <Icon name="x" className="w-4 h-4" />
        </button>
      </div>
      {sessions.length === 0 ? (
        <p className="text-sm text-ts mt-3">{point ? 'Session details aren’t available for this day.' : 'Rest day — no sessions logged.'}</p>
      ) : (
        <ul className="mt-3 divide-y divide-bdr border border-bdr rounded-lg bg-bg">
          {sessions.map(s => {
            const types = [...(s.primaryTypes || []), ...(s.skillTypes || [])].join(', ') || 'Session';
            return (
              <li key={s._id}>
                <button onClick={() => onSession?.(s)} disabled={!onSession}
                        className="w-full flex items-center gap-4 px-4 py-3 text-left hover:bg-card/60 transition-colors disabled:cursor-default">
                  <div className="min-w-0 flex-1">
                    <div className="text-sm font-semibold text-tp truncate">{types}</div>
                    <div className="text-xs text-ts mt-0.5">
                      {[s.primaryDuration && `${s.primaryDuration} min`, s.primaryRpe != null && `RPE ${s.primaryRpe}`,
                        s.readinessPercent != null && `Readiness ${Math.round(s.readinessPercent)}%`].filter(Boolean).join(' · ')}
                    </div>
                  </div>
                  <div className="text-right shrink-0">
                    <div className="num text-[20px] text-tp leading-none">{fmtNum(s.totalLoad)}</div>
                    <div className="text-xs text-ts">AU</div>
                  </div>
                  {onSession && <Icon name="chevron" className="w-4 h-4 text-ts" />}
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}

function Panel({ title, sub, legend, children }) {
  return (
    <div className="panel rounded-xl p-4">
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

export function AcwrGauge({ value }) {
  const zone = acwrZone(value);
  const pct = (Math.max(0, Math.min(2, value || 0)) / 2) * 100;
  const zonesInfo = [
    { flex: 40, color: STATUS.info, name: 'Undertraining · below 0.8' },
    { flex: 25, color: STATUS.good, name: 'Sweet spot · 0.8–1.3' },
    { flex: 10, color: STATUS.warning, name: 'Caution · 1.3–1.5' },
    { flex: 25, color: STATUS.critical, name: 'Danger · above 1.5' },
  ];
  return (
    <div>
      <div className="relative">
        <div className="h-3 rounded-full overflow-hidden flex gap-[2px]">
          {zonesInfo.map(zi => <div key={zi.name} title={zi.name} style={{ flex: zi.flex, background: zi.color }} />)}
        </div>
        {value > 0 && (
          <span className="absolute -top-1 w-1.5 h-5 rounded-full bg-tp shadow ring-2 ring-surface -translate-x-1/2 transition-[left] duration-300"
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

function LoadHistoryChart({ series, group, selected, onPick, hidden }) {
  const dim = c => ctx => (selected == null || ctx.dataIndex === selected ? c : `${c}55`);
  const data = {
    labels: series.map(d => d.label || shortDate(d.date)),
    datasets: [
      { ...lineDataset('7-day acute', series.map(d => Math.round(d.acute * 10) / 10), SERIES.acute), order: 1, unit: 'AU', hidden: !!hidden.acute, tipOrder: 1 },
      { ...lineDataset('Chronic', series.map(d => Math.round(d.chronic * 10) / 10), SERIES.chronic), order: 2, unit: 'AU', hidden: !!hidden.chronic, tipOrder: 2 },
      { ...barDataset('Session load', series.map(d => Math.round(d.load)), SERIES.load), order: 3, unit: 'AU', hidden: !!hidden.load,
        backgroundColor: dim(SERIES.load), tipColor: SERIES.load, tipOrder: 0 },
    ],
  };
  return (
    <InteractiveChart type="bar" data={data} options={chartOptions()} group={group} titles={series.map(d => fullDate(d.date))}
                      onPick={onPick} selected={selected} title="Load history" subtitle="Daily load with 7-day acute and 28-day chronic, in AU"
                      pickLabel="Show this day’s sessions" />
  );
}

function AcwrTrendChart({ series, group, selected, onPick, zones }) {
  const n = series.length;
  const data = {
    labels: series.map(d => d.label || shortDate(d.date)),
    datasets: [
      lineDataset('ACWR', series.map(d => Math.min(Number(d.acwr.toFixed(2)), 2.5)), SERIES.load, { fill: true }),
      ...(zones ? [
        thresholdDataset('Danger above 1.5', 1.5, n, STATUS.critical),
        thresholdDataset('Sweet spot to 1.3', 1.3, n, STATUS.good),
        thresholdDataset('Under below 0.8', 0.8, n, STATUS.info),
      ] : []),
    ],
  };
  return (
    <InteractiveChart type="line" data={data} options={chartOptions({ yMin: 0, yMax: 2.5 })} group={group}
                      titles={series.map(d => fullDate(d.date))} onPick={onPick} selected={selected}
                      title="ACWR trend" subtitle="Acute ÷ chronic workload ratio · sweet spot 0.8–1.3, danger above 1.5"
                      pickLabel="Show this day’s sessions" />
  );
}
