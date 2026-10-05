import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Line, Bar } from 'react-chartjs-2';
import NavBar from '../components/NavBar';
import Badge, { readinessColor } from '../components/Badge';
import SessionModal from '../components/SessionModal';
import WorkloadMonitor from '../components/WorkloadMonitor';
import {
  Icon, Button, PageHeader, Card, FilterBar, Field, AthleteSelect, Avatar,
  EmptyState, ErrorBanner, TableSkeleton, Skeleton, Metric, useSort, SortTh,
  ToastProvider, useToast, downloadCsv,
} from '../components/ui';
import { api } from '../api';
import { downloadAthleteReport } from '../utils/pdfReport';
import { dayKey } from '../utils/acwr';
import { fmtDate, fmtNum } from '../utils/fmt';
import { SINGLE, STATUS, shortDate, chartOptions, lineDataset, barDataset } from '../utils/adminCharts';
import SubscriptionsSection from './SubscriptionsSection';
import {
  computeBCA, interpret,
  gradeBF, gradeFFMI, gradeSMM, gradeSMI, gradeRelASM, gradeMBR, gradeAppendicular, gradeAxial,
} from '../utils/bodyComposition';

const NAV = [
  { id: 'athletes',      label: 'Athletes',       icon: 'users',    subtitle: 'Everyone on your roster. Select an athlete for their full profile.' },
  { id: 'sessions',      label: 'Sessions',       icon: 'list',     subtitle: 'Every training session logged in the app.' },
  { id: 'analytics',     label: 'Analytics',      icon: 'chart',    subtitle: 'Body composition and workload monitoring for any athlete.' },
  { id: 'recovery',      label: 'Recovery',       icon: 'moon',     subtitle: 'Sleep and wellness check-ins submitted by athletes.' },
  { id: 'subscriptions', label: 'Subscriptions',  icon: 'card',     subtitle: 'Plans, billing settings and athlete subscriptions.' },
  { id: 'create',        label: 'Create Athlete', icon: 'userPlus', subtitle: 'Add an athlete account. They can sign in to the app straight away.' },
];

// Enough history for a stable 28-day chronic load.
const HISTORY_LIMIT = 365;

const ATHLETE_SORT = {
  name: a => a.name?.toLowerCase(), sport: a => a.sport?.toLowerCase() || null,
  last: a => (a.lastSession ? +new Date(a.lastSession) : null), load: a => a.lastTotalLoad,
  readiness: a => a.lastReadiness, status: a => (a.active ? 1 : 0),
};
const SESSION_SORT = {
  date: s => +new Date(s.date), athlete: s => s.athlete?.name?.toLowerCase() || null,
  sport: s => s.athlete?.sport?.toLowerCase() || null, load: s => s.totalLoad,
  grade: s => s.scaledGrade, readiness: s => s.readinessPercent,
};

const SESSION_CSV = [
  ['Date', s => dayKey(s.date)], ['Athlete', s => s.athlete?.name], ['Sport', s => s.athlete?.sport],
  ['Types', s => sessionTypes(s)], ['Total load', s => s.totalLoad], ['Grade', s => s.scaledGrade?.toFixed(1)],
  ['Readiness %', s => s.readinessPercent?.toFixed(0)],
];
const RECOVERY_CSV = [
  ['Date', s => dayKey(s.date)], ['Athlete', s => s.athlete?.name], ['Sleep', s => s.sleep], ['Wellness', s => s.wellness],
  ['Soreness', s => s.soreness], ['Fatigue', s => s.fatigue], ['Sleep hours', s => s.sleepDuration?.toFixed(1)],
  ['Sleep efficiency %', s => s.sleepEfficiency?.toFixed(0)], ['Readiness %', s => s.readinessPercent?.toFixed(0)],
];

const errMsg = (e, what) => `Couldn't load ${what}${e?.message ? ` — ${e.message}` : ''}.`;
const gradeBadge = g => (g == null ? null : <Badge color={g >= 7 ? 'red' : g >= 4 ? 'yellow' : 'green'}>{g.toFixed(1)}</Badge>);
const readinessBadge = v => (v == null ? '—' : <Badge color={readinessColor(v)}>{v.toFixed(0)}%</Badge>);
const sessionTypes = s => [...(s.primaryTypes || []), ...(s.skillTypes || [])].join(', ') || '—';
const inRange = (date, from, to) => {
  const k = dayKey(date);
  return (!from || k >= from) && (!to || k <= to);
};

export default function AdminPage() {
  return <ToastProvider><AdminShell /></ToastProvider>;
}

function AdminShell() {
  const [params, setParams] = useSearchParams();
  const section = NAV.some(n => n.id === params.get('section')) ? params.get('section') : 'athletes';
  const athleteParam = params.get('athlete') || '';
  const [sideOpen, setSideOpen] = useState(false);

  // Section + selected athlete live in the URL so refresh / back keep your place.
  const go = (id, athlete) => {
    const next = { section: id };
    if (athlete) next.athlete = athlete;
    setParams(next);
    setSideOpen(false);
    window.scrollTo({ top: 0 });
  };

  const [athletes, setAthletes] = useState([]);
  const [athLoading, setAthLoading] = useState(true);
  const [athError, setAthError] = useState('');
  const [selSession, setSelSession] = useState(null);

  async function loadAthletes() {
    setAthError('');
    try { setAthletes(await api.get('/admin/athletes')); }
    catch (e) { setAthError(errMsg(e, 'athletes')); }
    finally { setAthLoading(false); }
  }
  // Every section uses the athlete list (filters, pickers), so keep it loaded.
  useEffect(() => { loadAthletes(); }, [section]);

  const mainRef = useRef(null);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) { first.current = false; return; }
    mainRef.current?.focus({ preventScroll: true });
  }, [section, athleteParam]);

  const current = NAV.find(n => n.id === section);
  const detailAthlete = section === 'athletes' && athleteParam ? athletes.find(a => a._id === athleteParam) : null;

  return (
    <div className="min-h-dvh bg-bg">
      <a href="#admin-main" className="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-50 bg-accent text-white text-sm font-semibold px-4 py-2 rounded-lg">
        Skip to content
      </a>
      <NavBar />
      <div className="flex relative max-w-[1600px] mx-auto">
        <aside
          className={`fixed inset-y-0 left-0 z-30 w-60 bg-surface border-r border-bdr pt-16 transition-transform
            ${sideOpen ? 'translate-x-0' : '-translate-x-full'} md:translate-x-0 md:sticky md:top-[61px] md:h-[calc(100vh-61px)] md:pt-0`}
          aria-label="Admin sections"
        >
          <nav className="p-3 space-y-0.5">
            {NAV.map(n => {
              const active = section === n.id;
              return (
                <button
                  key={n.id}
                  onClick={() => go(n.id)}
                  aria-current={active ? 'page' : undefined}
                  className={`relative w-full flex items-center gap-3 text-left px-3 min-h-[44px] rounded-lg text-sm font-medium transition-colors
                    ${active ? 'bg-accent/15 text-accent' : 'text-ts hover:text-tp hover:bg-card'}`}
                >
                  {active && <span className="absolute left-0 top-2 bottom-2 w-0.5 rounded-full bg-accent" />}
                  <Icon name={n.icon} className="w-4 h-4 shrink-0" />
                  {n.label}
                </button>
              );
            })}
          </nav>
        </aside>

        {sideOpen && <div className="fixed inset-0 bg-black/60 z-20 md:hidden" onClick={() => setSideOpen(false)} />}

        <main id="admin-main" ref={mainRef} tabIndex={-1} className="flex-1 min-w-0 p-4 sm:p-6 lg:p-8 space-y-6 outline-none">
          <button
            className="md:hidden inline-flex items-center gap-2 border border-bdr text-ts px-4 h-11 rounded-lg text-sm"
            onClick={() => setSideOpen(v => !v)}
            aria-expanded={sideOpen}
          >
            <Icon name="menu" /> Menu
          </button>

          {!detailAthlete && <PageHeader title={current.label} subtitle={current.subtitle} />}
          <ErrorBanner message={athError} onRetry={loadAthletes} />

          {section === 'athletes' && (detailAthlete
            ? <AthleteDetail athlete={detailAthlete} onBack={() => go('athletes')} onSession={setSelSession}
                             onAnalytics={() => go('analytics', detailAthlete._id)} />
            : <AthletesList athletes={athletes} loading={athLoading} onOpen={a => go('athletes', a._id)} onChanged={loadAthletes} />)}
          {section === 'sessions'      && <SessionsSection athletes={athletes} onSession={setSelSession} />}
          {section === 'analytics'     && <AnalyticsSection athletes={athletes} athleteId={athleteParam} onSelect={id => go('analytics', id)} />}
          {section === 'recovery'      && <RecoverySection athletes={athletes} />}
          {section === 'subscriptions' && <SubscriptionsSection athletes={athletes} />}
          {section === 'create'        && <CreateAthlete onCreated={loadAthletes} />}
        </main>
      </div>

      <SessionModal session={selSession} onClose={() => setSelSession(null)} />
    </div>
  );
}

// ── Athletes ────────────────────────────────────────────────────────────────
function AthletesList({ athletes, loading, onOpen, onChanged }) {
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState('all');
  const [busyId, setBusyId] = useState(null);
  const toast = useToast();

  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    return athletes.filter(a =>
      (status === 'all' || (status === 'active' ? a.active : !a.active)) &&
      (!q || [a.name, a.email, a.sport].some(v => v?.toLowerCase().includes(q))));
  }, [athletes, query, status]);
  const activeCount = athletes.filter(a => a.active).length;
  const { sorted, sort, toggle } = useSort(shown, ATHLETE_SORT, 'name', 'asc');

  async function toggleActive(a) {
    if (a.active && !window.confirm(`Deactivate ${a.name}? They will no longer be able to sign in.`)) return;
    setBusyId(a._id);
    try {
      if (a.active) await api.delete(`/admin/athletes/${a._id}`);
      else await api.put(`/admin/athletes/${a._id}`, { active: true });
      await onChanged();
      toast(a.active ? `${a.name} was deactivated.` : `${a.name} is active again.`);
    } catch (e) {
      toast(`Couldn't update ${a.name}: ${e.message || 'please try again.'}`, 'error');
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-3 gap-3 max-w-xl">
        <Metric label="Athletes" value={athletes.length} />
        <Metric label="Active" value={activeCount} color={STATUS.good} />
        <Metric label="Inactive" value={athletes.length - activeCount} color={STATUS.none} />
      </div>

      <Card bodyClassName="p-0">
        <div className="flex flex-col sm:flex-row gap-3 p-4 border-b border-bdr">
          <div className="relative flex-1 max-w-sm">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-ts"><Icon name="search" /></span>
            <input
              type="search" value={query} onChange={e => setQuery(e.target.value)}
              placeholder="Search name, email or sport" aria-label="Search athletes"
              className="!pl-9 h-11 sm:h-9"
            />
          </div>
          <div className="inline-flex bg-bg border border-bdr rounded-lg p-1 self-start" role="group" aria-label="Status">
            {['all', 'active', 'inactive'].map(s => (
              <button key={s} onClick={() => setStatus(s)} aria-pressed={status === s}
                      className={`px-3 h-11 sm:h-7 rounded-md text-xs font-semibold capitalize transition-colors ${status === s ? 'bg-card text-tp' : 'text-ts hover:text-tp'}`}>
                {s}
              </button>
            ))}
          </div>
        </div>

        {loading ? <TableSkeleton /> : shown.length === 0 ? (
          <EmptyState icon="users" title={athletes.length ? 'No athletes match your filters' : 'No athletes yet'}
                      hint={athletes.length ? 'Try a different search or status.' : 'Create an athlete account to get started.'} />
        ) : (
          <div className="overflow-x-auto">
            <table>
              <thead><tr>
                {[['Athlete', 'name'], ['Sport', 'sport'], ['Last session', 'last'], ['Load', 'load'], ['Readiness', 'readiness'], ['Status', 'status'], ['', null]]
                  .map(([h, k]) => <SortTh key={h || 'actions'} label={h} sortKey={k} sort={sort} onSort={toggle} />)}
              </tr></thead>
              <tbody>
                {sorted.map(a => (
                  <tr key={a._id} onClick={() => onOpen(a)} tabIndex={0}
                      onKeyDown={e => e.key === 'Enter' && onOpen(a)} aria-label={`Open ${a.name}`}>
                    <td>
                      <div className="flex items-center gap-3">
                        <Avatar name={a.name} />
                        <div className="min-w-0">
                          <div className="text-tp font-medium truncate">{a.name}</div>
                          <div className="text-xs text-ts truncate">{a.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="text-ts">{a.sport || '—'}</td>
                    <td className="text-ts whitespace-nowrap">{fmtDate(a.lastSession)}</td>
                    <td className="text-tp">{fmtNum(a.lastTotalLoad)}</td>
                    <td>{readinessBadge(a.lastReadiness)}</td>
                    <td><Badge color={a.active ? 'green' : 'gray'}>{a.active ? 'Active' : 'Inactive'}</Badge></td>
                    <td onClick={e => e.stopPropagation()} className="text-right whitespace-nowrap">
                      <Button variant={a.active ? 'ghost' : 'secondary'} disabled={busyId === a._id} onClick={() => toggleActive(a)}>
                        {busyId === a._id ? 'Saving…' : a.active ? 'Deactivate' : 'Activate'}
                      </Button>
                      <span className="inline-block align-middle text-ts ml-1"><Icon name="chevron" /></span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </div>
  );
}

function AthleteDetail({ athlete, onBack, onSession, onAnalytics }) {
  const [sessions, setSessions] = useState(null);
  const [error, setError] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [reportBusy, setReportBusy] = useState(false);

  async function load() {
    setError(''); setSessions(null);
    try { setSessions(await api.get(`/admin/athletes/${athlete._id}/sessions?limit=${HISTORY_LIMIT}`)); }
    catch (e) { setError(errMsg(e, 'sessions')); setSessions([]); }
  }
  useEffect(() => { load(); }, [athlete._id]);

  async function downloadReport() {
    setReportBusy(true);
    try {
      let bodyComposition = null;
      try { bodyComposition = await api.get(`/admin/athletes/${athlete._id}/body-composition`); } catch {}
      downloadAthleteReport(athlete, { sessions, bodyComposition });
    } finally {
      setReportBusy(false);
    }
  }

  const log = useMemo(
    () => (sessions || []).filter(s => inRange(s.date, from, to)).sort((a, b) => new Date(b.date) - new Date(a.date)),
    [sessions, from, to],
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center gap-4">
        <Button variant="ghost" icon="back" onClick={onBack} className="self-start">All athletes</Button>
        <div className="flex items-center gap-3 min-w-0">
          <Avatar name={athlete.name} size="w-11 h-11 text-sm" />
          <div className="min-w-0">
            <h1 className="text-xl font-bold text-tp truncate">{athlete.name}</h1>
            <div className="text-xs text-ts truncate">{athlete.email} · {athlete.sport || 'General'} · {athlete.active ? 'Active' : 'Inactive'}</div>
          </div>
        </div>
        <div className="sm:ml-auto flex gap-2">
          <Button icon="body" onClick={onAnalytics}>Body composition</Button>
          <Button variant="primary" icon="download" onClick={downloadReport} disabled={!sessions || reportBusy}>
            {reportBusy ? 'Preparing PDF…' : 'Download PDF'}
          </Button>
        </div>
      </div>

      <ErrorBanner message={error} onRetry={load} />

      {!sessions ? <Skeleton className="h-96 w-full" /> : (
        <>
          <WorkloadMonitor athlete={athlete} sessions={sessions} />
          <TrendsRow sessions={sessions} />

          <Card title="Session log" subtitle={`${log.length} of ${sessions.length} sessions · select a row for full details`} bodyClassName="p-0"
                actions={
                  <div className="flex items-end gap-2 flex-wrap">
                    <input type="date" value={from} onChange={e => setFrom(e.target.value)} aria-label="From date" className="!w-auto h-11 sm:h-8 text-xs" />
                    <span className="text-ts text-xs pb-2">to</span>
                    <input type="date" value={to} onChange={e => setTo(e.target.value)} aria-label="To date" className="!w-auto h-11 sm:h-8 text-xs" />
                    {(from || to) && <Button variant="ghost" className="sm:!h-8" onClick={() => { setFrom(''); setTo(''); }}>Clear</Button>}
                  </div>
                }>
            {log.length === 0 ? <EmptyState icon="list" title="No sessions in this range" /> : (
              <div className="overflow-x-auto max-h-[480px]">
                <table>
                  <thead><tr>{['Date', 'Types', 'Total load', 'Grade', 'Readiness'].map(h => <th key={h}>{h}</th>)}</tr></thead>
                  <tbody>
                    {log.map(s => (
                      <tr key={s._id} onClick={() => onSession(s)} tabIndex={0} onKeyDown={e => e.key === 'Enter' && onSession(s)}>
                        <td className="whitespace-nowrap text-tp">{fmtDate(s.date)}</td>
                        <td className="text-ts">{sessionTypes(s)}</td>
                        <td className="text-tp">{fmtNum(s.totalLoad)}</td>
                        <td>{gradeBadge(s.scaledGrade) ?? '—'}</td>
                        <td>{readinessBadge(s.readinessPercent)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </>
      )}
    </div>
  );
}

// Readiness over time + the mix of session types, shared by detail & analytics.
function TrendsRow({ sessions }) {
  const sorted = useMemo(() => [...sessions].sort((a, b) => new Date(a.date) - new Date(b.date)), [sessions]);
  const mix = useMemo(() => {
    const c = {};
    sessions.forEach(s => [...(s.primaryTypes || []), ...(s.secondaryTypes || []), ...(s.skillTypes || []), ...(s.skillSubTypes || [])]
      .forEach(t => { c[t] = (c[t] || 0) + 1; }));
    return Object.entries(c).sort((a, b) => b[1] - a[1]);
  }, [sessions]);
  const hasReadiness = sorted.some(s => s.readinessPercent != null);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <Card title="Readiness trend" subtitle="Readiness % from each wellness check-in" className="lg:col-span-2">
        {hasReadiness ? (
          <div className="h-60">
            <Line
              data={{ labels: sorted.map(s => shortDate(s.date)), datasets: [lineDataset('Readiness %', sorted.map(s => (s.readinessPercent == null ? null : Math.round(s.readinessPercent))), SINGLE, { fill: true })] }}
              options={chartOptions({ yMin: 0, yMax: 100 })}
              role="img" aria-label="Readiness trend chart; values are in the session log"
            />
          </div>
        ) : <EmptyState icon="chart" title="No readiness data yet" />}
      </Card>
      <Card title="Training mix" subtitle="Sessions logged per type">
        {mix.length ? (
          <div style={{ height: Math.max(120, mix.length * 34 + 24) }}>
            <Bar
              data={{ labels: mix.map(([t]) => t), datasets: [barDataset('sessions', mix.map(([, n]) => n), SINGLE, { horizontal: true })] }}
              options={chartOptions({ horizontal: true, yMin: 0 })}
              role="img" aria-label={mix.map(([t, n]) => `${t}: ${n}`).join(', ')}
            />
          </div>
        ) : <EmptyState icon="chart" title="No session types logged" />}
      </Card>
    </div>
  );
}

// ── Sessions ────────────────────────────────────────────────────────────────
function SessionsSection({ athletes, onSession }) {
  const [rows, setRows] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [f, setF] = useState({ athlete: '', from: '', to: '' });

  // Refetch keeps the previous rows on screen (dimmed) instead of flashing a skeleton.
  async function load(q = f) {
    setError(''); setBusy(true);
    let url = '/admin/sessions?limit=300';
    if (q.from) url += `&from=${q.from}`;
    if (q.to) url += `&to=${q.to}`;
    if (q.athlete) url += `&athleteId=${q.athlete}`;
    try { setRows(await api.get(url)); }
    catch (e) { setError(errMsg(e, 'sessions')); setRows(r => r || []); }
    finally { setBusy(false); }
  }
  const { sorted, sort, toggle } = useSort(rows || [], SESSION_SORT, 'date', 'desc');
  useEffect(() => { load(); }, []);

  const clear = () => { const empty = { athlete: '', from: '', to: '' }; setF(empty); load(empty); };
  const filtered = f.athlete || f.from || f.to;

  return (
    <div className="space-y-4">
      <FilterBar>
        <Field label="Athlete" htmlFor="sess-ath">
          <AthleteSelect id="sess-ath" athletes={athletes} value={f.athlete} onChange={v => setF({ ...f, athlete: v })} allLabel="All athletes" />
        </Field>
        <Field label="From" htmlFor="sess-from"><input id="sess-from" type="date" value={f.from} onChange={e => setF({ ...f, from: e.target.value })} className="!w-auto h-11 sm:h-9" /></Field>
        <Field label="To" htmlFor="sess-to"><input id="sess-to" type="date" value={f.to} onChange={e => setF({ ...f, to: e.target.value })} className="!w-auto h-11 sm:h-9" /></Field>
        <Button variant="primary" onClick={() => load()} disabled={busy}>{busy ? 'Loading…' : 'Apply'}</Button>
        {filtered && <Button variant="ghost" onClick={clear} disabled={busy}>Clear</Button>}
      </FilterBar>

      <ErrorBanner message={error} onRetry={() => load()} />

      <Card title="Sessions" subtitle={rows ? `${rows.length} session${rows.length === 1 ? '' : 's'}${rows.length >= 300 ? ' (latest 300)' : ''} · select a row for full details` : 'Loading…'} bodyClassName="p-0"
            actions={rows?.length ? <Button icon="download" onClick={() => downloadCsv('sessions.csv', SESSION_CSV, sorted)}>Export CSV</Button> : null}>
        {!rows ? <TableSkeleton rows={8} /> : rows.length === 0 ? (
          <EmptyState icon="list" title="No sessions found" hint={filtered ? 'Try widening the date range or choosing all athletes.' : 'Sessions appear here once athletes log them in the app.'} />
        ) : (
          <div className={`overflow-x-auto max-h-[640px] transition-opacity ${busy ? 'opacity-50' : ''}`} aria-busy={busy}>
            <table>
              <thead><tr>
                {[['Date', 'date'], ['Athlete', 'athlete'], ['Sport', 'sport'], ['Types', null], ['Load', 'load'], ['Grade', 'grade'], ['Readiness', 'readiness']]
                  .map(([h, k]) => <SortTh key={h} label={h} sortKey={k} sort={sort} onSort={toggle} />)}
              </tr></thead>
              <tbody>
                {sorted.map(s => (
                  <tr key={s._id} onClick={() => onSession(s)} tabIndex={0} onKeyDown={e => e.key === 'Enter' && onSession(s)}>
                    <td className="whitespace-nowrap text-tp">{fmtDate(s.date)}</td>
                    <td className="text-tp">{s.athlete?.name || '—'}</td>
                    <td className="text-ts">{s.athlete?.sport || '—'}</td>
                    <td className="text-ts">{sessionTypes(s)}</td>
                    <td className="text-tp">{fmtNum(s.totalLoad)}</td>
                    <td>{gradeBadge(s.scaledGrade) ?? '—'}</td>
                    <td>{readinessBadge(s.readinessPercent)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </div>
  );
}

// ── Analytics — body composition on top, then the Workload Monitor ─────────
function AnalyticsSection({ athletes, athleteId, onSelect }) {
  const athlete = athletes.find(a => a._id === athleteId) || null;
  const [sessions, setSessions] = useState(null);
  const [body, setBody] = useState(undefined);
  const [error, setError] = useState('');

  async function load() {
    if (!athleteId) return;
    setError(''); setSessions(null); setBody(undefined);
    const [s, b] = await Promise.allSettled([
      api.get(`/admin/athletes/${athleteId}/sessions?limit=${HISTORY_LIMIT}`),
      api.get(`/admin/athletes/${athleteId}/body-composition`),
    ]);
    setSessions(s.status === 'fulfilled' ? s.value : []);
    setBody(b.status === 'fulfilled' ? b.value : null);
    if (s.status === 'rejected') setError(errMsg(s.reason, 'sessions'));
  }
  useEffect(() => { load(); }, [athleteId]);

  return (
    <div className="space-y-6">
      <FilterBar>
        <Field label="Athlete" htmlFor="anal-ath">
          <AthleteSelect id="anal-ath" athletes={athletes} value={athleteId} onChange={onSelect} />
        </Field>
        {athlete && (
          <div className="flex items-center gap-3 pb-0.5">
            <Avatar name={athlete.name} />
            <div className="text-xs text-ts">
              <div className="text-sm text-tp font-semibold">{athlete.name}</div>
              {athlete.sport || 'General'} · last session {fmtDate(athlete.lastSession)}
            </div>
          </div>
        )}
      </FilterBar>

      {!athleteId ? (
        athletes.length === 0 ? <Card><EmptyState icon="users" title="No athletes yet" /></Card> : (
          <Card title="Choose an athlete" subtitle="Analytics are available for every athlete on the roster.">
            <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-3">
              {athletes.map(a => (
                <button key={a._id} onClick={() => onSelect(a._id)}
                        className="flex items-center gap-3 text-left bg-bg border border-bdr rounded-xl p-3 hover:border-accent/60 hover:bg-card transition-colors">
                  <Avatar name={a.name} />
                  <div className="min-w-0 flex-1">
                    <div className="text-sm font-semibold text-tp truncate">{a.name}</div>
                    <div className="text-xs text-ts truncate">{a.sport || 'General'} · {a.lastSession ? `last ${fmtDate(a.lastSession)}` : 'no sessions'}</div>
                  </div>
                  {readinessBadge(a.lastReadiness)}
                </button>
              ))}
            </div>
          </Card>
        )
      ) : (
        <>
          <ErrorBanner message={error} onRetry={load} />
          {body === undefined ? <Skeleton className="h-72 w-full" /> : <BodyCompositionCard data={body} />}
          {!sessions ? <Skeleton className="h-96 w-full" /> : (
            <>
              <WorkloadMonitor athlete={athlete} sessions={sessions} />
              {sessions.length > 0 && <TrendsRow sessions={sessions} />}
            </>
          )}
        </>
      )}
    </div>
  );
}

// ── Recovery — wellness/sleep data the athlete fills in-app ────────────────
const REC_FIELDS = [
  { key: 'sleep',            label: 'Sleep',            sub: '1 best – 5 worst', dec: 1, color: '#818CF8' },
  { key: 'wellness',         label: 'Wellness',         sub: '1 best – 5 worst', dec: 1, color: '#34D399' },
  { key: 'soreness',         label: 'Soreness',         sub: '1 best – 5 worst', dec: 1, color: '#FBBF24' },
  { key: 'fatigue',          label: 'Fatigue',          sub: '1 best – 5 worst', dec: 1, color: '#F87171' },
  { key: 'sleepDuration',    label: 'Sleep duration',   sub: 'hours',            dec: 1, color: '#38BDF8' },
  { key: 'sleepEfficiency',  label: 'Sleep efficiency', sub: '%',                dec: 0, color: '#FF6B35' },
  { key: 'readinessPercent', label: 'Readiness',        sub: '%',                dec: 0, color: '#A78BFA' },
];

const mean = (rows, key) => {
  const v = rows.map(r => r[key]).filter(x => x != null);
  return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null;
};
const fmtAvg = (v, dec) => (v == null ? '—' : v.toFixed(dec));

function RecoverySection({ athletes }) {
  const [rows, setRows] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [f, setF] = useState({ athlete: '', from: '', to: '' });
  const [shownFor, setShownFor] = useState('');

  async function load(q = f) {
    setError(''); setBusy(true);
    let url = q.athlete ? `/admin/athletes/${q.athlete}/sessions?limit=300` : '/admin/sessions?limit=300';
    if (q.from) url += `&from=${q.from}`;
    if (q.to) url += `&to=${q.to}`;
    try { setRows(await api.get(url)); setShownFor(q.athlete); }
    catch (e) { setError(errMsg(e, 'recovery data')); setRows(r => r || []); }
    finally { setBusy(false); }
  }
  useEffect(() => { load(); }, []);

  const clear = () => { const empty = { athlete: '', from: '', to: '' }; setF(empty); load(empty); };
  // Team mode follows the data on screen, not the unsaved dropdown.
  const team = !shownFor;
  const data = rows || [];
  const log = useMemo(() => [...data].sort((a, b) => new Date(b.date) - new Date(a.date)), [rows]);

  // Charts plot one point per day; across the whole roster that's the daily average.
  const daily = useMemo(() => {
    const byDay = new Map();
    data.forEach(r => { const k = dayKey(r.date); byDay.set(k, [...(byDay.get(k) || []), r]); });
    return [...byDay.entries()].sort(([a], [b]) => (a < b ? -1 : 1)).map(([k, rs]) => ({
      date: k, ...Object.fromEntries(REC_FIELDS.map(fl => [fl.key, mean(rs, fl.key)])),
    }));
  }, [rows]);

  const perAthlete = useMemo(() => {
    const byAth = new Map();
    data.forEach(r => { const id = r.athlete?._id || r.athlete; byAth.set(id, [...(byAth.get(id) || []), r]); });
    return [...byAth.entries()].map(([id, rs]) => ({
      id, name: rs[0].athlete?.name || athletes.find(a => a._id === id)?.name || '—', count: rs.length,
      ...Object.fromEntries(REC_FIELDS.map(fl => [fl.key, mean(rs, fl.key)])),
    })).sort((a, b) => (a.readinessPercent ?? 101) - (b.readinessPercent ?? 101));
  }, [rows, athletes]);


  return (
    <div className="space-y-6">
      <FilterBar>
        <Field label="Athlete" htmlFor="rec-ath">
          <AthleteSelect id="rec-ath" athletes={athletes} value={f.athlete} onChange={v => setF({ ...f, athlete: v })} allLabel="All athletes (team averages)" />
        </Field>
        <Field label="From" htmlFor="rec-from"><input id="rec-from" type="date" value={f.from} onChange={e => setF({ ...f, from: e.target.value })} className="!w-auto h-11 sm:h-9" /></Field>
        <Field label="To" htmlFor="rec-to"><input id="rec-to" type="date" value={f.to} onChange={e => setF({ ...f, to: e.target.value })} className="!w-auto h-11 sm:h-9" /></Field>
        <Button variant="primary" onClick={() => load()} disabled={busy}>{busy ? 'Loading…' : 'Apply'}</Button>
        {(f.athlete || f.from || f.to) && <Button variant="ghost" onClick={clear} disabled={busy}>Clear</Button>}
      </FilterBar>

      <ErrorBanner message={error} onRetry={() => load()} />

      {!rows ? <Skeleton className="h-96 w-full" /> : data.length === 0 ? (
        <Card><EmptyState icon="moon" title="No recovery data found" hint="Check-ins appear here once athletes submit sleep and wellness data in the app." /></Card>
      ) : (
        <div className={`space-y-6 transition-opacity ${busy ? 'opacity-50' : ''}`} aria-busy={busy}>
          <div>
            <div className="text-xs text-ts mb-2">{team ? 'Team averages' : 'Averages'} · {data.length} check-in{data.length === 1 ? '' : 's'}</div>
            <div className="grid grid-cols-2 sm:grid-cols-4 xl:grid-cols-7 gap-3">
              {REC_FIELDS.map(fl => (
                <Metric key={fl.key} label={fl.label} value={fmtAvg(mean(data, fl.key), fl.dec)} sub={fl.sub} />
              ))}
            </div>
          </div>

          <Card title="Wellness ratings" subtitle={`1 = best, 5 = worst · higher on the chart is better${team ? ' · daily team average' : ''}`}>
            <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-5">
              {REC_FIELDS.slice(0, 4).map(fl => (
                <MiniTrend key={fl.key} title={fl.label} daily={daily} field={fl.key} opts={{ yMin: 1, yMax: 5, yStep: 1, reverse: true }} dec={1} />
              ))}
            </div>
          </Card>

          <Card title="Sleep" subtitle={`From the sleep check-in${team ? ' · daily team average' : ''}`}>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <MiniTrend title="Duration (hours)" daily={daily} field="sleepDuration" opts={{ yMin: 0, yMax: 12, yStep: 2 }} dec={1} tall />
              <MiniTrend title="Efficiency (%)" daily={daily} field="sleepEfficiency" opts={{ yMin: 0, yMax: 100 }} dec={0} tall />
            </div>
          </Card>

          {team && perAthlete.length > 1 && (
            <Card title="Athlete comparison" subtitle="Averages per athlete for the selected period · lowest readiness first" bodyClassName="p-0">
              <div className="overflow-x-auto">
                <table className="static">
                  <thead><tr>{['Athlete', 'Check-ins', ...REC_FIELDS.map(fl => fl.label)].map(h => <th key={h}>{h}</th>)}</tr></thead>
                  <tbody>
                    {perAthlete.map(p => (
                      <tr key={p.id}>
                        <td><div className="flex items-center gap-2"><Avatar name={p.name} size="w-6 h-6 text-[11px]" /><span className="text-tp">{p.name}</span></div></td>
                        <td>{p.count}</td>
                        {REC_FIELDS.map(fl => (
                          <td key={fl.key}>{fl.key === 'readinessPercent' ? readinessBadge(p[fl.key]) : fmtAvg(p[fl.key], fl.dec)}</td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Card>
          )}

          <Card title="Recovery log" subtitle={`${log.length} check-in${log.length === 1 ? '' : 's'} · table view of the charts above`} bodyClassName="p-0"
                actions={<Button icon="download" onClick={() => downloadCsv('recovery-log.csv', RECOVERY_CSV, log)}>Export CSV</Button>}>
            <div className="overflow-x-auto max-h-[560px]">
              <table className="static">
                <thead><tr>{[...(team ? ['Athlete'] : []), 'Date', 'Sleep', 'Wellness', 'Soreness', 'Fatigue', 'Sleep dur.', 'Sleep eff.', 'Readiness'].map(h => <th key={h}>{h}</th>)}</tr></thead>
                <tbody>
                  {log.map(s => (
                    <tr key={s._id}>
                      {team && <td className="text-tp">{s.athlete?.name || '—'}</td>}
                      <td className="whitespace-nowrap text-tp">{fmtDate(s.date)}</td>
                      <td>{s.sleep ?? '—'}</td>
                      <td>{s.wellness ?? '—'}</td>
                      <td>{s.soreness ?? '—'}</td>
                      <td>{s.fatigue ?? '—'}</td>
                      <td>{s.sleepDuration != null ? `${s.sleepDuration.toFixed(1)}h` : '—'}</td>
                      <td>{s.sleepEfficiency != null ? `${Math.round(s.sleepEfficiency)}%` : '—'}</td>
                      <td>{readinessBadge(s.readinessPercent)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}

// One measure over time — a small multiple, so each chart has a single scale.
function MiniTrend({ title, daily, field, opts, dec, tall = false }) {
  const pts = daily.map(d => (d[field] == null ? null : Number(d[field].toFixed(dec))));
  const vals = pts.filter(v => v != null);
  const latest = vals.length ? vals[vals.length - 1] : null;
  return (
    <div>
      <div className="flex items-baseline justify-between gap-2 mb-2">
        <div className="text-xs font-semibold text-tp">{title}</div>
        <div className="text-xs text-ts">latest <span className="text-tp font-semibold">{latest ?? '—'}</span></div>
      </div>
      <div className={tall ? 'h-48' : 'h-36'}>
        {vals.length ? (
          <Line data={{ labels: daily.map(d => shortDate(d.date)), datasets: [lineDataset(title, pts, SINGLE, { fill: !opts.reverse })] }}
                options={chartOptions({ xTicks: tall ? 6 : 3, ...opts })} role="img" aria-label={`${title} trend; values are in the recovery log`} />
        ) : <div className="h-full flex items-center justify-center text-xs text-ts">No data</div>}
      </div>
    </div>
  );
}

// ── Create athlete ──────────────────────────────────────────────────────────
function CreateAthlete({ onCreated }) {
  const empty = { name: '', email: '', password: '', sport: '' };
  const [form, setForm] = useState(empty);
  const [err, setErr] = useState('');
  const [ok, setOk] = useState('');
  const [busy, setBusy] = useState(false);
  const [showPw, setShowPw] = useState(false);
  const [touched, setTouched] = useState({});
  const toast = useToast();

  const problems = {
    name: !form.name.trim() ? 'Enter the athlete\'s full name.' : '',
    email: !form.email.trim() ? 'Enter an email address.' : !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim()) ? 'That email address doesn\'t look right — check for typos.' : '',
    password: form.password.length < 6 ? 'Use at least 6 characters.' : '',
  };
  const fieldError = k => (touched[k] ? problems[k] : '');

  async function submit(e) {
    e.preventDefault();
    setTouched({ name: true, email: true, password: true });
    const firstBad = ['name', 'email', 'password'].find(k => problems[k]);
    if (firstBad) { document.getElementById(`new-${firstBad}`)?.focus(); return; }
    setErr(''); setOk(''); setBusy(true);
    try {
      await api.post('/admin/athletes', form);
      setOk(`${form.name} was created. They can now sign in with ${form.email}.`);
      toast(`${form.name} was created.`);
      setForm(empty);
      setTouched({});
      onCreated();
    } catch (e2) {
      setErr(e2.message || 'Could not create the athlete.');
    } finally {
      setBusy(false);
    }
  }

  const fields = [
    { key: 'name',  label: 'Full name', type: 'text',  placeholder: 'Jane Smith',       auto: 'name' },
    { key: 'email', label: 'Email',     type: 'email', placeholder: 'jane@example.com', auto: 'email' },
  ];

  return (
    <Card className="max-w-lg" bodyClassName="p-6">
      <form onSubmit={submit} className="space-y-4" noValidate>
        {err && <div role="alert" className="bg-red-500/10 border border-red-500/40 rounded-lg px-4 py-3 text-red-300 text-sm">{err}</div>}
        {ok && <div role="status" className="flex items-center gap-2 bg-green-500/10 border border-green-500/40 rounded-lg px-4 py-3 text-green-300 text-sm"><Icon name="check" />{ok}</div>}
        {fields.map(fl => (
          <Field key={fl.key} label={<>{fl.label} <span className="text-accent">*</span></>} htmlFor={`new-${fl.key}`}>
            <input id={`new-${fl.key}`} type={fl.type} placeholder={fl.placeholder} autoComplete={fl.auto} required
                   aria-invalid={!!fieldError(fl.key)} aria-describedby={fieldError(fl.key) ? `new-${fl.key}-err` : undefined}
                   onBlur={() => setTouched(t => ({ ...t, [fl.key]: true }))}
                   value={form[fl.key]} onChange={e => setForm(f => ({ ...f, [fl.key]: e.target.value }))}
                   className={`h-11 ${fieldError(fl.key) ? '!border-red-500/70' : ''}`} />
            {fieldError(fl.key) && <span id={`new-${fl.key}-err`} className="text-xs text-red-300">{fieldError(fl.key)}</span>}
          </Field>
        ))}
        <Field label={<>Temporary password <span className="text-accent">*</span></>} htmlFor="new-password">
          <div className="relative">
            <input id="new-password" type={showPw ? 'text' : 'password'} autoComplete="new-password" required
                   aria-invalid={!!fieldError('password')} aria-describedby="new-password-help"
                   onBlur={() => setTouched(t => ({ ...t, password: true }))}
                   value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))}
                   className={`h-11 !pr-12 ${fieldError('password') ? '!border-red-500/70' : ''}`} />
            <button type="button" onClick={() => setShowPw(v => !v)} aria-label={showPw ? 'Hide password' : 'Show password'}
                    className="absolute right-0.5 top-1/2 -translate-y-1/2 w-11 h-11 flex items-center justify-center text-ts hover:text-tp">
              <Icon name={showPw ? 'eyeOff' : 'eye'} />
            </button>
          </div>
          <span id="new-password-help" className={`text-xs ${fieldError('password') ? 'text-red-300' : 'text-ts'}`}>
            {fieldError('password') || 'At least 6 characters. Share it with the athlete; they can change it from the app.'}
          </span>
        </Field>
        <Field label="Sport (optional)" htmlFor="new-sport">
          <input id="new-sport" type="text" placeholder="Cricket, Running…" value={form.sport}
                 onChange={e => setForm(f => ({ ...f, sport: e.target.value }))} className="h-11" />
        </Field>
        <Button type="submit" variant="primary" disabled={busy} className="w-full !h-11 !text-sm">
          {busy ? 'Creating…' : 'Create athlete'}
        </Button>
      </form>
    </Card>
  );
}

// ── Body composition — mirrors the mobile app's analysis view ──────────────
function GradePill({ grade }) {
  return (
    <span className="text-[11px] font-bold px-2 py-0.5 rounded-full whitespace-nowrap"
          style={{ color: grade.color, backgroundColor: `${grade.color}22` }}>
      {grade.label}
    </span>
  );
}

function BodyCompositionCard({ data }) {
  const latest = data?.latest;
  const fmt = (v, d = 1) => (v == null || Number.isNaN(v) ? '—' : Number(v).toFixed(d));

  // Recompute the full analysis from the stored measurements (same engine as the app).
  const r = latest ? computeBCA(latest) : null;

  if (!latest || !r) {
    return (
      <Card title="Body composition">
        <EmptyState icon="body" title="No body-composition estimate yet"
                    hint="It appears here after the athlete runs a body-composition analysis in the app." />
      </Card>
    );
  }

  const male = r.isMale;
  const ip = interpret(r);
  const lbmPct = 100 - r.bfPercent;
  const pctOf = kg => (kg / r.weightKg) * 100;

  const metrics = [
    { name: 'Fat Percentage',     value: `${fmt(r.bfPercent)}%`,           grade: gradeBF(r.bfPercent, male),                     sub: 'Composition balance' },
    { name: 'FFMI',               value: fmt(r.ffmi),                      grade: gradeFFMI(r.ffmi, male),                        sub: 'Fat-free mass index' },
    { name: 'Skeletal Muscle %',  value: `${fmt(r.smmPercent)}%`,          grade: gradeSMM(r.smmPercent, male),                   sub: 'of total body weight' },
    { name: 'Muscle Mass Index',  value: `${fmt(r.smi, 2)} kg/m²`,         grade: gradeSMI(r.smi, male),                          sub: 'Sarcopenia screening' },
    { name: 'Relative ASM',       value: `${fmt(r.relativeAsm)}%`,         grade: gradeRelASM(r.relativeAsm, male),               sub: 'Functional limb muscle' },
    { name: 'Muscle-Bone Ratio',  value: fmt(r.mbr),                       grade: gradeMBR(r.mbr),                                sub: 'LBM / Bone mass' },
    { name: 'Appendicular Ratio', value: `${fmt(r.appendicularToTotal)}%`, grade: gradeAppendicular(r.appendicularToTotal, male), sub: 'Limb muscle, % of body weight' },
    { name: 'Axial Ratio',        value: `${fmt(r.axialToTotal)}%`,        grade: gradeAxial(r.axialToTotal, male),               sub: 'Core muscle, % of body weight' },
  ];

  // The six tissue layers that add up to 100% of body weight.
  const layers = [
    { label: 'Body fat',          pct: r.bfPercent,                kg: r.bfKg,            color: '#EF4444' },
    { label: 'Skeletal muscle',   pct: r.smmPercent,               kg: r.tsm,             color: '#4AADFF' },
    { label: 'Organs',            pct: pctOf(r.essentialOrgans),   kg: r.essentialOrgans, color: '#A78BFA' },
    { label: 'Lean fluids',       pct: pctOf(r.nonMuscleFluid),    kg: r.nonMuscleFluid,  color: '#38BDF8' },
    { label: 'Skin & connective', pct: pctOf(r.skinConnective),    kg: r.skinConnective,  color: '#FBBF24' },
    { label: 'Bone mineral',      pct: pctOf(r.bmc),               kg: r.bmc,             color: '#E6EDF3' },
  ];

  const tableRows = [
    ['Total Body Weight',      100,                       r.weightKg,          null,      true],
    ['Total Body Fat',         r.bfPercent,               r.bfKg,              '#EF4444'],
    ['Lean Body Mass (LBM)',   lbmPct,                    r.lbm,               '#00CF74'],
    ['Total Skeletal Muscle',  r.smmPercent,              r.tsm,               '#4AADFF'],
    ['  Appendicular (ASM)',   r.appendicularToTotal,     r.asm,               null],
    ['  Axial Muscle Mass',    r.axialToTotal,            r.axial,             null],
    ['Essential Organs',       pctOf(r.essentialOrgans),  r.essentialOrgans,   null],
    ['Bone Mineral Content',   pctOf(r.bmc),              r.bmc,               null],
    ['Skin & Connective',      pctOf(r.skinConnective),   r.skinConnective,    null],
    ['Non-Muscle Lean Fluids', pctOf(r.nonMuscleFluid),   r.nonMuscleFluid,    null],
  ];

  const history = (data?.history || []).map(h => ({ h, c: computeBCA(h) }));

  return (
    <div className="space-y-4">
      <Card title={`Body composition · ${male ? 'Male' : 'Female'}`} subtitle={`Latest estimate ${fmtDate(latest.date)}${history.length ? ` · ${history.length} earlier` : ''}`}
            actions={
              <span className="text-xs font-bold px-3 py-1 rounded-full whitespace-nowrap" style={{ color: ip.overallColor, background: `${ip.overallColor}1A`, border: `1px solid ${ip.overallColor}55` }}>
                {ip.overallLabel}
              </span>
            }>
        <div className="grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-6 gap-3">
          <Metric label="Body fat"        value={`${fmt(r.bfPercent)}%`}  sub={`${fmt(r.bfKg)} kg`}           color="#F87171" />
          <Metric label="Lean mass"       value={`${fmt(r.lbm)} kg`}      sub={`${fmt(lbmPct)}% of BW`}       color="#34D399" />
          <Metric label="Skeletal muscle" value={`${fmt(r.smmPercent)}%`} sub={`${fmt(r.tsm)} kg`}            color="#4AADFF" />
          <Metric label="SMI"             value={fmt(r.smi, 2)}           sub="kg/m²"                         color="#4AADFF" />
          <Metric label="FFMI"            value={fmt(r.ffmi)}             sub="fat-free mass index"           color="#FF6B35" />
          <Metric label="Weight"          value={`${fmt(r.weightKg)} kg`} sub={`${fmt(r.heightCm, 0)} cm`} />
        </div>
      </Card>

      <div className="grid grid-cols-1 xl:grid-cols-5 gap-4">
        <Card title="Structural layer composition" subtitle="Share of total body weight" className="xl:col-span-3">
          <div className="flex gap-[2px] h-7 rounded-lg overflow-hidden mb-3" role="img"
               aria-label={layers.map(l => `${l.label} ${fmt(l.pct)}%`).join(', ')}>
            {layers.map(l => (
              <div key={l.label} style={{ width: `${l.pct}%`, background: l.color }} title={`${l.label}: ${fmt(l.pct)}%`}
                   className="flex items-center justify-center text-[11px] font-bold text-bg overflow-hidden">
                {l.pct >= 8 ? `${fmt(l.pct, 0)}%` : ''}
              </div>
            ))}
          </div>
          <div className="flex flex-wrap gap-x-4 gap-y-1 mb-4">
            {layers.map(l => (
              <span key={l.label} className="inline-flex items-center gap-1.5 text-xs text-ts">
                <span className="w-2.5 h-2.5 rounded-sm" style={{ background: l.color }} />
                {l.label} <span className="text-tp font-semibold tabular-nums">{fmt(l.pct)}%</span>
              </span>
            ))}
          </div>
          <div className="overflow-x-auto">
            <table className="static w-full text-sm">
              <thead><tr><th>Layer</th><th className="!text-right">% of BW</th><th className="!text-right">kg</th><th className="!text-right">lbs</th></tr></thead>
              <tbody>
                {tableRows.map(([label, pct, kg, color, bold]) => (
                  <tr key={label}>
                    <td className={bold ? 'font-bold text-tp' : label.startsWith('  ') ? 'text-ts !pl-8' : 'text-tp'} style={color ? { color } : undefined}>{label.trim()}</td>
                    <td className="text-right font-semibold" style={color ? { color } : undefined}>{fmt(pct, 2)}%</td>
                    <td className="text-right text-tp">{fmt(kg, 2)}</td>
                    <td className="text-right text-ts">{fmt(kg * 2.20462, 2)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>

        <Card title="Interpretation" className="xl:col-span-2">
          <div className="text-xs font-bold uppercase tracking-wider text-ts mb-2">Insights</div>
          <ul className="text-sm text-ts space-y-2 mb-5 list-disc pl-5">
            <li><span className="text-tp font-semibold">Muscle efficiency:</span> FFMI {fmt(r.ffmi)} kg/m² — {gradeFFMI(r.ffmi, male).label}.</li>
            <li><span className="text-tp font-semibold">Skeletal support:</span> muscle-to-bone ratio {fmt(r.mbr)} — {gradeMBR(r.mbr).label}.</li>
            <li><span className="text-tp font-semibold">Weight distribution:</span> {ip.limbDominant ? 'limb-dominant' : 'core-dominant'} ({fmt(r.appendicularToTotal)}% limb / {fmt(r.axialToTotal)}% core muscle of BW).</li>
            <li><span className="text-tp font-semibold">Composition balance:</span> {fmt(r.lbm)} kg lean vs {fmt(r.bfKg)} kg fat.</li>
          </ul>
          <div className="text-xs font-bold uppercase tracking-wider text-ts mb-2">Suggestions</div>
          <ol className="text-sm text-ts space-y-2 list-decimal pl-5">
            {ip.actions.map((a, i) => <li key={i}>{a}</li>)}
          </ol>
        </Card>
      </div>

      <Card title="Key metrics & grades">
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3">
          {metrics.map(m => (
            <div key={m.name} className="border border-bdr rounded-xl p-3.5 bg-bg flex flex-col gap-2">
              <GradePill grade={m.grade} />
              <div>
                <div className="text-xl font-extrabold text-tp tabular-nums">{m.value}</div>
                <div className="text-xs font-semibold text-tp">{m.name}</div>
                <div className="text-xs text-ts">{m.sub}</div>
              </div>
            </div>
          ))}
        </div>
      </Card>

      {history.length > 0 && (
        <Card title="Earlier measurements" subtitle="Newest first · the latest estimate is shown above" bodyClassName="p-0">
          <div className="overflow-x-auto">
            <table className="static">
              <thead><tr>{['Date', 'Body fat', 'Lean mass', 'Skeletal muscle', 'FFMI', 'Weight'].map(h => <th key={h}>{h}</th>)}</tr></thead>
              <tbody>
                {history.map(({ h, c }) => (
                  <tr key={h._id}>
                    <td className="text-tp whitespace-nowrap">{fmtDate(h.date)}</td>
                    <td>{fmt(h.bfPercent ?? c?.bfPercent)}%</td>
                    <td>{fmt(h.lbm ?? c?.lbm)} kg</td>
                    <td>{fmt(h.smmPercent ?? c?.smmPercent)}%</td>
                    <td>{fmt(h.ffmi ?? c?.ffmi)}</td>
                    <td>{fmt(h.weightKg)} kg</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}
