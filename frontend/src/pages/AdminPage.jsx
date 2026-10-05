import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';

import SessionModal from '../components/SessionModal';
import WorkloadMonitor, { exertionStatus } from '../components/WorkloadMonitor';
import InteractiveChart, { LegendToggle } from '../components/InteractiveChart';
import {
  Icon, Button, PageHeader, Card, FilterBar, Field, AthleteSelect, Avatar,
  EmptyState, ErrorBanner, TableSkeleton, Skeleton, Metric, useSort, SortTh,
  ToastProvider, useToast, downloadCsv, ConditionChip, Sparkline, Ring, Segmented,
} from '../components/ui';
import { api, clearSession, getUser } from '../api';
import { athleteCondition, relativeDay, CONDITION } from '../utils/athleteStatus';
import './admin.css';
import { downloadAthleteReport } from '../utils/pdfReport';
import { dayKey } from '../utils/acwr';
import { fmtDate, fmtNum } from '../utils/fmt';
import { SERIES, STATUS, loadRamp, themeName, setChartTheme, shortDate, chartOptions, lineDataset, barDataset } from '../utils/adminCharts';
import SubscriptionsSection from './SubscriptionsSection';
import {
  computeBCA, interpret,
  gradeBF, gradeFFMI, gradeSMM, gradeSMI, gradeRelASM, gradeMBR, gradeAppendicular, gradeAxial,
} from '../utils/bodyComposition';

const NAV = [
  { id: 'athletes',      label: 'Athletes',       icon: 'users',    subtitle: 'Your roster at a glance — who needs attention today, and everyone else.' },
  { id: 'sessions',      label: 'Sessions',       icon: 'list',     subtitle: 'Every training session logged in the app.' },
  { id: 'analytics',     label: 'Analytics',      icon: 'chart',    subtitle: 'Body composition and workload monitoring for any athlete.' },
  { id: 'recovery',      label: 'Recovery',       icon: 'moon',     subtitle: 'Sleep and wellness check-ins submitted by athletes.' },
  { id: 'subscriptions', label: 'Subscriptions',  icon: 'card',     subtitle: 'Plans, billing settings and athlete subscriptions.' },
  { id: 'create',        label: 'Create Athlete', icon: 'userPlus', subtitle: 'Add an athlete account. They can sign in to the app straight away.' },
];

// Enough history for a stable 28-day chronic load.
const HISTORY_LIMIT = 365;

// Roster rows carry their computed condition as `cond`.
const ATHLETE_SORT = {
  name: a => a.name?.toLowerCase(), condition: a => (a.active ? a.cond?.rank ?? 9 : 10),
  acwr: a => a.cond?.acwr ?? null, readiness: a => a.cond?.readiness ?? a.lastReadiness,
  last: a => (a.lastSession ? +new Date(a.lastSession) : null), status: a => (a.active ? 1 : 0),
};
// Body-composition progress lines use the validated series slots 2 and 1.
const SERIES_BC = { get bf() { return SERIES.acute; }, get smm() { return SERIES.load; } };

const THEME_KEY = 'sc_admin_theme';
const THEMES = [
  { value: 'light', label: 'Light', icon: 'sun' },
  { value: 'dark', label: 'Dark', icon: 'moon' },
  { value: 'system', label: 'System', icon: 'monitor' },
];
const ROSTER_WINDOW_DAYS = 42; // 28-day chronic load + two weeks of warm-up

const greeting = () => {
  const h = new Date().getHours();
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
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

const fullDate = d => new Date(d).toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' });
const keyToDate = k => { const [y, m, d] = k.split('-').map(Number); return new Date(y, m - 1, d); };

// Period presets shared by Sessions and Recovery (dates in local YYYY-MM-DD).
const PERIODS = [
  { value: '7', label: '7 days' }, { value: '14', label: '14 days' }, { value: '28', label: '28 days' },
  { value: '90', label: '90 days' }, { value: 'all', label: 'All' }, { value: 'custom', label: 'Custom' },
];
const periodFrom = p => (p === 'all' || p === 'custom' ? '' : dayKey(Date.now() - (Number(p) - 1) * 864e5));

const readinessTone = v => (v == null ? null : v >= 70 ? STATUS.good : v >= 50 ? STATUS.warning : STATUS.critical);

// Number with a small status dot — colour supports, the number carries it.
function ToneNum({ value, color, suffix = '' }) {
  if (value == null) return <span className="text-ts">—</span>;
  return (
    <span className="inline-flex items-center gap-2">
      <span className="w-1.5 h-1.5 rounded-full shrink-0" style={{ background: color || 'transparent' }} aria-hidden="true" />
      <span className="num text-[16px] text-tp">{value}{suffix}</span>
    </span>
  );
}

function PeriodFilter({ f, setF, onLoad, busy, idPrefix }) {
  return (
    <>
      <Field label="Period" htmlFor={`${idPrefix}-period`}>
        <Segmented label="Period" size="md" value={f.period} options={PERIODS}
                   onChange={v => { const q = { ...f, period: v, from: v === 'custom' ? f.from : periodFrom(v), to: v === 'custom' ? f.to : '' }; setF(q); if (v !== 'custom') onLoad(q); }} />
      </Field>
      {f.period === 'custom' && (
        <>
          <Field label="From" htmlFor={`${idPrefix}-from`}><input id={`${idPrefix}-from`} type="date" value={f.from} onChange={e => setF({ ...f, from: e.target.value })} className="!w-auto h-11 sm:h-10" /></Field>
          <Field label="To" htmlFor={`${idPrefix}-to`}><input id={`${idPrefix}-to`} type="date" value={f.to} onChange={e => setF({ ...f, to: e.target.value })} className="!w-auto h-11 sm:h-10" /></Field>
          <Button variant="primary" className="sm:!h-10" onClick={() => onLoad(f)} disabled={busy}>{busy ? 'Loading…' : 'Apply'}</Button>
        </>
      )}
    </>
  );
}

function FilterChip({ label, onClear }) {
  return (
    <span className="inline-flex items-center gap-1 pl-3 pr-1 h-8 rounded-full bg-accent/10 border border-accent/40 text-[13px] text-tp">
      {label}
      <button onClick={onClear} aria-label={`Clear filter: ${label}`} className="w-7 h-7 rounded-full flex items-center justify-center text-ts hover:text-tp">
        <Icon name="x" className="w-3.5 h-3.5" />
      </button>
    </span>
  );
}

const errMsg = (e, what) => `Couldn't load ${what}${e?.message ? ` — ${e.message}` : ''}.`;
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
  const navigate = useNavigate();
  const user = getUser();

  // Theme: Light / Dark / System, remembered per browser (falls back to System).
  const [themePref, setThemePref] = useState(() => { try { return localStorage.getItem(THEME_KEY) || 'system'; } catch { return 'system'; } });
  const [systemDark, setSystemDark] = useState(() => window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? true);
  useEffect(() => {
    const mq = window.matchMedia?.('(prefers-color-scheme: dark)');
    if (!mq) return undefined;
    const h = e => setSystemDark(e.matches);
    mq.addEventListener('change', h);
    return () => mq.removeEventListener('change', h);
  }, []);
  const theme = themePref === 'system' ? (systemDark ? 'dark' : 'light') : themePref;
  setChartTheme(theme); // set before children render so every chart reads the right palette
  useEffect(() => { try { localStorage.setItem(THEME_KEY, themePref); } catch { /* private mode */ } }, [themePref]);
  useEffect(() => {
    document.documentElement.dataset.adminTheme = theme;
    return () => { delete document.documentElement.dataset.adminTheme; };
  }, [theme]);

  const section = NAV.some(n => n.id === params.get('section')) ? params.get('section') : 'athletes';
  const athleteParam = params.get('athlete') || '';
  const filterParam = params.get('filter') || 'all';
  const [sideOpen, setSideOpen] = useState(false);

  // Section, athlete and roster filter live in the URL so refresh / back keep your place.
  const go = (id, athlete, filter, day) => {
    const next = { section: id };
    if (athlete) next.athlete = athlete;
    if (filter && filter !== 'all') next.filter = filter;
    if (day) next.day = day;
    setParams(next);
    setSideOpen(false);
    window.scrollTo({ top: 0 });
  };

  const [athletes, setAthletes] = useState([]);
  const [athLoading, setAthLoading] = useState(true);
  const [athError, setAthError] = useState('');
  const [recent, setRecent] = useState(null); // last ROSTER_WINDOW_DAYS of sessions, all athletes
  const [selSession, setSelSession] = useState(null);

  async function loadAthletes() {
    setAthError('');
    try { setAthletes(await api.get('/admin/athletes')); }
    catch (e) { setAthError(errMsg(e, 'athletes')); }
    finally { setAthLoading(false); }
  }
  async function loadRecent() {
    const from = dayKey(Date.now() - ROSTER_WINDOW_DAYS * 864e5);
    try { setRecent(await api.get(`/admin/sessions?limit=5000&from=${from}`)); }
    catch { setRecent([]); }
  }
  // Every section uses the athlete list (filters, pickers), so keep it loaded.
  useEffect(() => { loadAthletes(); }, [section]);
  useEffect(() => { loadRecent(); }, []);

  // Each athlete's condition, from the same numbers as their Workload Monitor.
  const roster = useMemo(() => {
    const byAth = new Map();
    (recent || []).forEach(r => { const id = r.athlete?._id || r.athlete; byAth.set(id, [...(byAth.get(id) || []), r]); });
    return athletes.map(a => ({ ...a, cond: recent ? athleteCondition(a, byAth.get(a._id) || []) : null }));
  }, [athletes, recent, theme]);
  const atRisk = roster.filter(a => a.active && a.cond?.key === 'risk').length;

  const mainRef = useRef(null);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) { first.current = false; return; }
    mainRef.current?.focus({ preventScroll: true });
  }, [section, athleteParam]);

  const current = NAV.find(n => n.id === section);
  const detailAthlete = section === 'athletes' && athleteParam ? roster.find(a => a._id === athleteParam) : null;
  const signOut = () => { clearSession(); navigate('/'); };
  const [findOpen, setFindOpen] = useState(false);
  useEffect(() => {
    const onKey = e => { if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); setFindOpen(true); } };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const sidebar = (
    <div className="flex flex-col h-full">
      <div className="px-5 h-20 flex items-center gap-3 border-b border-bdr">
        <img src="/logo.png" alt="" className="h-8 w-auto" />
        <div className="leading-none">
          <div className="display text-[20px] text-tp">Solidcore</div>
          <div className="text-[11px] font-semibold tracking-[0.2em] uppercase text-ts mt-1">Coach console</div>
        </div>
      </div>
      <div className="px-3 pt-4">
        <button onClick={() => { setFindOpen(true); setSideOpen(false); }}
                className="w-full flex items-center gap-2.5 px-3 min-h-[40px] rounded-md bg-bg border border-bdr text-sm text-ts hover:text-tp hover:border-[rgb(var(--c-bdr-strong))] transition-colors">
          <Icon name="search" className="w-4 h-4" />
          <span className="flex-1 text-left">Find athlete</span>
          <kbd className="text-[11px] font-semibold border border-bdr rounded px-1.5 py-0.5">Ctrl K</kbd>
        </button>
      </div>
      <nav className="px-3 py-4 space-y-0.5 flex-1" aria-label="Admin sections">
        {NAV.map(n => {
          const active = section === n.id;
          const badge = n.id === 'athletes' && atRisk > 0 ? atRisk : null;
          return (
            <button
              key={n.id}
              onClick={() => go(n.id)}
              aria-current={active ? 'page' : undefined}
              className={`relative w-full flex items-center gap-3 text-left pl-4 pr-3 min-h-[44px] rounded-md text-[15px] transition-colors
                ${active ? 'text-tp font-semibold bg-card' : 'text-ts font-medium hover:text-tp'}`}
            >
              {active && <span className="absolute left-0 top-2.5 bottom-2.5 w-[3px] rounded-full bg-accent" />}
              <Icon name={n.icon} className={`w-[18px] h-[18px] ${active ? 'text-accent' : ''}`} strokeWidth={1.75} />
              <span className="flex-1">{n.label}</span>
              {badge && (
                <span className="num text-[13px] leading-none px-1.5 py-1 rounded text-white" style={{ background: CONDITION.risk.color }}
                      aria-label={`${badge} athletes at risk`}>{badge}</span>
              )}
            </button>
          );
        })}
      </nav>
      <div className="px-4 pt-4 border-t border-bdr">
        <div className="label-caps mb-1.5" id="theme-label">Appearance</div>
        <div role="radiogroup" aria-labelledby="theme-label" className="grid grid-cols-3 gap-1 p-1 rounded-lg bg-bg border border-bdr">
          {THEMES.map(t => {
            const on = themePref === t.value;
            return (
              <button key={t.value} type="button" role="radio" aria-checked={on} onClick={() => setThemePref(t.value)}
                      title={t.value === 'system' ? 'Follow this device’s setting' : `${t.label} theme`}
                      className={`flex items-center justify-center gap-1.5 h-11 sm:h-8 rounded-md text-xs font-semibold transition-colors
                        ${on ? 'bg-surface text-tp ring-1 ring-bdr shadow-sm' : 'text-ts hover:text-tp'}`}>
                <Icon name={t.icon} className="w-3.5 h-3.5" />{t.label}
              </button>
            );
          })}
        </div>
      </div>
      <div className="px-4 py-4 flex items-center gap-3">
        <Avatar name={user?.name || 'Admin'} size="w-9 h-9 text-xs" />
        <div className="min-w-0 flex-1">
          <div className="text-sm font-semibold text-tp truncate">{user?.name || 'Admin'}</div>
          <div className="text-xs text-ts truncate">{user?.email}</div>
        </div>
        <button onClick={signOut} aria-label="Sign out" title="Sign out"
                className="w-11 h-11 -mr-2 rounded-md flex items-center justify-center text-ts hover:text-tp hover:bg-card transition-colors">
          <Icon name="logout" className="w-[18px] h-[18px]" strokeWidth={1.75} />
        </button>
      </div>
    </div>
  );

  const today = new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' });

  return (
    <div className="admin-root min-h-dvh text-tp" data-theme={theme}>
      <a href="#admin-main" className="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-50 bg-accent text-white text-sm font-semibold px-4 py-2 rounded-md">
        Skip to content
      </a>

      <header className="md:hidden sticky top-0 z-30 flex items-center gap-3 px-2 h-14 bg-bg/95 backdrop-blur border-b border-bdr">
        <button onClick={() => setSideOpen(true)} aria-label="Open menu" aria-expanded={sideOpen}
                className="w-11 h-11 rounded-md flex items-center justify-center text-tp">
          <Icon name="menu" className="w-5 h-5" />
        </button>
        <span className="display text-lg">Solidcore</span>
      </header>

      <div className="flex">
        <aside className={`fixed inset-y-0 left-0 z-40 w-64 bg-surface border-r border-bdr transition-transform duration-200
            ${sideOpen ? 'translate-x-0' : '-translate-x-full'} md:translate-x-0 md:sticky md:top-0 md:h-dvh md:shrink-0`}>
          {sidebar}
        </aside>
        {sideOpen && <div className="fixed inset-0 bg-black/60 z-30 md:hidden" onClick={() => setSideOpen(false)} />}

        <main id="admin-main" ref={mainRef} tabIndex={-1}
              className="flex-1 min-w-0 px-4 sm:px-10 py-6 sm:py-9 space-y-8 outline-none max-w-[1480px] mx-auto">
          {!detailAthlete && (
            section === 'athletes'
              ? <PageHeader eyebrow={`${greeting()}, ${(user?.name || 'Coach').split(' ')[0]} · ${today}`} title="Team overview"
                            actions={<Button variant="primary" icon="userPlus" onClick={() => go('create')}>New athlete</Button>} />
              : <PageHeader title={current.label} subtitle={current.subtitle} />
          )}
          <ErrorBanner message={athError} onRetry={loadAthletes} />

          {section === 'athletes' && (detailAthlete
            ? <AthleteDetail athlete={detailAthlete} onBack={() => go('athletes')} onSession={setSelSession}
                             initialDay={params.get('day') || null} onAnalytics={() => go('analytics', detailAthlete._id)} />
            : <AthletesOverview roster={roster} recent={recent} loading={athLoading} filter={filterParam}
                                onFilter={f => go('athletes', null, f)} onOpen={(a, day) => go('athletes', a._id, null, day)}
                                onChanged={loadAthletes} onCreate={() => go('create')} />)}
          {section === 'sessions'      && <SessionsSection athletes={athletes} onSession={setSelSession} />}
          {section === 'analytics'     && <AnalyticsSection athletes={roster} athleteId={athleteParam} onSelect={id => go('analytics', id)} onSession={setSelSession} />}
          {section === 'recovery'      && <RecoverySection athletes={athletes} />}
          {section === 'subscriptions' && <SubscriptionsSection athletes={athletes} />}
          {section === 'create'        && <CreateAthlete onCreated={() => { loadAthletes(); loadRecent(); }} />}
        </main>
      </div>

      <SessionModal session={selSession} onClose={() => setSelSession(null)} />
      {findOpen && <QuickFind roster={roster} onClose={() => setFindOpen(false)}
                              onPick={(a, where) => { setFindOpen(false); go(where, a._id); }} />}
    </div>
  );
}

// Ctrl/Cmd+K: type a name, arrows to move, Enter opens the profile.
function QuickFind({ roster, onClose, onPick }) {
  const [q, setQ] = useState('');
  const [i, setI] = useState(0);
  const inputRef = useRef(null);
  useEffect(() => { inputRef.current?.focus(); }, []);
  const ql = q.trim().toLowerCase();
  // Best match first: name starts with the query, then a word in it does, then anywhere.
  const score = a => {
    const n = (a.name || '').toLowerCase();
    if (!ql) return 0;
    if (n.startsWith(ql)) return 0;
    if (n.split(/\s+/).some(w => w.startsWith(ql))) return 1;
    return 2;
  };
  const hits = roster.filter(a => !ql || [a.name, a.email, a.sport].some(v => v?.toLowerCase().includes(ql)))
    .sort((a, b) => score(a) - score(b) || (a.cond?.rank ?? 9) - (b.cond?.rank ?? 9) || a.name.localeCompare(b.name)).slice(0, 8);
  const onKey = e => {
    if (e.key === 'ArrowDown') { e.preventDefault(); setI(x => Math.min(hits.length - 1, x + 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setI(x => Math.max(0, x - 1)); }
    else if (e.key === 'Enter' && hits[i]) { e.preventDefault(); onPick(hits[i], e.shiftKey ? 'analytics' : 'athletes'); }
    else if (e.key === 'Escape') onClose();
  };
  return (
    <div className="fixed inset-0 z-50 bg-black/60 flex items-start justify-center pt-[12vh] px-4" onClick={onClose}>
      <div role="dialog" aria-modal="true" aria-label="Find athlete" onClick={e => e.stopPropagation()}
           className="w-full max-w-lg rounded-xl border border-bdr bg-surface shadow-2xl overflow-hidden">
        <div className="flex items-center gap-3 px-4 border-b border-bdr">
          <Icon name="search" className="w-4 h-4 text-ts" />
          <input ref={inputRef} value={q} onChange={e => { setQ(e.target.value); setI(0); }} onKeyDown={onKey}
                 placeholder="Find an athlete by name, email or sport" aria-label="Find athlete"
                 className="!border-0 !bg-transparent h-14 !px-0 text-[15px] focus:!border-0" />
          <kbd className="text-[11px] text-ts border border-bdr rounded px-1.5 py-0.5">Esc</kbd>
        </div>
        <ul role="listbox" aria-label="Athletes" className="max-h-[50vh] overflow-y-auto py-1">
          {hits.map((a, idx) => (
            <li key={a._id} role="option" aria-selected={idx === i}>
              <button onMouseEnter={() => setI(idx)} onClick={() => onPick(a, 'athletes')}
                      className={`w-full flex items-center gap-3 px-4 py-2.5 text-left ${idx === i ? 'bg-card' : ''}`}>
                <Avatar name={a.name} size="w-8 h-8 text-[11px]" />
                <span className="min-w-0 flex-1">
                  <span className="block text-sm text-tp font-medium truncate">{a.name}</span>
                  <span className="block text-xs text-ts truncate">{a.sport || 'General'} · {relativeDay(a.lastSession)}</span>
                </span>
                {a.cond && <ConditionChip condition={a.active ? a.cond : { ...CONDITION.nodata, label: 'Inactive' }} />}
              </button>
            </li>
          ))}
          {hits.length === 0 && <li className="px-4 py-6 text-sm text-ts text-center">No athletes match “{q}”.</li>}
        </ul>
        <div className="px-4 py-2.5 border-t border-bdr text-[11px] text-ts flex gap-4">
          <span><kbd className="font-semibold">↑ ↓</kbd> move</span><span><kbd className="font-semibold">Enter</kbd> open profile</span><span><kbd className="font-semibold">Shift+Enter</kbd> analytics</span>
        </div>
      </div>
    </div>
  );
}

// ── Athletes — team overview + roster ──────────────────────────────────────
const ROSTER_FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'risk', label: 'At risk' },
  { key: 'monitor', label: 'Monitor' },
  { key: 'ready', label: 'Ready' },
  { key: 'inactive', label: 'Inactive' },
];
const BOARD_DAYS = 21;
const SPARK_DAYS = 14;

// Daily total load per athlete for the last n days, oldest → newest.
function dailyLoads(sessions, n) {
  const byDay = new Map();
  sessions.forEach(s => { const k = dayKey(s.date); byDay.set(k, (byDay.get(k) || 0) + (s.totalLoad || 0)); });
  return Array.from({ length: n }, (_, i) => {
    const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - (n - 1 - i));
    return { date: d, load: byDay.get(dayKey(d)) || 0 };
  });
}

function SparkFor({ sessions, name, ...rest }) {
  const days = dailyLoads(sessions, SPARK_DAYS);
  return <Sparkline values={days.map(d => d.load)} dates={days.map(d => d.date)} unit="AU" label={`${name}, load over ${SPARK_DAYS} days`} {...rest} />;
}

function HeroStat({ label, value, note, noteColor, onClick }) {
  const Tag = onClick ? 'button' : 'div';
  return (
    <Tag onClick={onClick} className={`flex flex-col justify-start h-full w-full text-left px-6 py-5 min-w-0 ${onClick ? 'hover:bg-card/60 transition-colors' : ''}`}>
      <div className="label-caps">{label}</div>
      <div className="num text-[52px] leading-[0.95] text-tp mt-2">{value}</div>
      {note && <div className="text-[13px] mt-1.5 font-medium" style={{ color: noteColor || 'rgb(var(--c-ts))' }}>{note}</div>}
    </Tag>
  );
}

function AthletesOverview({ roster, recent, loading, filter, onFilter, onOpen, onChanged, onCreate }) {
  const [query, setQuery] = useState('');
  const [hover, setHover] = useState(null); // { row, col, x, y, a, d, n }
  const boardRef = useRef(null);
  const [busyId, setBusyId] = useState(null);
  const toast = useToast();

  const ready = recent != null;
  const byAthlete = useMemo(() => {
    const m = new Map();
    (recent || []).forEach(r => { const id = r.athlete?._id || r.athlete; m.set(id, [...(m.get(id) || []), r]); });
    return m;
  }, [recent]);

  const active = roster.filter(a => a.active);
  const risk = active.filter(a => a.cond?.key === 'risk');
  const attention = active.filter(a => a.cond && (a.cond.key === 'risk' || a.cond.key === 'monitor'))
    .sort((a, b) => a.cond.rank - b.cond.rank || (a.cond.readiness ?? 101) - (b.cond.readiness ?? 101));
  const readinessVals = active.map(a => a.cond?.readiness ?? a.lastReadiness).filter(v => v != null);
  const avgReadiness = readinessVals.length ? readinessVals.reduce((x, y) => x + y, 0) / readinessVals.length : null;
  const acwrVals = active.map(a => a.cond?.acwr).filter(v => v != null);
  const teamAcwr = acwrVals.length ? acwrVals.reduce((x, y) => x + y, 0) / acwrVals.length : null;
  const weekCount = (recent || []).filter(s => Date.now() - new Date(s.date) < 7 * 864e5).length;
  const prevCount = (recent || []).filter(s => { const d = Date.now() - new Date(s.date); return d >= 7 * 864e5 && d < 14 * 864e5; }).length;
  const delta = weekCount - prevCount;
  const readinessTone = avgReadiness == null ? null : avgReadiness >= 70 ? CONDITION.ready : avgReadiness >= 50 ? CONDITION.monitor : CONDITION.risk;

  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    return roster.filter(a =>
      (filter === 'all' ? true : filter === 'inactive' ? !a.active : a.active && a.cond?.key === filter) &&
      (!q || [a.name, a.email, a.sport].some(v => v?.toLowerCase().includes(q))));
  }, [roster, query, filter]);
  const { sorted, sort, toggle } = useSort(shown, ATHLETE_SORT, 'condition', 'asc');

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

  // Load board: one row per active athlete, worst condition first.
  const boardRows = active.slice().sort((a, b) => (a.cond?.rank ?? 9) - (b.cond?.rank ?? 9) || a.name.localeCompare(b.name));
  const boardData = boardRows.map(a => ({ a, days: dailyLoads(byAthlete.get(a._id) || [], BOARD_DAYS) }));
  const nonZero = boardData.flatMap(r => r.days.map(d => d.load)).filter(v => v > 0).sort((x, y) => x - y);
  const q = p => nonZero[Math.min(nonZero.length - 1, Math.floor(p * nonZero.length))] ?? 0;
  const cuts = [q(1 / 6), q(2 / 6), q(3 / 6), q(4 / 6), q(5 / 6)];
  const shade = v => (v <= 0 ? null : loadRamp()[cuts.filter(c => v > c).length]);
  const dayHeads = boardData[0]?.days || dailyLoads([], BOARD_DAYS);

  return (
    <div className="space-y-8">
      {/* Headline strip */}
      <section className="card rounded-xl flex flex-col lg:flex-row lg:items-stretch overflow-hidden">
        <div className="flex items-center gap-6 px-6 py-6 lg:pr-8 border-b lg:border-b-0 lg:border-r border-bdr">
          <Ring value={avgReadiness} caption="Readiness" color={readinessTone?.color || 'rgb(var(--c-ts))'} />
          <div className="max-w-[220px]">
            <div className="display text-xl text-tp leading-tight">
              {avgReadiness == null ? 'No check-ins yet' : avgReadiness >= 70 ? 'Team is fresh' : avgReadiness >= 50 ? 'Team is carrying fatigue' : 'Team is fatigued'}
            </div>
            <p className="text-[13px] text-ts mt-1.5 leading-snug">Average of each active athlete's latest wellness check-in. Aim for 70% or higher.</p>
          </div>
        </div>
        <div className="grid grid-cols-2 xl:grid-cols-4 flex-1 divide-x divide-bdr [&>*:nth-child(3)]:border-l-0 xl:[&>*:nth-child(3)]:border-l [&>*:nth-child(n+3)]:border-t xl:[&>*:nth-child(n+3)]:border-t-0 border-bdr">
          <HeroStat label="Active athletes" value={loading ? '—' : active.length} note={`${roster.length} on the roster`} />
          <HeroStat label="Need attention" value={ready ? attention.length : '—'}
                    note={!ready ? 'Checking…' : attention.length ? `${risk.length} at risk · ${attention.length - risk.length} to monitor` : 'Everyone in range'}
                    noteColor={!ready ? undefined : risk.length ? CONDITION.risk.color : attention.length ? CONDITION.monitor.color : CONDITION.ready.color}
                    onClick={ready && attention.length ? () => onFilter(risk.length ? 'risk' : 'monitor') : undefined} />
          <HeroStat label="Sessions · 7 days" value={ready ? weekCount : '—'}
                    note={ready ? `${delta >= 0 ? '▲' : '▼'} ${Math.abs(delta)} vs previous week` : 'Checking…'} />
          <HeroStat label="Team ACWR" value={teamAcwr != null ? teamAcwr.toFixed(2) : '—'}
                    note={teamAcwr == null ? 'No load yet' : teamAcwr > 1.5 ? 'Above 1.5 — spike' : teamAcwr > 1.3 ? 'Above sweet spot' : teamAcwr < 0.8 ? 'Below 0.8 — light' : 'In the 0.8–1.3 sweet spot'}
                    noteColor={teamAcwr == null ? undefined : teamAcwr > 1.5 ? CONDITION.risk.color : (teamAcwr > 1.3 || teamAcwr < 0.8) ? CONDITION.monitor.color : CONDITION.ready.color} />
        </div>
      </section>

      <div className="grid grid-cols-1 xl:grid-cols-5 gap-8 items-start">
        {/* Team load board */}
        <Card title="Team load board" subtitle={`Daily training load, last ${BOARD_DAYS} days · ${themeName() === 'light' ? 'paler = lighter day, darker = heavier day' : 'dimmer = lighter day, brighter = heavier day'}`}
              className="xl:col-span-3" bodyClassName="p-5"
              actions={
                <div className="hidden sm:flex items-center gap-1.5 text-xs text-ts" aria-hidden="true">
                  Less {loadRamp().map(c => <span key={c} className="w-3 h-3 rounded-[2px]" style={{ background: c }} />)} More
                </div>
              }>
          {!ready ? <Skeleton className="h-56 w-full" /> : boardRows.length === 0 ? (
            <EmptyState icon="activity" title="No active athletes" />
          ) : (
            <div className="overflow-x-auto relative" ref={el => { boardRef.current = el; if (el && !el.dataset.scrolled) { el.scrollLeft = el.scrollWidth; el.dataset.scrolled = '1'; } }}
                 onMouseLeave={() => setHover(null)}>
              {hover && (
                <div className="chart-tip !opacity-100" style={{ left: hover.x, top: hover.y }} aria-hidden="true">
                  <div className="chart-tip-title">{hover.d.date.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' })}</div>
                  <div className="text-[13px] font-semibold text-tp">{hover.a.name}</div>
                  <div className="chart-tip-row">
                    <span className="chart-tip-box" style={{ background: shade(hover.d.load) || 'rgb(var(--c-off))' }} />
                    <span className="chart-tip-val">{hover.d.load ? `${Math.round(hover.d.load)} AU` : 'Rest day'}</span>
                    {hover.n > 0 && <span className="chart-tip-lab">{hover.n} session{hover.n === 1 ? '' : 's'}</span>}
                  </div>
                  {hover.d.load > 0 && <div className="text-[11px] text-ts mt-1">Click to open this day</div>}
                </div>
              )}
              <div className="grid gap-x-[3px] gap-y-[5px] items-center min-w-[520px]"
                   style={{ gridTemplateColumns: `minmax(110px, 150px) repeat(${BOARD_DAYS}, minmax(12px, 1fr)) 52px` }}
                   role="table" aria-label="Daily load per athlete, last 21 days">
                <div className="label-caps" role="columnheader">Athlete</div>
                {dayHeads.map((d, i) => {
                  const isToday = i === BOARD_DAYS - 1;
                  const mark = isToday || i % 7 === 6;
                  return (
                    <div key={i} role="columnheader" className="relative h-4">
                      {(hover ? hover.col === i : mark) && (
                        <span className={`absolute right-0 bottom-0 text-[11px] font-semibold whitespace-nowrap px-0.5 rounded
                          ${hover?.col === i ? 'text-tp bg-card z-10' : isToday ? 'text-accent' : 'text-ts'}`}>
                          {isToday ? 'Today' : d.date.toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}
                        </span>
                      )}
                    </div>
                  );
                })}
                <div className="label-caps text-right" role="columnheader">ACWR</div>

                {boardData.map(({ a, days }, row) => (
                  <React.Fragment key={a._id}>
                    <button onClick={() => onOpen(a)} role="rowheader"
                            className={`flex items-center gap-2 min-w-0 text-left text-[13px] hover:underline h-11 sm:h-7 ${hover?.row === row ? 'text-accent font-semibold' : 'text-tp'}`}>
                      <span className="w-2 h-2 rounded-full shrink-0" style={{ background: a.cond?.color }} />
                      <span className="truncate">{a.name}</span>
                    </button>
                    {days.map((d, i) => {
                      const dim = hover && hover.row !== row && hover.col !== i;
                      return (
                        <div key={i} role="cell"
                             aria-label={`${a.name}, ${d.date.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' })}: ${d.load ? `${Math.round(d.load)} AU` : 'rest day'}`}
                             className={`h-11 sm:h-7 rounded-[3px] transition-opacity duration-100 ${d.load ? 'cursor-pointer' : ''} ${hover?.row === row && hover?.col === i ? 'ring-2 ring-tp ring-offset-1 ring-offset-surface' : ''}`}
                             style={{ background: shade(d.load) || 'rgb(var(--c-card))', opacity: dim ? 0.45 : 1 }}
                             onMouseEnter={e => {
                               const box = boardRef.current.getBoundingClientRect();
                               const c = e.currentTarget.getBoundingClientRect();
                               const n = (byAthlete.get(a._id) || []).filter(s => dayKey(s.date) === dayKey(d.date)).length;
                               const left = c.left - box.left + boardRef.current.scrollLeft;
                               setHover({ row, col: i, a, d, n, x: left > box.width - 200 ? left - 190 : left + c.width + 8, y: c.top - box.top - 4 });
                             }}
                             onClick={() => d.load && onOpen(a, dayKey(d.date))} />
                      );
                    })}
                    <div role="cell" className="num text-[17px] text-tp text-right">{a.cond?.acwr != null ? a.cond.acwr.toFixed(2) : '—'}</div>
                  </React.Fragment>
                ))}
              </div>
            </div>
          )}
        </Card>

        {/* Needs attention */}
        <Card title="Needs attention" subtitle="Latest ACWR, readiness, Z-score and training gaps"
              className="xl:col-span-2" bodyClassName={attention.length ? 'p-0' : 'p-5'}>
          {!ready ? <div className="space-y-2 p-5">{[0, 1, 2].map(i => <Skeleton key={i} className="h-12 w-full" />)}</div>
            : attention.length === 0 ? (
              <p className="text-sm text-ts"><ConditionChip condition={CONDITION.ready} /> &nbsp;No one is flagged. Every active athlete is inside their normal ranges.</p>
            ) : (
              <ul>
                {attention.slice(0, 6).map(a => (
                  <li key={a._id} className="border-b border-bdr last:border-0">
                    <button onClick={() => onOpen(a)} className="w-full flex items-center gap-4 px-5 py-3.5 text-left hover:bg-card/60 transition-colors">
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-3">
                          <span className="text-[15px] font-semibold text-tp truncate">{a.name}</span>
                          <ConditionChip condition={a.cond} />
                        </div>
                        <div className="text-[13px] text-ts mt-0.5 truncate">{a.cond.reasons.join(' · ')}</div>
                      </div>
                      <SparkFor sessions={byAthlete.get(a._id) || []} color={a.cond.color} width={84} name={a.name} />
                    </button>
                  </li>
                ))}
                {attention.length > 6 && (
                  <li className="px-5 py-3">
                    <button onClick={() => onFilter('monitor')} className="min-h-[44px] inline-flex items-center text-[13px] font-semibold text-accent hover:underline">
                      See all {attention.length} flagged athletes
                    </button>
                  </li>
                )}
              </ul>
            )}
        </Card>
      </div>

      {/* Roster */}
      <Card title="Roster" subtitle={`${shown.length} of ${roster.length} athletes`} bodyClassName="p-0"
            actions={
              <div className="relative w-56 hidden sm:block">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-ts"><Icon name="search" /></span>
                <input type="search" value={query} onChange={e => setQuery(e.target.value)}
                       placeholder="Search athletes" aria-label="Search athletes" className="!pl-9 h-9" />
              </div>
            }>
        <div className="flex flex-col sm:flex-row gap-3 px-5 pt-1 border-b border-bdr">
          <input type="search" value={query} onChange={e => setQuery(e.target.value)}
                 placeholder="Search athletes" aria-label="Search athletes" className="sm:!hidden h-11 mt-3" />
          <div className="flex gap-5 overflow-x-auto" role="tablist" aria-label="Filter by condition">
            {ROSTER_FILTERS.map(f => {
              const n = f.key === 'all' ? roster.length : f.key === 'inactive' ? roster.filter(a => !a.active).length
                : roster.filter(a => a.active && a.cond?.key === f.key).length;
              const on = filter === f.key;
              return (
                <button key={f.key} role="tab" aria-selected={on} onClick={() => onFilter(f.key)}
                        className={`relative min-h-[44px] text-[14px] whitespace-nowrap transition-colors ${on ? 'text-tp font-semibold' : 'text-ts hover:text-tp'}`}>
                  {f.label} <span className="num text-[14px] text-ts ml-0.5">{ready || f.key === 'all' || f.key === 'inactive' ? n : ''}</span>
                  {on && <span className="absolute left-0 right-0 -bottom-px h-[2px] bg-accent" />}
                </button>
              );
            })}
          </div>
        </div>

        {loading ? <TableSkeleton /> : shown.length === 0 ? (
          <EmptyState icon="users" title={roster.length ? 'No athletes match' : 'No athletes yet'}
                      hint={roster.length ? 'Try a different search or filter.' : 'Create the first athlete account to get started.'}
                      action={!roster.length && <Button variant="primary" icon="userPlus" onClick={onCreate}>New athlete</Button>} />
        ) : (
          <div className="overflow-x-auto">
            <table>
              <thead><tr>
                {[['Athlete', 'name'], ['Condition', 'condition'], [`Load · ${SPARK_DAYS}d`, null], ['ACWR', 'acwr'], ['Readiness', 'readiness'], ['Last session', 'last'], ['', null]]
                  .map(([h, k]) => <SortTh key={h || 'actions'} label={h} sortKey={k} sort={sort} onSort={toggle} />)}
              </tr></thead>
              <tbody>
                {sorted.map(a => (
                  <tr key={a._id} onClick={() => onOpen(a)} tabIndex={0}
                      onKeyDown={e => e.key === 'Enter' && onOpen(a)} aria-label={`Open ${a.name}`}
                      className={a.active ? '' : 'opacity-50'}>
                    <td>
                      <div className="flex items-center gap-3">
                        <Avatar name={a.name} size="w-9 h-9 text-xs" />
                        <div className="min-w-0">
                          <div className="text-[15px] text-tp font-semibold truncate">{a.name}</div>
                          <div className="text-[13px] text-ts truncate">{a.sport || 'General'}</div>
                        </div>
                      </div>
                    </td>
                    <td>{a.cond ? <ConditionChip condition={a.active ? a.cond : { ...CONDITION.nodata, label: 'Inactive' }} /> : <Skeleton className="h-4 w-16" />}</td>
                    <td onClick={e => e.stopPropagation()}>{ready && <SparkFor sessions={byAthlete.get(a._id) || []} name={a.name} />}</td>
                    <td className="num text-[17px] text-tp">{a.cond?.acwr != null ? a.cond.acwr.toFixed(2) : '—'}</td>
                    <td className="num text-[17px] text-tp">{(a.cond?.readiness ?? a.lastReadiness) != null ? `${Math.round(a.cond?.readiness ?? a.lastReadiness)}%` : '—'}</td>
                    <td className="text-ts whitespace-nowrap" title={fmtDate(a.lastSession)}>{relativeDay(a.lastSession)}</td>
                    <td onClick={e => e.stopPropagation()} className="text-right whitespace-nowrap">
                      <Button variant="ghost" disabled={busyId === a._id} onClick={() => toggleActive(a)}>
                        {busyId === a._id ? 'Saving…' : a.active ? 'Deactivate' : 'Activate'}
                      </Button>
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

function AthleteDetail({ athlete, onBack, onSession, onAnalytics, initialDay }) {
  const [typeFilter, setTypeFilter] = useState('');
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
    () => (sessions || []).filter(s => inRange(s.date, from, to)
      && (!typeFilter || [...(s.primaryTypes || []), ...(s.secondaryTypes || []), ...(s.skillTypes || []), ...(s.skillSubTypes || [])].includes(typeFilter)))
      .sort((a, b) => new Date(b.date) - new Date(a.date)),
    [sessions, from, to, typeFilter],
  );
  const logRef = useRef(null);

  return (
    <div className="space-y-6">
      <nav aria-label="Breadcrumb" className="flex items-center gap-1.5 text-sm">
        <button onClick={onBack} className="text-ts hover:text-tp inline-flex items-center gap-1.5 min-h-[44px] sm:min-h-0">
          <Icon name="back" className="w-4 h-4" /> Team overview
        </button>
        <Icon name="chevron" className="w-3.5 h-3.5 text-ts" />
        <span className="text-tp font-medium truncate">{athlete.name}</span>
      </nav>

      <section className="card rounded-2xl p-5 sm:p-6">
        <div className="flex flex-col lg:flex-row lg:items-center gap-5">
          <div className="flex items-center gap-4 min-w-0 flex-1">
            <Avatar name={athlete.name} size="w-16 h-16 text-xl" />
            <div className="min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <h1 className="text-2xl font-bold text-tp truncate">{athlete.name}</h1>
                {athlete.cond && <ConditionChip condition={athlete.active ? athlete.cond : { ...CONDITION.nodata, label: 'Inactive' }} />}
              </div>
              <div className="text-sm text-ts mt-1 truncate">{athlete.sport || 'General'} · {athlete.email}</div>
              {athlete.cond?.reasons?.length > 0 && athlete.cond.key !== 'ready' && (
                <div className="text-xs mt-1.5" style={{ color: athlete.cond.color }}>{athlete.cond.reasons.join(' · ')}</div>
              )}
            </div>
          </div>
          <div className="grid grid-cols-3 gap-2 sm:gap-3 lg:w-[380px] shrink-0">
            {[
              ['ACWR', athlete.cond?.acwr != null ? athlete.cond.acwr.toFixed(2) : '—'],
              ['Readiness', (athlete.cond?.readiness ?? athlete.lastReadiness) != null ? `${Math.round(athlete.cond?.readiness ?? athlete.lastReadiness)}%` : '—'],
              ['Last session', relativeDay(athlete.lastSession)],
            ].map(([l, v]) => (
              <div key={l} className="card-inset rounded-xl px-3 py-2.5 min-w-0">
                <div className="text-xs text-ts">{l}</div>
                <div className="text-base font-bold text-tp truncate mt-0.5">{v}</div>
              </div>
            ))}
          </div>
        </div>
        <div className="flex gap-2 flex-wrap mt-5 pt-5 border-t border-bdr">
          <Button variant="primary" icon="download" onClick={downloadReport} disabled={!sessions || reportBusy}>
            {reportBusy ? 'Preparing PDF…' : 'Download PDF report'}
          </Button>
          <Button icon="body" onClick={onAnalytics}>Body composition</Button>
        </div>
      </section>

      <ErrorBanner message={error} onRetry={load} />

      {!sessions ? <Skeleton className="h-96 w-full" /> : (
        <>
          <WorkloadMonitor athlete={athlete} sessions={sessions} onSession={onSession} initialDay={initialDay} />
          <TrendsRow sessions={sessions} onSession={onSession} activeType={typeFilter}
                     onType={t => { setTypeFilter(t); setTimeout(() => logRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 50); }} />

          <div ref={logRef} className="scroll-mt-6" />
          <Card title="Session log" subtitle={`${log.length} of ${sessions.length} sessions · select a row for full details`} bodyClassName="p-0"
                actions={
                  <div className="flex items-end gap-2 flex-wrap">
                    <input type="date" value={from} onChange={e => setFrom(e.target.value)} aria-label="From date" className="!w-auto h-11 sm:h-8 text-xs" />
                    <span className="text-ts text-xs pb-2">to</span>
                    <input type="date" value={to} onChange={e => setTo(e.target.value)} aria-label="To date" className="!w-auto h-11 sm:h-8 text-xs" />
                    {(from || to) && <Button variant="ghost" className="sm:!h-8" onClick={() => { setFrom(''); setTo(''); }}>Clear</Button>}
                  </div>
                }>
            {typeFilter && <div className="px-5 pt-4"><FilterChip label={`Type: ${typeFilter}`} onClear={() => setTypeFilter('')} /></div>}
            {log.length === 0 ? <EmptyState icon="list" title="No sessions in this range" /> : (
              <div className="overflow-x-auto max-h-[480px]">
                <table>
                  <thead><tr>{['Date', 'Types', 'Load', 'Exertion', 'Readiness'].map(h => <th key={h}>{h}</th>)}</tr></thead>
                  <tbody>
                    {log.map(s => (
                      <tr key={s._id} onClick={() => onSession(s)} tabIndex={0} onKeyDown={e => e.key === 'Enter' && onSession(s)}>
                        <td className="whitespace-nowrap text-tp">{fmtDate(s.date)}</td>
                        <td><TypeTags s={s} /></td>
                        <td className="num text-[16px] text-tp">{fmtNum(s.totalLoad)}</td>
                        <td><ToneNum value={s.scaledGrade != null ? s.scaledGrade.toFixed(1) : null} color={s.scaledGrade != null ? exertionStatus(s.scaledGrade).color : null} /></td>
                        <td><ToneNum value={s.readinessPercent != null ? Math.round(s.readinessPercent) : null} suffix="%" color={readinessTone(s.readinessPercent)} /></td>
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

function TypeTags({ s }) {
  const t = [...(s.primaryTypes || []), ...(s.skillTypes || [])];
  if (!t.length) return <span className="text-ts">—</span>;
  return (
    <span className="flex flex-wrap gap-1">
      {t.map(x => <span key={x} className="text-xs text-ts border border-bdr rounded px-1.5 py-0.5 whitespace-nowrap">{x}</span>)}
    </span>
  );
}

// Readiness over time + the mix of session types, shared by detail & analytics.
function TrendsRow({ sessions, onSession, onType, activeType }) {
  const sorted = useMemo(() => [...sessions].sort((a, b) => new Date(a.date) - new Date(b.date)), [sessions]);
  const mix = useMemo(() => {
    const c = {};
    sessions.forEach(s => [...(s.primaryTypes || []), ...(s.secondaryTypes || []), ...(s.skillTypes || []), ...(s.skillSubTypes || [])]
      .forEach(t => { c[t] = (c[t] || 0) + 1; }));
    return Object.entries(c).sort((a, b) => b[1] - a[1]);
  }, [sessions]);
  const hasReadiness = sorted.some(s => s.readinessPercent != null);
  const activeIdx = activeType ? mix.findIndex(([t]) => t === activeType) : -1;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <Card title="Readiness trend" subtitle={`Readiness % from each wellness check-in${onSession ? ' · click a point to open that session' : ''}`} className="lg:col-span-2">
        {hasReadiness ? (
          <InteractiveChart type="line" height="h-60" title="Readiness trend" subtitle="Readiness % from each wellness check-in"
            pickLabel="Open this session"
            data={{ labels: sorted.map(s => shortDate(s.date)),
                    datasets: [{ ...lineDataset('Readiness', sorted.map(s => (s.readinessPercent == null ? null : Math.round(s.readinessPercent))), SERIES.load, { fill: true }), unit: '%', pointRadius: 2 }] }}
            titles={sorted.map(s => `${fullDate(s.date)} · ${sessionTypes(s)}`)}
            options={chartOptions({ yMin: 0, yMax: 100 })}
            onPick={onSession ? i => onSession(sorted[i]) : undefined} />
        ) : <EmptyState icon="chart" title="No readiness data yet" />}
      </Card>
      <Card title="Training mix" subtitle={onType ? 'Sessions per type · click a bar to filter the log' : 'Sessions logged per type'}>
        {mix.length ? (
          <div style={{ height: Math.max(140, mix.length * 36 + 30) }}><InteractiveChart type="bar" horizontal height="h-full" title="Training mix" subtitle="Number of sessions logged per training type"
            pickLabel={i => `Filter the session log to ${mix[i][0]}`}
            data={{ labels: mix.map(([t]) => t),
                    datasets: [{ ...barDataset('sessions', mix.map(([, n]) => n), SERIES.load, { horizontal: true }),
                                 backgroundColor: ctx => (activeIdx < 0 || ctx.dataIndex === activeIdx ? SERIES.load : `${SERIES.load}55`), tipColor: SERIES.load }] }}
            titles={mix.map(([t]) => t)}
            options={{ ...chartOptions({ horizontal: true, yMin: 0 }), maintainAspectRatio: false }}
            onPick={onType ? i => onType(mix[i][0]) : undefined}
            selected={activeIdx >= 0 ? activeIdx : null} /></div>
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
  const [f, setF] = useState({ athlete: '', period: '28', from: periodFrom('28'), to: '' });
  const [query, setQuery] = useState('');
  const [day, setDay] = useState(null);

  // Refetch keeps the previous rows on screen (dimmed) instead of flashing a skeleton.
  async function load(q = f) {
    setError(''); setBusy(true); setDay(null);
    let url = '/admin/sessions?limit=2000';
    if (q.from) url += `&from=${q.from}`;
    if (q.to) url += `&to=${q.to}`;
    if (q.athlete) url += `&athleteId=${q.athlete}`;
    try { setRows(await api.get(url)); }
    catch (e) { setError(errMsg(e, 'sessions')); setRows(r => r || []); }
    finally { setBusy(false); }
  }
  useEffect(() => { load(); }, []);

  const all = rows || [];
  const ql = query.trim().toLowerCase();
  const visible = useMemo(() => all.filter(s =>
    (!day || dayKey(s.date) === day) &&
    (!ql || [s.athlete?.name, s.athlete?.sport, sessionTypes(s)].some(v => v?.toLowerCase().includes(ql)))), [rows, day, ql]);
  const { sorted, sort, toggle } = useSort(visible, SESSION_SORT, 'date', 'desc');
  const maxLoad = Math.max(1, ...visible.map(s => s.totalLoad || 0));

  // Daily totals for the chart (search applies, day filter doesn't — the chart is how you pick a day).
  const daily = useMemo(() => {
    const m = new Map();
    all.filter(s => !ql || [s.athlete?.name, s.athlete?.sport, sessionTypes(s)].some(v => v?.toLowerCase().includes(ql)))
      .forEach(s => { const k = dayKey(s.date); const v = m.get(k) || { load: 0, n: 0 }; v.load += s.totalLoad || 0; v.n += 1; m.set(k, v); });
    return [...m.entries()].sort(([a], [b]) => (a < b ? -1 : 1)).map(([k, v]) => ({ key: k, ...v }));
  }, [rows, ql]);
  const dayIdx = day ? daily.findIndex(d => d.key === day) : -1;

  const athletesIn = new Set(visible.map(s => s.athlete?._id)).size;
  const avg = key => { const v = visible.map(s => s[key]).filter(x => x != null); return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null; };
  const avgEx = avg('scaledGrade'), avgReady = avg('readinessPercent');

  return (
    <div className="space-y-6">
      <FilterBar>
        <Field label="Athlete" htmlFor="sess-ath">
          <AthleteSelect id="sess-ath" athletes={athletes} value={f.athlete} allLabel="All athletes"
                         onChange={v => { const q = { ...f, athlete: v }; setF(q); load(q); }} />
        </Field>
        <PeriodFilter f={f} setF={setF} onLoad={load} busy={busy} idPrefix="sess" />
        <div className="relative ml-auto w-full sm:w-64">
          <span className="absolute left-3 top-1/2 -translate-y-1/2 text-ts"><Icon name="search" /></span>
          <input type="search" value={query} onChange={e => setQuery(e.target.value)} placeholder="Search athlete or type"
                 aria-label="Search sessions" className="!pl-9 h-11 sm:h-10" />
        </div>
      </FilterBar>

      <ErrorBanner message={error} onRetry={() => load()} />

      {!rows ? <Skeleton className="h-96 w-full" /> : (
        <div className={`space-y-6 transition-opacity ${busy ? 'opacity-50' : ''}`} aria-busy={busy}>
          <section className="card rounded-xl grid grid-cols-2 lg:grid-cols-5 divide-x divide-bdr [&>*:nth-child(n+3)]:border-t lg:[&>*:nth-child(n+3)]:border-t-0 [&>*:nth-child(3)]:border-l-0 lg:[&>*:nth-child(3)]:border-l border-bdr overflow-hidden">
            <HeroStat label="Sessions" value={visible.length} note={day ? fullDate(keyToDate(day)) : PERIODS.find(p => p.value === f.period)?.label} />
            <HeroStat label="Athletes" value={athletesIn} note="logged in this view" />
            <HeroStat label="Total load" value={Math.round(visible.reduce((a, s) => a + (s.totalLoad || 0), 0)).toLocaleString('en-IN')} note="AU" />
            <HeroStat label="Avg exertion" value={avgEx != null ? avgEx.toFixed(1) : '—'} note={avgEx != null ? exertionStatus(avgEx).label : 'No data'}
                      noteColor={avgEx != null ? exertionStatus(avgEx).color : undefined} />
            <HeroStat label="Avg readiness" value={avgReady != null ? `${Math.round(avgReady)}%` : '—'}
                      note={avgReady == null ? 'No check-ins' : avgReady >= 70 ? 'Fresh' : avgReady >= 50 ? 'Some fatigue' : 'Fatigued'}
                      noteColor={readinessTone(avgReady) || undefined} />
          </section>

          {daily.length > 1 && (
            <Card title="Load per day" subtitle="Total load logged each day across the athletes in view · click a day to list its sessions">
              <InteractiveChart type="bar" height="h-48" title="Load per day" subtitle="Total load logged each day across the athletes in view, in AU"
                pickLabel="List this day’s sessions"
                data={{ labels: daily.map(d => shortDate(keyToDate(d.key))),
                        datasets: [{ ...barDataset('Total load', daily.map(d => Math.round(d.load)), SERIES.load), unit: 'AU', tipColor: SERIES.load,
                                     backgroundColor: ctx => (dayIdx < 0 || ctx.dataIndex === dayIdx ? SERIES.load : `${SERIES.load}55`) }] }}
                titles={daily.map(d => `${fullDate(keyToDate(d.key))} · ${d.n} session${d.n === 1 ? '' : 's'}`)}
                options={chartOptions({ xTicks: 10 })}
                onPick={i => setDay(daily[i].key)}
                selected={dayIdx >= 0 ? dayIdx : null} />
            </Card>
          )}

          <Card title="Sessions" subtitle={`${visible.length} session${visible.length === 1 ? '' : 's'} · select a row for full details`} bodyClassName="p-0"
                actions={visible.length ? <Button icon="download" onClick={() => downloadCsv('sessions.csv', SESSION_CSV, sorted)}>Export CSV</Button> : null}>
            {(day || ql) && (
              <div className="flex gap-2 flex-wrap px-5 pt-4">
                {day && <FilterChip label={fullDate(keyToDate(day))} onClear={() => setDay(null)} />}
                {ql && <FilterChip label={`“${query}”`} onClear={() => setQuery('')} />}
              </div>
            )}
            {visible.length === 0 ? (
              <EmptyState icon="list" title="No sessions found" hint="Try a longer period, all athletes, or clearing the search." />
            ) : (
              <div className="overflow-x-auto max-h-[640px]">
                <table>
                  <thead><tr>
                    {[['Date', 'date'], ['Athlete', 'athlete'], ['Types', null], ['Load', 'load'], ['Exertion', 'grade'], ['Readiness', 'readiness']]
                      .map(([h, k]) => <SortTh key={h} label={h} sortKey={k} sort={sort} onSort={toggle} />)}
                  </tr></thead>
                  <tbody>
                    {sorted.map(s => (
                      <tr key={s._id} onClick={() => onSession(s)} tabIndex={0} onKeyDown={e => e.key === 'Enter' && onSession(s)}>
                        <td className="whitespace-nowrap">
                          <div className="text-tp">{fmtDate(s.date)}</div>
                          <div className="text-xs text-ts">{relativeDay(s.date)}</div>
                        </td>
                        <td>
                          <div className="flex items-center gap-2.5">
                            <Avatar name={s.athlete?.name} size="w-7 h-7 text-[10px]" />
                            <div className="min-w-0">
                              <div className="text-tp truncate">{s.athlete?.name || '—'}</div>
                              <div className="text-xs text-ts truncate">{s.athlete?.sport || 'General'}</div>
                            </div>
                          </div>
                        </td>
                        <td><TypeTags s={s} /></td>
                        <td className="min-w-[140px]">
                          <div className="flex items-center gap-3">
                            <span className="num text-[16px] text-tp w-10 text-right">{fmtNum(s.totalLoad)}</span>
                            <span className="flex-1 h-1.5 rounded-full bg-card overflow-hidden" aria-hidden="true">
                              <span className="block h-full rounded-full" style={{ width: `${((s.totalLoad || 0) / maxLoad) * 100}%`, background: SERIES.load }} />
                            </span>
                          </div>
                        </td>
                        <td><ToneNum value={s.scaledGrade != null ? s.scaledGrade.toFixed(1) : null} color={s.scaledGrade != null ? exertionStatus(s.scaledGrade).color : null} /></td>
                        <td><ToneNum value={s.readinessPercent != null ? Math.round(s.readinessPercent) : null} suffix="%" color={readinessTone(s.readinessPercent)} /></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </div>
      )}
    </div>
  );
}

// ── Analytics — body composition on top, then the Workload Monitor ─────────
function AnalyticsSection({ athletes, athleteId, onSelect, onSession }) {
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
              {[...athletes].sort((a, b) => (a.cond?.rank ?? 9) - (b.cond?.rank ?? 9)).map(a => (
                <button key={a._id} onClick={() => onSelect(a._id)}
                        className="group flex items-center gap-3 text-left card-inset rounded-xl p-4 hover:border-accent/50 transition-colors">
                  <Avatar name={a.name} size="w-10 h-10 text-sm" />
                  <div className="min-w-0 flex-1">
                    <div className="text-sm font-semibold text-tp truncate">{a.name}</div>
                    <div className="text-xs text-ts truncate mt-0.5">{a.sport || 'General'} · {relativeDay(a.lastSession)}</div>
                  </div>
                  {a.cond ? <ConditionChip condition={a.active ? a.cond : { ...CONDITION.nodata, label: 'Inactive' }} /> : <ToneNum value={a.lastReadiness != null ? Math.round(a.lastReadiness) : null} suffix="%" color={readinessTone(a.lastReadiness)} />}
                  <Icon name="chevron" className="w-4 h-4 text-ts group-hover:text-tp" />
                </button>
              ))}
            </div>
          </Card>
        )
      ) : (
        <>
          <ErrorBanner message={error} onRetry={load} />
          <nav aria-label="On this page" className="sticky top-0 md:top-0 z-20 -mx-4 sm:-mx-10 px-4 sm:px-10 py-2 bg-bg/90 backdrop-blur border-b border-bdr flex gap-1 overflow-x-auto">
            {[['an-body', 'Body composition'], ['an-workload', 'Workload'], ['an-trends', 'Readiness & training mix']].map(([id, l]) => (
              <a key={id} href={`#${id}`} onClick={e => { e.preventDefault(); document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' }); }}
                 className="px-3 min-h-[40px] inline-flex items-center rounded-md text-sm text-ts hover:text-tp hover:bg-card whitespace-nowrap">{l}</a>
            ))}
          </nav>
          <div id="an-body" className="scroll-mt-20">{body === undefined ? <Skeleton className="h-72 w-full" /> : <BodyCompositionCard data={body} />}</div>
          {!sessions ? <Skeleton className="h-96 w-full" /> : (
            <>
              <div id="an-workload" className="scroll-mt-20"><WorkloadMonitor athlete={athlete} sessions={sessions} onSession={onSession} /></div>
              {sessions.length > 0 && <div id="an-trends" className="scroll-mt-20"><TrendsRow sessions={sessions} onSession={onSession} /></div>}
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
  const [f, setF] = useState({ athlete: '', period: '28', from: periodFrom('28'), to: '' });
  const [shownFor, setShownFor] = useState('');
  const [day, setDay] = useState(null);

  async function load(q = f) {
    setError(''); setBusy(true); setDay(null);
    let url = q.athlete ? `/admin/athletes/${q.athlete}/sessions?limit=2000` : '/admin/sessions?limit=2000';
    if (q.from) url += `&from=${q.from}`;
    if (q.to) url += `&to=${q.to}`;
    try { setRows(await api.get(url)); setShownFor(q.athlete); }
    catch (e) { setError(errMsg(e, 'recovery data')); setRows(r => r || []); }
    finally { setBusy(false); }
  }
  useEffect(() => { load(); }, []);

  // Team mode follows the data on screen, not the unsaved dropdown.
  const team = !shownFor;
  const data = rows || [];
  const log = useMemo(() => [...data].filter(r => !day || dayKey(r.date) === day).sort((a, b) => new Date(b.date) - new Date(a.date)), [rows, day]);
  const logRef = useRef(null);

  // Charts plot one point per day; across the whole roster that's the daily average.
  const daily = useMemo(() => {
    const byDay = new Map();
    data.forEach(r => { const k = dayKey(r.date); byDay.set(k, [...(byDay.get(k) || []), r]); });
    return [...byDay.entries()].sort(([a], [b]) => (a < b ? -1 : 1)).map(([k, rs]) => ({
      date: k, ...Object.fromEntries(REC_FIELDS.map(fl => [fl.key, mean(rs, fl.key)])),
    }));
  }, [rows]);

  const dayIdx = day ? daily.findIndex(d => d.date === day) : -1;
  const pickDay = i => {
    setDay(daily[i].date);
    setTimeout(() => logRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 60);
  };

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
          <AthleteSelect id="rec-ath" athletes={athletes} value={f.athlete} allLabel="All athletes (team averages)"
                         onChange={v => { const q = { ...f, athlete: v }; setF(q); load(q); }} />
        </Field>
        <PeriodFilter f={f} setF={setF} onLoad={load} busy={busy} idPrefix="rec" />
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

          <Card title="Wellness ratings" subtitle={`1 = best, 5 = worst · higher on the chart is better${team ? ' · daily team average' : ''} · hover to compare, click a day to see its check-ins`}>
            <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-5">
              {REC_FIELDS.slice(0, 4).map(fl => (
                <MiniTrend key={fl.key} title={fl.label} daily={daily} field={fl.key} opts={{ yMin: 1, yMax: 5, yStep: 1, reverse: true }} dec={1}
                           selected={dayIdx >= 0 ? dayIdx : null} onPick={pickDay} />
              ))}
            </div>
          </Card>

          <Card title="Sleep" subtitle={`From the sleep check-in${team ? ' · daily team average' : ''}`}>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <MiniTrend title="Duration" unit="h" daily={daily} field="sleepDuration" opts={{ yMin: 0, yMax: 12, yStep: 2 }} dec={1} tall selected={dayIdx >= 0 ? dayIdx : null} onPick={pickDay} />
              <MiniTrend title="Efficiency" unit="%" daily={daily} field="sleepEfficiency" opts={{ yMin: 0, yMax: 100 }} dec={0} tall selected={dayIdx >= 0 ? dayIdx : null} onPick={pickDay} />
            </div>
          </Card>

          {team && perAthlete.length > 1 && (
            <Card title="Athlete comparison" subtitle="Averages per athlete for the selected period · lowest readiness first" bodyClassName="p-0">
              <div className="overflow-x-auto">
                <table className="static">
                  <thead><tr>{['Athlete', 'Check-ins', ...REC_FIELDS.map(fl => fl.label)].map(h => <th key={h}>{h}</th>)}</tr></thead>
                  <tbody>
                    {perAthlete.map(p => (
                      <tr key={p.id} className="!cursor-pointer" tabIndex={0} title={`Show only ${p.name}`}
                          onClick={() => { const q = { ...f, athlete: p.id }; setF(q); load(q); }}
                          onKeyDown={e => { if (e.key === 'Enter') { const q = { ...f, athlete: p.id }; setF(q); load(q); } }}>
                        <td><div className="flex items-center gap-2"><Avatar name={p.name} size="w-6 h-6 text-[11px]" /><span className="text-tp">{p.name}</span></div></td>
                        <td>{p.count}</td>
                        {REC_FIELDS.map(fl => (
                          <td key={fl.key}>{fl.key === 'readinessPercent'
                            ? <ToneNum value={p[fl.key] != null ? Math.round(p[fl.key]) : null} suffix="%" color={readinessTone(p[fl.key])} />
                            : fmtAvg(p[fl.key], fl.dec)}</td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Card>
          )}

          <div ref={logRef} />
          <Card title="Recovery log" subtitle={`${log.length} check-in${log.length === 1 ? '' : 's'} · table view of the charts above`} bodyClassName="p-0"
                actions={<Button icon="download" onClick={() => downloadCsv('recovery-log.csv', RECOVERY_CSV, log)}>Export CSV</Button>}>
            {day && <div className="px-5 pt-4"><FilterChip label={fullDate(keyToDate(day))} onClear={() => setDay(null)} /></div>}
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
                      <td><ToneNum value={s.readinessPercent != null ? Math.round(s.readinessPercent) : null} suffix="%" color={readinessTone(s.readinessPercent)} /></td>
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
// All small multiples share a hover group, so the crosshair moves across them together.
// Hover shows the value in the header instead of a floating tooltip, so the
// whole row of small multiples reads out the same day at once.
function MiniTrend({ title, daily, field, opts, dec, tall = false, unit = '', selected, onPick }) {
  const [hi, setHi] = useState(null);
  const pts = daily.map(d => (d[field] == null ? null : Number(d[field].toFixed(dec))));
  const vals = pts.filter(v => v != null);
  const latest = vals.length ? vals[vals.length - 1] : null;
  const showIdx = hi ?? selected;
  const shown = showIdx != null ? pts[showIdx] : latest;
  return (
    <div>
      <div className="flex items-baseline justify-between gap-2 mb-2">
        <div className="text-xs font-semibold text-tp">{title}{unit && <span className="text-ts font-normal"> ({unit})</span>}</div>
        <div className={`text-xs ${showIdx != null ? 'text-accent' : 'text-ts'}`}>
          {showIdx != null ? shortDate(keyToDate(daily[showIdx].date)) : 'latest'}{' '}
          <span className="num text-[16px] text-tp">{shown ?? '—'}{shown != null ? unit : ''}</span>
        </div>
      </div>
      {vals.length ? (
        <InteractiveChart type="line" height={tall ? 'h-48' : 'h-36'} group="recovery" title={`${title} trend`}
          subtitle={unit ? `Daily ${title.toLowerCase()} (${unit})` : `Daily ${title.toLowerCase()} rating · 1 = best, 5 = worst`}
          pickLabel="Show this day’s check-ins"
          data={{ labels: daily.map(d => shortDate(keyToDate(d.date))), datasets: [{ ...lineDataset(title, pts, SERIES.load), unit }] }}
          titles={daily.map(d => fullDate(keyToDate(d.date)))}
          options={chartOptions({ xTicks: tall ? 6 : 3, ...opts })}
          selected={selected} onPick={onPick} tooltip={false} onHover={setHi} />
      ) : <div className={`${tall ? 'h-48' : 'h-36'} flex items-center justify-center text-xs text-ts`}>No data</div>}
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
        {err && <div role="alert" className="bg-red-500/10 border border-red-500/40 rounded-lg px-4 py-3 text-[rgb(var(--c-danger))] text-sm">{err}</div>}
        {ok && <div role="status" className="flex items-center gap-2 bg-green-500/10 border border-green-500/40 rounded-lg px-4 py-3 text-[rgb(var(--c-success))] text-sm"><Icon name="check" />{ok}</div>}
        {fields.map(fl => (
          <Field key={fl.key} label={<>{fl.label} <span className="text-accent">*</span></>} htmlFor={`new-${fl.key}`}>
            <input id={`new-${fl.key}`} type={fl.type} placeholder={fl.placeholder} autoComplete={fl.auto} required
                   aria-invalid={!!fieldError(fl.key)} aria-describedby={fieldError(fl.key) ? `new-${fl.key}-err` : undefined}
                   onBlur={() => setTouched(t => ({ ...t, [fl.key]: true }))}
                   value={form[fl.key]} onChange={e => setForm(f => ({ ...f, [fl.key]: e.target.value }))}
                   className={`h-11 ${fieldError(fl.key) ? '!border-red-500/70' : ''}`} />
            {fieldError(fl.key) && <span id={`new-${fl.key}-err`} className="text-xs text-[rgb(var(--c-danger))]">{fieldError(fl.key)}</span>}
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
          <span id="new-password-help" className={`text-xs ${fieldError('password') ? 'text-[rgb(var(--c-danger))]' : 'text-ts'}`}>
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
    <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-tp whitespace-nowrap">
      <span className="w-2 h-2 rounded-full shrink-0" style={{ background: grade.color }} aria-hidden="true" />
      {grade.label}
    </span>
  );
}


function BodyCompositionCard({ data }) {
  const [hoverLayer, setHoverLayer] = useState(null);
  const [hiddenBc, setHiddenBc] = useState({});
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
    { label: 'Bone mineral',      pct: pctOf(r.bmc),               kg: r.bmc,             color: '#9CA3AF' },
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
              <span className="inline-flex items-center gap-2 text-sm font-semibold text-tp whitespace-nowrap">
                <span className="w-2.5 h-2.5 rounded-full" style={{ background: ip.overallColor }} aria-hidden="true" />
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
              <div key={l.label} style={{ width: `${l.pct}%`, background: l.color, opacity: hoverLayer && hoverLayer !== l.label ? 0.35 : 1 }}
                   title={`${l.label}: ${fmt(l.pct)}% · ${fmt(l.kg)} kg`}
                   onMouseEnter={() => setHoverLayer(l.label)} onMouseLeave={() => setHoverLayer(null)}
                   className="flex items-center justify-center text-[11px] font-bold text-[#16161A] overflow-hidden transition-opacity cursor-default">
                {l.pct >= 8 ? `${fmt(l.pct, 0)}%` : ''}
              </div>
            ))}
          </div>
          <div className="flex flex-wrap gap-x-4 gap-y-1 mb-4">
            {layers.map(l => (
              <span key={l.label} onMouseEnter={() => setHoverLayer(l.label)} onMouseLeave={() => setHoverLayer(null)}
                    className={`inline-flex items-center gap-1.5 text-xs transition-colors ${hoverLayer === l.label ? 'text-tp' : 'text-ts'}`}>
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
                    <td className={bold ? 'font-bold text-tp' : label.startsWith('  ') ? 'text-ts !pl-8' : 'text-tp'}>
                      <span className="inline-flex items-center gap-2">
                        {color && <span className="w-2 h-2 rounded-sm shrink-0" style={{ background: color }} aria-hidden="true" />}
                        {label.trim()}
                      </span>
                    </td>
                    <td className="text-right font-semibold text-tp">{fmt(pct, 2)}%</td>
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

      {history.length > 0 && (() => {
        const pts = [{ h: latest, c: r }, ...history].map(({ h, c }) => ({
          date: h.date, bf: h.bfPercent ?? c?.bfPercent, smm: h.smmPercent ?? c?.smmPercent, lbm: h.lbm ?? c?.lbm, w: h.weightKg,
        })).sort((a, b) => new Date(a.date) - new Date(b.date));
        const first = pts[0], last = pts[pts.length - 1];
        const delta = (a, b, unit, goodDown) => {
          if (a == null || b == null) return null;
          const d = b - a;
          const good = goodDown ? d < 0 : d > 0;
          return <span style={{ color: Math.abs(d) < 0.05 ? 'rgb(var(--c-ts))' : good ? STATUS.good : STATUS.warning }}>{d > 0 ? '▲' : d < 0 ? '▼' : '•'} {Math.abs(d).toFixed(1)}{unit}</span>;
        };
        return (
          <Card title="Progress" subtitle={`${pts.length} measurements · ${fmtDate(first.date)} → ${fmtDate(last.date)}`}>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-5">
              {[['Body fat', first.bf, last.bf, '%', true], ['Skeletal muscle', first.smm, last.smm, '%', false],
                ['Lean mass', first.lbm, last.lbm, ' kg', false], ['Weight', first.w, last.w, ' kg', null]].map(([l, a, b, u, gd]) => (
                <div key={l} className="card-inset rounded-xl px-4 py-3">
                  <div className="label-caps">{l}</div>
                  <div className="num text-[24px] text-tp mt-1">{b != null ? `${Number(b).toFixed(1)}${u}` : '—'}</div>
                  <div className="text-xs font-semibold mt-0.5">{gd === null ? <span className="text-ts">{b != null && a != null ? `${b - a >= 0 ? '+' : ''}${(b - a).toFixed(1)}${u} since first` : ''}</span> : delta(a, b, u, gd)}<span className="text-ts font-normal"> since first</span></div>
                </div>
              ))}
            </div>
            {pts.length >= 2 && (
              <>
                <div className="flex justify-end mb-2">
                  <LegendToggle items={[
                    { key: 'bf', label: 'Body fat %', color: SERIES_BC.bf, on: !hiddenBc.bf, onToggle: () => setHiddenBc(h => ({ ...h, bf: !h.bf })) },
                    { key: 'smm', label: 'Skeletal muscle %', color: SERIES_BC.smm, on: !hiddenBc.smm, onToggle: () => setHiddenBc(h => ({ ...h, smm: !h.smm })) },
                  ]} />
                </div>
                <InteractiveChart type="line" height="h-56" title="Body composition progress" subtitle="Body fat and skeletal muscle as % of body weight"
                  data={{ labels: pts.map(p => shortDate(p.date)), datasets: [
                    { ...lineDataset('Body fat', pts.map(p => (p.bf == null ? null : Number(p.bf.toFixed(1)))), SERIES_BC.bf), unit: '%', pointRadius: 4, hidden: !!hiddenBc.bf },
                    { ...lineDataset('Skeletal muscle', pts.map(p => (p.smm == null ? null : Number(p.smm.toFixed(1)))), SERIES_BC.smm), unit: '%', pointRadius: 4, hidden: !!hiddenBc.smm },
                  ] }}
                  titles={pts.map(p => fullDate(p.date))}
                  options={chartOptions({ yTitle: '% of body weight' })} />
              </>
            )}
            <div className="overflow-x-auto mt-5 -mx-5 border-t border-bdr">
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
        );
      })()}
    </div>
  );
}
