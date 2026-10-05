// Roster condition — a quick triage of each athlete from the same numbers the
// Workload Monitor shows (latest ACWR, Z-score, readiness, days since a
// session). It's a prompt to look closer, not a medical judgement, so every
// level carries the reasons that produced it.
import { buildSeries } from '../components/WorkloadMonitor';
import { STATUS } from './adminCharts';

// Colours are getters so they follow the console's light/dark theme.
const level = (key, rank, label, status, icon) => ({ key, rank, label, icon, get color() { return STATUS[status]; } });
export const CONDITION = {
  risk:    level('risk', 0, 'At risk', 'critical', 'alert'),
  monitor: level('monitor', 1, 'Monitor', 'warning', 'info'),
  ready:   level('ready', 2, 'Ready', 'good', 'check'),
  nodata:  level('nodata', 3, 'No data', 'none', 'info'),
};

const DAY = 864e5;
// Copies a level plus extra fields while keeping `color` theme-live.
export const withColor = (lvl, extra = {}) =>
  Object.defineProperties({ ...extra, key: lvl.key, rank: lvl.rank, label: extra.label ?? lvl.label, icon: lvl.icon },
    { color: { get: () => lvl.color, enumerable: true } });

export const daysSince = d => (d ? Math.floor((Date.now() - new Date(d).getTime()) / DAY) : null);

export function relativeDay(d) {
  const n = daysSince(d);
  if (n == null) return 'Never';
  if (n <= 0) return 'Today';
  if (n === 1) return 'Yesterday';
  if (n < 7) return `${n} days ago`;
  if (n < 14) return 'Last week';
  return `${Math.floor(n / 7)} weeks ago`;
}

// athlete: roster row; sessions: that athlete's recent sessions (any order).
export function athleteCondition(athlete, sessions) {
  const series = buildSeries(athlete, sessions, 'total');
  const latest = series[series.length - 1];
  const readiness = athlete.lastReadiness ?? [...sessions].sort((a, b) => new Date(b.date) - new Date(a.date))
    .find(s => s.readinessPercent != null)?.readinessPercent ?? null;
  const idle = daysSince(athlete.lastSession);
  const acwr = latest?.acwr || 0;
  const z = latest?.z ?? 0;

  if (!latest && readiness == null) return withColor(CONDITION.nodata, { reasons: ['No sessions logged yet'], acwr: null, readiness, z: null, idle });

  const risk = [], watch = [];
  if (acwr > 1.5) risk.push(`ACWR ${acwr.toFixed(2)} — load spike`);
  else if (acwr > 1.3) watch.push(`ACWR ${acwr.toFixed(2)} — above sweet spot`);
  else if (acwr > 0 && acwr < 0.8) watch.push(`ACWR ${acwr.toFixed(2)} — undertraining`);
  if (readiness != null && readiness < 40) risk.push(`Readiness ${Math.round(readiness)}%`);
  else if (readiness != null && readiness < 60) watch.push(`Readiness ${Math.round(readiness)}%`);
  if (Math.abs(z) > 2) watch.push(`Z-score ${z.toFixed(1)} — unusual load`);
  if (idle != null && idle >= 7) watch.push(`No session for ${idle} days`);

  const lvl = risk.length ? CONDITION.risk : watch.length ? CONDITION.monitor : CONDITION.ready;
  return withColor(lvl, { reasons: [...risk, ...watch], acwr: acwr || null, readiness, z, idle });
}
