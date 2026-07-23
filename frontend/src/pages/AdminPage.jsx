import React, { useEffect, useState, useMemo } from 'react';
import { Bar, Line, Doughnut } from 'react-chartjs-2';
import NavBar from '../components/NavBar';
import StatCard from '../components/StatCard';
import Badge from '../components/Badge';
import SessionModal from '../components/SessionModal';
import WorkloadMonitorPage from './WorkloadMonitorPage';
import { api } from '../api';
import { buildDailyRecords, buildFlutterSeries, computeRollingACWR, computeStats, dayKey } from '../utils/acwr';
import { monitorSeriesForAthlete } from '../utils/flutterWorkloadMonitorData';
import { fmtDate, fmtNum } from '../utils/fmt';
import { CHART_OPTS, ACWR_OPTS, DONUT_OPTS, COLORS } from '../utils/chartDefaults';
import { acwrColor, acwrLabel, readinessColor } from '../components/Badge';
import SubscriptionsSection from './SubscriptionsSection';
import {
  computeBCA, interpret,
  gradeBF, gradeFFMI, gradeSMM, gradeSMI, gradeRelASM, gradeMBR, gradeAppendicular, gradeAxial,
} from '../utils/bodyComposition';

const SECTIONS = ['Overview', 'Athletes', 'Sessions', 'Analytics', 'Workload Monitor', 'Subscriptions', 'Create Athlete'];

export default function AdminPage() {
  const [section, setSection]         = useState('Overview');
  const [sideOpen, setSideOpen]       = useState(false);

  // Overview
  const [dash, setDash]               = useState(null);

  // Athletes
  const [athletes, setAthletes]       = useState([]);
  const [selectedAthlete, setSelAth]  = useState(null);
  const [athDetail, setAthDetail]     = useState(null); // { sessions, summary }
  const [athFrom, setAthFrom]         = useState('');
  const [athTo, setAthTo]             = useState('');

  // Sessions
  const [sessions, setSessions]       = useState([]);
  const [sessFrom, setSessFrom]       = useState('');
  const [sessTo, setSessTo]           = useState('');
  const [sessAthId, setSessAthId]     = useState('');
  const [selSession, setSelSession]   = useState(null);

  // Analytics
  const [analAthId, setAnalAthId]     = useState('');
  const [analSessions, setAnalSess]   = useState([]);
  const [analBody, setAnalBody]       = useState(null); // body-composition { latest, history, synced }

  // Create athlete form
  const [form, setForm]               = useState({ name: '', email: '', password: '', sport: '' });
  const [formErr, setFormErr]         = useState('');
  const [formOk, setFormOk]           = useState('');
  const [creating, setCreating]       = useState(false);

  // ── Load data per section ──────────────────────────────────────────────
  useEffect(() => {
    // Several sections (Athletes, Sessions, Analytics, Workload Monitor, Create
    // Athlete) render an athlete dropdown, so always keep the list loaded —
    // otherwise navigating straight to Analytics shows an empty "Select athlete".
    loadAthletes();
    if (section === 'Overview') loadDash();
    if (section === 'Sessions') loadSessions();
  }, [section]);

  async function loadDash() {
    try { setDash(await api.get('/admin/dashboard')); } catch {}
  }
  async function loadAthletes() {
    try { setAthletes(await api.get('/admin/athletes')); } catch {}
  }
  async function loadSessions(f, t, aid) {
    try {
      let url = '/admin/sessions?limit=300';
      if (f)   url += `&from=${f}`;
      if (t)   url += `&to=${t}`;
      if (aid) url += `&athleteId=${aid}`;
      setSessions(await api.get(url));
    } catch {}
  }
  async function loadAthDetail(id, f, t) {
    try {
      let url = `/admin/athletes/${id}/sessions?limit=200`;
      if (f) url += `&from=${f}`;
      if (t) url += `&to=${t}`;
      const [sessions, summary] = await Promise.all([
        api.get(url),
        api.get(`/admin/athletes/${id}/summary`),
      ]);
      setAthDetail({ sessions, summary });
    } catch {}
  }
  async function loadAnalytics(id) {
    if (!id) { setAnalSess([]); setAnalBody(null); return; }
    try { setAnalSess(await api.get(`/admin/athletes/${id}/sessions?limit=200`)); } catch { setAnalSess([]); }
    try { setAnalBody(await api.get(`/admin/athletes/${id}/body-composition`)); } catch { setAnalBody(null); }
  }

  async function toggleActive(ath) {
    try {
      if (ath.active) {
        await api.delete(`/admin/athletes/${ath._id}`);
      } else {
        await api.put(`/admin/athletes/${ath._id}`, { active: true });
      }
      loadAthletes();
    } catch {}
  }

  async function createAthlete(e) {
    e.preventDefault();
    setFormErr(''); setFormOk(''); setCreating(true);
    try {
      await api.post('/admin/athletes', form);
      setFormOk(`Athlete "${form.name}" created successfully.`);
      setForm({ name: '', email: '', password: '', sport: '' });
      loadAthletes();
    } catch (err) {
      setFormErr(err.message);
    } finally {
      setCreating(false);
    }
  }

  // ── Sidebar ────────────────────────────────────────────────────────────
  const Sidebar = () => (
    <aside className={`fixed inset-y-0 left-0 z-30 w-56 bg-surface border-r border-bdr flex flex-col pt-16 transition-transform
      ${sideOpen ? 'translate-x-0' : '-translate-x-full'} md:translate-x-0 md:static md:pt-0`}>
      <div className="p-4 space-y-1">
        {SECTIONS.map(s => (
          <button
            key={s}
            onClick={() => { setSection(s); setSideOpen(false); }}
            className={`w-full text-left px-4 py-2.5 rounded-lg text-sm font-medium transition
              ${section === s ? 'bg-accent/15 text-accent' : 'text-ts hover:text-tp hover:bg-card'}`}
          >
            {s}
          </button>
        ))}
      </div>
    </aside>
  );

  // ── Render sections ────────────────────────────────────────────────────
  const sessPerDay = dash?.sessionsPerDay || [];
  const recentSess = dash?.recentSessions || [];

  return (
    <div className="min-h-screen bg-bg">
      <NavBar />
      <div className="flex relative">
        <Sidebar />

        {/* Mobile overlay */}
        {sideOpen && <div className="fixed inset-0 bg-black/50 z-20 md:hidden" onClick={() => setSideOpen(false)} />}

        <main className="flex-1 min-w-0 p-4 sm:p-6 space-y-6 md:ml-0">
          {/* Mobile menu toggle */}
          <button
            className="md:hidden border border-bdr text-ts px-3 py-1.5 rounded-lg text-sm"
            onClick={() => setSideOpen(v => !v)}
          >
            ☰ Menu
          </button>

          <h2 className="text-xl font-bold text-tp">{section}</h2>

          {/* ── Overview ── */}
          {section === 'Overview' && dash && (
            <div className="space-y-6">
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                <StatCard label="Total Athletes">{dash.totalAthletes}</StatCard>
                <StatCard label="Total Sessions">{dash.totalSessions}</StatCard>
                <StatCard label="Avg Load" sub="AU">{dash.avgLoad}</StatCard>
              </div>
              <ChartCard title="Sessions per Day (last 30d)">
                <Bar
                  data={{
                    labels: sessPerDay.map(d => d._id),
                    datasets: [{ data: sessPerDay.map(d => d.count), backgroundColor: '#FF6B35', borderRadius: 4 }],
                  }}
                  options={CHART_OPTS}
                />
              </ChartCard>
              <div className="bg-surface border border-bdr rounded-xl overflow-hidden">
                <div className="px-5 py-4 border-b border-bdr text-sm font-semibold text-tp">Recent Sessions (7d)</div>
                <div className="overflow-x-auto">
                  <table>
                    <thead><tr>{['Athlete','Date','Load','Readiness'].map(h => <th key={h}>{h}</th>)}</tr></thead>
                    <tbody>
                      {recentSess.slice(0, 20).map(s => (
                        <tr key={s._id}>
                          <td className="text-tp">{s.athlete?.name || '—'}</td>
                          <td className="text-ts whitespace-nowrap">{fmtDate(s.date)}</td>
                          <td className="font-mono">{fmtNum(s.totalLoad)}</td>
                          <td>{s.readinessPercent != null ? <Badge color={readinessColor(s.readinessPercent)}>{s.readinessPercent.toFixed(0)}%</Badge> : '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* ── Athletes ── */}
          {section === 'Athletes' && !selectedAthlete && (
            <div className="bg-surface border border-bdr rounded-xl overflow-hidden">
              <div className="overflow-x-auto">
                <table>
                  <thead><tr>{['Name','Email','Sport','Last Session','Load','Readiness','Status',''].map(h => <th key={h}>{h}</th>)}</tr></thead>
                  <tbody>
                    {athletes.map(a => (
                      <tr key={a._id} onClick={() => { setSelAth(a); loadAthDetail(a._id); }}>
                        <td className="text-tp font-medium">{a.name}</td>
                        <td className="text-ts">{a.email}</td>
                        <td className="text-ts">{a.sport || '—'}</td>
                        <td className="text-ts whitespace-nowrap">{fmtDate(a.lastSession)}</td>
                        <td className="font-mono">{fmtNum(a.lastTotalLoad)}</td>
                        <td>{a.lastReadiness != null ? <Badge color={readinessColor(a.lastReadiness)}>{a.lastReadiness.toFixed(0)}%</Badge> : '—'}</td>
                        <td><Badge color={a.active ? 'green' : 'gray'}>{a.active ? 'Active' : 'Inactive'}</Badge></td>
                        <td onClick={e => e.stopPropagation()}>
                          <button
                            onClick={() => toggleActive(a)}
                            className="text-xs border border-bdr px-3 py-1 rounded-lg text-ts hover:text-tp transition"
                          >
                            {a.active ? 'Deactivate' : 'Activate'}
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* ── Athlete Detail ── */}
          {section === 'Athletes' && selectedAthlete && (
            <div className="space-y-6">
              <div className="flex items-center gap-3">
                <button onClick={() => { setSelAth(null); setAthDetail(null); }} className="text-xs border border-bdr px-3 py-1.5 rounded-lg text-ts hover:text-tp transition">← Back</button>
                <div>
                  <div className="font-semibold text-tp">{selectedAthlete.name}</div>
                  <div className="text-xs text-ts">{selectedAthlete.email} · {selectedAthlete.sport || 'General'}</div>
                </div>
              </div>

              {/* Date filter */}
              <div className="flex gap-2 flex-wrap">
                <input type="date" value={athFrom} onChange={e => setAthFrom(e.target.value)} className="!w-auto text-xs" />
                <span className="text-ts text-xs self-center">to</span>
                <input type="date" value={athTo}   onChange={e => setAthTo(e.target.value)}   className="!w-auto text-xs" />
                <button onClick={() => loadAthDetail(selectedAthlete._id, athFrom, athTo)} className="bg-accent hover:bg-orange-600 text-white text-xs px-4 py-2 rounded-lg font-semibold transition">Apply</button>
              </div>

              {athDetail && (
                <>
                  {/* Summary stats */}
                  {(() => {
                    const ds = displayStats(athDetail.sessions, selectedAthlete);
                    return (
                      <>
                        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                          <StatCard label="Acute Load (7d)" sub="AU">{ds.acuteLoad}</StatCard>
                          <StatCard label="Chronic Load" sub="EWMA 28d">{ds.chronicLoad}</StatCard>
                          <StatCard label="ACWR">
                            <Badge color={acwrColor(ds.acwr)}>
                              {ds.acwr || 0} {acwrLabel(ds.acwr)}
                            </Badge>
                          </StatCard>
                          <StatCard label="Data Points">{ds.points || 0}</StatCard>
                        </div>
                        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                          <StatCard label="Tomorrow's Target Load" sub="Chronic × 0.8 – 1.3">
                            {ds.chronicLoad > 0
                              ? <span className="text-green-400 font-bold">{ds.targetLow} – {ds.targetHigh}</span>
                              : '—'}
                          </StatCard>
                          <StatCard label="Z-Score" sub="(Load − Chronic) / StdDev">
                            <span style={{ color: Math.abs(ds.zScore ?? 0) > 2 ? '#f87171' : '#2dd4bf' }}>
                              {ds.zScore != null ? fmtNum(ds.zScore, 2) : '—'}
                              {Math.abs(ds.zScore ?? 0) > 2 ? ' ⚠' : ''}
                            </span>
                          </StatCard>
                          <StatCard label="Std Deviation" sub="Historical load distribution">
                            {ds.stdDev > 0 ? ds.stdDev : '—'}
                          </StatCard>
                        </div>
                      </>
                    );
                  })()}

                  <AthCharts sessions={athDetail.sessions} athlete={selectedAthlete} />

                  {/* Session log */}
                  <div className="bg-surface border border-bdr rounded-xl overflow-hidden">
                    <div className="px-5 py-4 border-b border-bdr text-sm font-semibold text-tp">Session Log</div>
                    <div className="overflow-x-auto">
                      <table>
                        <thead><tr>{['Date','Total Load','Grade','Readiness'].map(h => <th key={h}>{h}</th>)}</tr></thead>
                        <tbody>
                          {[...athDetail.sessions].sort((a, b) => new Date(b.date) - new Date(a.date)).map(s => (
                            <tr key={s._id} onClick={() => setSelSession(s)}>
                              <td className="whitespace-nowrap text-tp">{fmtDate(s.date)}</td>
                              <td className="font-mono">{fmtNum(s.totalLoad)}</td>
                              <td>{s.scaledGrade != null ? <Badge color={s.scaledGrade >= 7 ? 'red' : s.scaledGrade >= 4 ? 'yellow' : 'green'}>{s.scaledGrade.toFixed(1)}</Badge> : '—'}</td>
                              <td>{s.readinessPercent != null ? <Badge color={readinessColor(s.readinessPercent)}>{s.readinessPercent.toFixed(0)}%</Badge> : '—'}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                </>
              )}
            </div>
          )}

          {/* ── Sessions ── */}
          {section === 'Sessions' && (
            <div className="space-y-4">
              <div className="flex gap-2 flex-wrap">
                <select value={sessAthId} onChange={e => setSessAthId(e.target.value)} className="!w-auto text-xs">
                  <option value="">All athletes</option>
                  {athletes.map(a => <option key={a._id} value={a._id}>{a.name}</option>)}
                </select>
                <input type="date" value={sessFrom} onChange={e => setSessFrom(e.target.value)} className="!w-auto text-xs" />
                <span className="text-ts text-xs self-center">to</span>
                <input type="date" value={sessTo}   onChange={e => setSessTo(e.target.value)}   className="!w-auto text-xs" />
                <button onClick={() => loadSessions(sessFrom, sessTo, sessAthId)} className="bg-accent hover:bg-orange-600 text-white text-xs px-4 py-2 rounded-lg font-semibold transition">Apply</button>
                <button onClick={() => { setSessFrom(''); setSessTo(''); setSessAthId(''); loadSessions(); }} className="border border-bdr text-ts hover:text-tp text-xs px-3 py-2 rounded-lg transition">Clear</button>
              </div>
              <div className="bg-surface border border-bdr rounded-xl overflow-hidden">
                <div className="overflow-x-auto">
                  <table>
                    <thead><tr>{['Date','Athlete','Sport','Types','Load','Grade','Readiness'].map(h => <th key={h}>{h}</th>)}</tr></thead>
                    <tbody>
                      {sessions.map(s => (
                        <tr key={s._id} onClick={() => setSelSession(s)}>
                          <td className="whitespace-nowrap text-tp">{fmtDate(s.date)}</td>
                          <td className="text-tp">{s.athlete?.name || '—'}</td>
                          <td className="text-ts">{s.athlete?.sport || '—'}</td>
                          <td className="text-ts">{[...(s.primaryTypes || []), ...(s.skillTypes || [])].join(', ') || '—'}</td>
                          <td className="font-mono">{fmtNum(s.totalLoad)}</td>
                          <td>{s.scaledGrade != null ? <Badge color={s.scaledGrade >= 7 ? 'red' : s.scaledGrade >= 4 ? 'yellow' : 'green'}>{s.scaledGrade.toFixed(1)}</Badge> : '—'}</td>
                          <td>{s.readinessPercent != null ? <Badge color={readinessColor(s.readinessPercent)}>{s.readinessPercent.toFixed(0)}%</Badge> : '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {sessions.length === 0 && <div className="py-12 text-center text-ts text-sm">No sessions found.</div>}
                </div>
              </div>
            </div>
          )}

          {/* ── Analytics ── */}
          {section === 'Analytics' && (
            <div className="space-y-6">
              <div className="flex gap-2 items-center">
                <label className="text-sm text-ts">Athlete:</label>
                <select
                  value={analAthId}
                  onChange={e => { setAnalAthId(e.target.value); loadAnalytics(e.target.value); }}
                  className="!w-auto"
                >
                  <option value="">Select athlete</option>
                  {athletes.map(a => <option key={a._id} value={a._id}>{a.name}</option>)}
                </select>
              </div>
              {analAthId && <BodyCompositionCard data={analBody} />}
              {analSessions.length > 0 && (
                <AthCharts
                  sessions={analSessions}
                  showTypes
                  athlete={athletes.find(a => a._id === analAthId)}
                />
              )}
              {analAthId && analSessions.length === 0 && <p className="text-ts text-sm">No sessions found.</p>}
            </div>
          )}

          {/* ── Workload Monitor ── */}
          {section === 'Workload Monitor' && (
            <WorkloadMonitorPage athletes={athletes} />
          )}

          {/* ── Create Athlete ── */}
          {section === 'Subscriptions' && <SubscriptionsSection athletes={athletes} />}

          {section === 'Create Athlete' && (
            <div className="max-w-md">
              <div className="bg-surface border border-bdr rounded-xl p-6 space-y-4">
                {formErr && <div className="bg-red-500/10 border border-red-500/40 rounded-lg px-4 py-3 text-red-400 text-sm">{formErr}</div>}
                {formOk  && <div className="bg-green-500/10 border border-green-500/40 rounded-lg px-4 py-3 text-green-400 text-sm">{formOk}</div>}
                <form onSubmit={createAthlete} className="space-y-4">
                  {[
                    { label: 'Full Name', key: 'name', type: 'text', placeholder: 'Jane Smith' },
                    { label: 'Email', key: 'email', type: 'email', placeholder: 'jane@example.com' },
                    { label: 'Password', key: 'password', type: 'password', placeholder: '••••••••' },
                    { label: 'Sport (optional)', key: 'sport', type: 'text', placeholder: 'Cricket, Running…' },
                  ].map(({ label, key, type, placeholder }) => (
                    <div key={key}>
                      <label className="block text-xs font-medium text-ts mb-1.5">{label}</label>
                      <input
                        type={type} placeholder={placeholder}
                        value={form[key]}
                        onChange={e => setForm(f => ({ ...f, [key]: e.target.value }))}
                        required={key !== 'sport'}
                      />
                    </div>
                  ))}
                  <button
                    type="submit" disabled={creating}
                    className="w-full bg-accent hover:bg-orange-600 disabled:opacity-60 text-white rounded-xl py-2.5 text-sm font-semibold transition"
                  >
                    {creating ? 'Creating…' : 'Create Athlete'}
                  </button>
                </form>
              </div>
            </div>
          )}
        </main>
      </div>

      <SessionModal session={selSession} onClose={() => setSelSession(null)} />
    </div>
  );
}

// ── Shared chart section for athlete detail + analytics ────────────────────
function AthCharts({ sessions, showTypes = false, athlete = null }) {
  const sorted = useMemo(() => [...sessions].sort((a, b) => new Date(a.date) - new Date(b.date)), [sessions]);
  const labels = sorted.map(s => fmtDate(s.date));
  const acwrData = useMemo(() => computeRollingACWR(sessions), [sessions]);
  const [workloadTab, setWorkloadTab] = useState('total');
  const workloadSeries = useMemo(() => buildWorkloadSeries(sessions, athlete), [sessions, athlete]);
  const activeWorkload = workloadSeries[workloadTab] || [];

  const typeCounts = useMemo(() => {
    const c = {};
    sessions.forEach(s => {
      [...(s.primaryTypes || []), ...(s.secondaryTypes || []), ...(s.skillTypes || []), ...(s.skillSubTypes || [])].forEach(t => {
        c[t] = (c[t] || 0) + 1;
      });
    });
    return c;
  }, [sessions]);

  return (
    <div className="space-y-6">
      <WorkloadResult
        active={workloadTab}
        onChange={setWorkloadTab}
        series={activeWorkload}
      />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <ChartCard title="Load History">
          <Bar
            data={{ labels, datasets: [{ data: sorted.map(s => s.totalLoad || 0), backgroundColor: '#FF6B35', borderRadius: 4 }] }}
            options={CHART_OPTS}
          />
        </ChartCard>
        <ChartCard title="ACWR Trend" acwrLegend>
          <Line
            data={{
              labels: acwrData.map(d => fmtDate(d.date)),
              datasets: [
                { data: acwrData.map(d => Math.min(d.acwr, 2.5)), borderColor: '#FF6B35', backgroundColor: 'rgba(255,107,53,.1)', tension: .4, cubicInterpolationMode: 'monotone', pointRadius: 2, fill: true },
                { data: Array(acwrData.length).fill(1.5), borderColor: '#F87171', borderDash: [6,4], borderWidth: 2, pointRadius: 0, fill: false },
                { data: Array(acwrData.length).fill(1.3), borderColor: '#34D399', borderDash: [6,4], borderWidth: 2, pointRadius: 0, fill: false },
                { data: Array(acwrData.length).fill(0.8), borderColor: '#60A5FA', borderDash: [6,4], borderWidth: 2, pointRadius: 0, fill: false },
              ],
            }}
            options={{ ...ACWR_OPTS, plugins: { ...ACWR_OPTS.plugins, legend: { display: false } } }}
          />
        </ChartCard>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <ChartCard title="Readiness Trend (%)">
          <Line
            data={{
              labels,
              datasets: [{ data: sorted.map(s => s.readinessPercent ?? null), borderColor: '#818CF8', backgroundColor: 'rgba(129,140,248,.1)', tension: .35, pointRadius: 2, fill: true, spanGaps: true }],
            }}
            options={CHART_OPTS}
          />
        </ChartCard>
        <ChartCard title="Training Types">
          <div className="flex items-center justify-center h-48">
            {Object.keys(typeCounts).length > 0
              ? <Doughnut
                  data={{ labels: Object.keys(typeCounts), datasets: [{ data: Object.values(typeCounts), backgroundColor: COLORS, borderWidth: 0, hoverOffset: 6 }] }}
                  options={{ ...DONUT_OPTS, maintainAspectRatio: false }}
                />
              : <span className="text-ts text-sm">No data</span>}
          </div>
        </ChartCard>
      </div>
    </div>
  );
}

function buildWorkloadSeries(sessions, athlete) {
  const monitorSeries = monitorSeriesForAthlete(athlete);
  if (monitorSeries) return monitorSeries;

  const records = buildDailyRecords(sessions);
  return {
    training: buildFlutterSeries(records, r => r.trainingLoad),
    skill: buildFlutterSeries(records, r => r.skillLoad),
    total: buildFlutterSeries(records, r => r.totalLoad),
  };
}

function displayStats(sessions, athlete) {
  const monitor = monitorSeriesForAthlete(athlete);
  if (monitor?.total?.length) {
    const latest = monitor.total[monitor.total.length - 1];
    const chronic = latest.chronic;
    return {
      acuteLoad:   Math.round(latest.acute),
      chronicLoad: chronic.toFixed(1),
      acwr:        latest.acwr,
      zScore:      latest.z ?? 0,
      targetLow:   Math.round(chronic * 0.8),
      targetHigh:  Math.round(chronic * 1.3),
      points:      monitor.total.length,
    };
  }
  const stats = computeStats(sessions);
  return {
    acuteLoad:   stats.acuteLoad,
    chronicLoad: stats.chronicLoad,
    acwr:        stats.acwr,
    zScore:      stats.zScore,
    stdDev:      stats.stdDev,
    targetLow:   stats.targetLow,
    targetHigh:  stats.targetHigh,
    points:      sessions.length,
  };
}

function WorkloadResult({ active, onChange, series }) {
  const latest = series[series.length - 1];
  const tabs = [
    { id: 'training', label: 'Training' },
    { id: 'skill', label: 'Skill' },
    { id: 'total', label: 'Daily Total' },
  ];

  if (!latest) {
    return (
      <div className="bg-surface border border-bdr rounded-xl p-6 text-center text-ts text-sm">
        No workload result available yet.
      </div>
    );
  }

  return (
    <div className="bg-surface border border-bdr rounded-xl p-5 space-y-5">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <div className="text-sm font-semibold text-tp">Workload Result</div>
          <div className="text-xs text-ts mt-1">Training, skill, and daily total load just like the mobile app.</div>
        </div>
        <div className="inline-flex bg-card border border-bdr rounded-lg p-1">
          {tabs.map(t => (
            <button
              key={t.id}
              onClick={() => onChange(t.id)}
              className={`px-3 py-1.5 rounded-md text-xs font-semibold transition ${
                active === t.id ? 'bg-accent text-white' : 'text-ts hover:text-tp'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-6 gap-3">
        <MiniMetric label="Session Load" value={fmtNum(latest.load)} sub="Latest" tone="orange" />
        <MiniMetric label="7-day Acute" value={fmtNum(latest.acute)} sub="Rolling sum" tone="blue" />
        <MiniMetric label="Chronic" value={latest.chronic.toFixed(1)} sub="EWMA 28d" tone="yellow" />
        <MiniMetric label="ACWR" value={latest.acwr > 0 ? latest.acwr.toFixed(2) : '0'} sub={acwrLabel(latest.acwr)} tone={acwrTone(latest.acwr)} />
        <MiniMetric label="Z-Score" value={latest.z != null ? latest.z.toFixed(2) : '0.00'} sub={Math.abs(latest.z || 0) > 2 ? 'Flag' : 'Normal'} tone={Math.abs(latest.z || 0) > 2 ? 'red' : 'green'} />
        <MiniMetric label="Data Points" value={series.length} sub="Days logged" tone="gray" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        <div className="bg-card border border-bdr rounded-xl p-4">
          <div className="text-xs font-semibold text-tp mb-3">ACWR Zone</div>
          <AcwrGauge value={latest.acwr} />
        </div>
        <div className="lg:col-span-2 grid grid-cols-1 md:grid-cols-2 gap-5">
          <ChartCard title="Load History">
            <Bar
              data={{
                labels: series.map(d => d.label || fmtDate(d.date)),
                datasets: [
                  { label: 'Load', data: series.map(d => Math.round(d.load)), backgroundColor: '#FF6B35', borderRadius: 4 },
                  { label: '7-day Acute', data: series.map(d => Math.round(d.acute)), backgroundColor: '#38BDF8', borderRadius: 4 },
                  { label: 'Chronic', data: series.map(d => Math.round(d.chronic)), backgroundColor: '#FBBF24', borderRadius: 4 },
                ],
              }}
              options={CHART_OPTS}
            />
          </ChartCard>
          <ChartCard title="ACWR Trend" acwrLegend>
            <Line
              data={{
                labels: series.map(d => d.label || fmtDate(d.date)),
                datasets: [
                  { data: series.map(d => Math.min(Number(d.acwr.toFixed(2)), 2.5)), borderColor: '#FF6B35', backgroundColor: 'rgba(255,107,53,.1)', tension: .4, cubicInterpolationMode: 'monotone', pointRadius: 2, fill: true },
                  { data: Array(series.length).fill(1.5), borderColor: '#F87171', borderDash: [6, 4], borderWidth: 2, pointRadius: 0, fill: false },
                  { data: Array(series.length).fill(1.3), borderColor: '#34D399', borderDash: [6, 4], borderWidth: 2, pointRadius: 0, fill: false },
                  { data: Array(series.length).fill(0.8), borderColor: '#60A5FA', borderDash: [6, 4], borderWidth: 2, pointRadius: 0, fill: false },
                ],
              }}
              options={{ ...ACWR_OPTS, plugins: { ...ACWR_OPTS.plugins, legend: { display: false } } }}
            />
          </ChartCard>
        </div>
      </div>

      <div className="bg-card border border-bdr rounded-xl overflow-hidden">
        <div className="px-4 py-3 border-b border-bdr text-xs font-semibold text-tp">Session Log (latest 10 days)</div>
        <div className="overflow-x-auto">
          <table>
            <thead><tr>{['Date', 'Load', 'Acute', 'Chronic', 'ACWR', 'Z-Score'].map(h => <th key={h}>{h}</th>)}</tr></thead>
            <tbody>
              {[...series].slice(-10).reverse().map(d => (
                <tr key={dayKey(d.date)}>
                  <td className="text-tp whitespace-nowrap">{d.label || fmtDate(d.date)}</td>
                  <td className="font-mono">{fmtNum(d.load)}</td>
                  <td className="font-mono">{fmtNum(d.acute)}</td>
                  <td className="font-mono">{d.chronic.toFixed(1)}</td>
                  <td><Badge color={acwrColor(d.acwr)}>{d.acwr > 0 ? d.acwr.toFixed(2) : 'No data'}</Badge></td>
                  <td className="font-mono">{d.z != null ? d.z.toFixed(2) : '0.00'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function MiniMetric({ label, value, sub, tone }) {
  const tones = {
    orange: 'border-accent/40 bg-accent/10 text-accent',
    blue: 'border-sky-400/40 bg-sky-400/10 text-sky-300',
    yellow: 'border-amber-400/40 bg-amber-400/10 text-amber-300',
    green: 'border-green-400/40 bg-green-400/10 text-green-300',
    red: 'border-red-400/40 bg-red-400/10 text-red-300',
    gray: 'border-bdr bg-bg text-ts',
  };
  return (
    <div className={`border rounded-xl p-3 ${tones[tone] || tones.gray}`}>
      <div className="text-[11px] text-ts">{label}</div>
      <div className="text-lg font-extrabold mt-1">{value}</div>
      <div className="text-[11px] text-ts mt-0.5 truncate">{sub}</div>
    </div>
  );
}

function GradePill({ grade }) {
  return (
    <span className="text-[10px] font-bold px-2 py-0.5 rounded-full whitespace-nowrap"
          style={{ color: grade.color, backgroundColor: `${grade.color}22` }}>
      {grade.label}
    </span>
  );
}

// Full body-composition result — mirrors the mobile app's analysis view.
function BodyCompositionCard({ data }) {
  const latest = data?.latest;
  const fmt = (v, d = 1) => (v == null ? '—' : Number(v).toFixed(d));
  const fmtDate = (s) => (s ? new Date(s).toLocaleDateString() : '—');

  // Recompute the full analysis from the stored measurements (same engine as the app).
  const r = latest ? computeBCA(latest) : null;

  if (!latest || !r) {
    return (
      <div className="bg-surface border border-bdr rounded-xl p-5">
        <div className="text-[11px] text-ts uppercase tracking-wider mb-2">Body Composition</div>
        <p className="text-ts text-sm">No body-composition estimate synced yet.</p>
      </div>
    );
  }

  const male = r.isMale;
  const ip = interpret(r);
  const lbmPct = 100 - r.bfPercent;

  const metrics = [
    { name: 'Fat Percentage',    value: `${fmt(r.bfPercent)}%`,        grade: gradeBF(r.bfPercent, male),           sub: 'Composition balance' },
    { name: 'FFMI',              value: fmt(r.ffmi),                    grade: gradeFFMI(r.ffmi, male),              sub: 'Fat-free mass index' },
    { name: 'Skeletal Muscle %', value: `${fmt(r.smmPercent)}%`,        grade: gradeSMM(r.smmPercent, male),         sub: 'of total body weight' },
    { name: 'Muscle Mass Index', value: `${fmt(r.smi, 2)} kg/m²`,       grade: gradeSMI(r.smi, male),                sub: 'Sarcopenia screening' },
    { name: 'Relative ASM',      value: `${fmt(r.relativeAsm)}%`,       grade: gradeRelASM(r.relativeAsm, male),     sub: 'Functional limb muscle' },
    { name: 'Muscle-Bone Ratio', value: fmt(r.mbr),                     grade: gradeMBR(r.mbr),                      sub: 'LBM / Bone mass' },
    { name: 'Appendicular Ratio',value: `${fmt(r.appendicularToTotal)}%`, grade: gradeAppendicular(r.appendicularToTotal, male), sub: 'Limb muscle vs body' },
    { name: 'Axial Ratio',       value: `${fmt(r.axialToTotal)}%`,      grade: gradeAxial(r.axialToTotal, male),     sub: 'Core muscle vs body' },
  ];

  const layerRows = [
    ['Total Body Weight',     100,                          r.weightKg, null,      true],
    ['Total Body Fat',        r.bfPercent,                  r.bfKg,     '#EF4444'],
    ['Lean Body Mass (LBM)',  lbmPct,                       r.lbm,      '#00CF74'],
    ['Total Skeletal Muscle', r.smmPercent,                 r.tsm,      '#4AADFF'],
    ['  Appendicular (ASM)',  r.appendicularToTotal,        r.asm,      null],
    ['  Axial Muscle Mass',   r.axialToTotal,               r.axial,    null],
    ['Essential Organs',      r.essentialOrgans / r.weightKg * 100, r.essentialOrgans, null],
    ['Bone Mineral Content',  r.bmc / r.weightKg * 100,     r.bmc,      null],
    ['Skin & Connective',     r.skinConnective / r.weightKg * 100,  r.skinConnective, null],
    ['Non-Muscle Lean Fluids',r.nonMuscleFluid / r.weightKg * 100,  r.nonMuscleFluid, null],
  ];

  return (
    <div className="space-y-4">
      {/* Header + summary */}
      <div className="bg-surface border border-bdr rounded-xl p-5">
        <div className="flex items-center justify-between mb-4">
          <div className="text-[11px] text-ts uppercase tracking-wider">Body Composition · {male ? 'Male' : 'Female'}</div>
          <div className="text-xs text-ts">{fmtDate(latest.date)}</div>
        </div>
        <div className="rounded-lg px-4 py-3 mb-4" style={{ backgroundColor: `${ip.overallColor}14`, border: `1px solid ${ip.overallColor}4D` }}>
          <div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: ip.overallColor }}>Overall Profile</div>
          <div className="text-lg font-extrabold" style={{ color: ip.overallColor }}>{ip.overallLabel}</div>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
          <MiniMetric label="Body Fat"        value={`${fmt(r.bfPercent)}%`}  sub={`${fmt(r.bfKg)} kg`}             tone="red" />
          <MiniMetric label="Lean Mass"       value={`${fmt(r.lbm)} kg`}      sub={`${fmt(lbmPct)}% of BW`}         tone="green" />
          <MiniMetric label="Skeletal Muscle" value={`${fmt(r.smmPercent)}%`} sub={`${fmt(r.tsm)} kg`}              tone="blue" />
          <MiniMetric label="SMI"             value={fmt(r.smi, 2)}           sub="kg/m²"                          tone="blue" />
          <MiniMetric label="FFMI"            value={fmt(r.ffmi)}             sub="fat-free index"                 tone="orange" />
          <MiniMetric label="Weight"          value={`${fmt(r.weightKg)} kg`} sub={`${fmt(r.heightCm, 0)} cm`}      tone="gray" />
        </div>
      </div>

      {/* Structural layer table */}
      <div className="bg-surface border border-bdr rounded-xl p-5">
        <div className="text-[11px] text-ts uppercase tracking-wider mb-3">Structural Layer Composition</div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-ts text-[11px] uppercase tracking-wider text-left border-b border-bdr">
                <th className="py-2 pr-3 font-medium">Layer</th>
                <th className="py-2 pr-3 font-medium text-right">%</th>
                <th className="py-2 pr-3 font-medium text-right">kg</th>
                <th className="py-2 pr-3 font-medium text-right">lbs</th>
              </tr>
            </thead>
            <tbody>
              {layerRows.map(([label, pct, kg, color, bold]) => (
                <tr key={label} className="border-b border-bdr/40">
                  <td className={`py-1.5 pr-3 ${bold ? 'font-bold text-tp' : 'text-tp'}`} style={color ? { color } : undefined}>
                    {label.startsWith('  ') ? <span className="text-ts">{label.trim()}</span> : label}
                  </td>
                  <td className="py-1.5 pr-3 text-right" style={color ? { color } : undefined}>{fmt(pct, 2)}%</td>
                  <td className="py-1.5 pr-3 text-right" style={color ? { color } : undefined}>{fmt(kg, 2)}</td>
                  <td className="py-1.5 pr-3 text-right text-ts">{fmt(kg * 2.20462, 2)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Key metrics grid */}
      <div className="bg-surface border border-bdr rounded-xl p-5">
        <div className="text-[11px] text-ts uppercase tracking-wider mb-3">Key Metrics & Analysis</div>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
          {metrics.map((m) => (
            <div key={m.name} className="border border-bdr rounded-xl p-3 bg-bg">
              <div className="flex justify-end mb-2"><GradePill grade={m.grade} /></div>
              <div className="text-xl font-extrabold text-tp">{m.value}</div>
              <div className="text-[12px] font-semibold text-tp mt-0.5">{m.name}</div>
              <div className="text-[10px] text-ts">{m.sub}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Interpretation */}
      <div className="bg-surface border border-bdr rounded-xl p-5">
        <div className="text-[11px] text-ts uppercase tracking-wider mb-3">Interpretation Report</div>
        <div className="text-[10px] font-bold uppercase tracking-wider text-ts mb-1">Analytical Insights</div>
        <ul className="text-sm text-ts space-y-1.5 mb-4 list-disc pl-5">
          <li><span className="text-tp font-semibold">Muscle Efficiency:</span> FFMI of {fmt(r.ffmi)} kg/m² — {gradeFFMI(r.ffmi, male).label} muscularity relative to height.</li>
          <li><span className="text-tp font-semibold">Skeletal Support:</span> Muscle-to-Bone Ratio of {fmt(r.mbr)} — {gradeMBR(r.mbr).label}.</li>
          <li><span className="text-tp font-semibold">Weight Distribution:</span> {ip.limbDominant ? 'Limb-Dominant' : 'Core-Dominant'} architecture ({fmt(r.appendicularToTotal)}% limb / {fmt(r.axialToTotal)}% core muscle of BW).</li>
          <li><span className="text-tp font-semibold">Composition Balance:</span> {fmt(r.lbm)} kg lean vs {fmt(r.bfKg)} kg fat mass.</li>
        </ul>
        <div className="text-[10px] font-bold uppercase tracking-wider text-ts mb-1">Suggestions</div>
        <ol className="text-sm text-ts space-y-1.5 list-decimal pl-5">
          {ip.actions.map((a, i) => <li key={i}>{a}</li>)}
        </ol>
      </div>

      {/* History */}
      {data?.history?.length > 1 && (
        <div className="bg-surface border border-bdr rounded-xl p-5">
          <div className="text-[11px] text-ts uppercase tracking-wider mb-3">History</div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-ts text-[11px] uppercase tracking-wider text-left border-b border-bdr">
                  <th className="py-2 pr-3 font-medium">Date</th>
                  <th className="py-2 pr-3 font-medium">Body Fat</th>
                  <th className="py-2 pr-3 font-medium">LBM</th>
                  <th className="py-2 pr-3 font-medium">SMM %</th>
                  <th className="py-2 pr-3 font-medium">FFMI</th>
                  <th className="py-2 pr-3 font-medium">Weight</th>
                </tr>
              </thead>
              <tbody>
                {data.history.map((h) => (
                  <tr key={h._id} className="border-b border-bdr/50 text-tp">
                    <td className="py-2 pr-3 text-ts">{fmtDate(h.date)}</td>
                    <td className="py-2 pr-3">{fmt(h.bfPercent)}%</td>
                    <td className="py-2 pr-3">{fmt(h.lbm)} kg</td>
                    <td className="py-2 pr-3">{fmt(h.smmPercent)}%</td>
                    <td className="py-2 pr-3">{fmt(h.ffmi)}</td>
                    <td className="py-2 pr-3">{fmt(h.weightKg)} kg</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

function AcwrGauge({ value }) {
  const clamped = Math.max(0, Math.min(2, value || 0));
  const left = `${clamped * 50}%`;
  return (
    <div>
      <div className="h-4 rounded-md overflow-hidden flex">
        <div className="basis-[40%] bg-blue-500/80" />
        <div className="basis-[25%] bg-green-400/80" />
        <div className="basis-[10%] bg-amber-400/80" />
        <div className="basis-[25%] bg-red-500/80" />
      </div>
      <div className="relative h-7">
        <div className="absolute top-0 -translate-x-1/2 text-white text-lg leading-none" style={{ left }}>▼</div>
      </div>
      <div className="flex justify-between text-[10px] text-ts">
        <span>0</span><span>0.8</span><span>1.3</span><span>1.5</span><span>2.0+</span>
      </div>
      <div className="mt-3 text-center">
        <Badge color={acwrColor(value)}>{value > 0 ? `ACWR ${value.toFixed(2)} - ${acwrLabel(value)}` : 'No data'}</Badge>
      </div>
    </div>
  );
}

function acwrTone(value) {
  if (!value) return 'gray';
  if (value < 0.8) return 'blue';
  if (value <= 1.3) return 'green';
  if (value <= 1.5) return 'yellow';
  return 'red';
}

function AcwrZoneLegend() {
  return (
    <div className="flex items-center gap-3 flex-wrap">
      {[
        { color: '#60A5FA', label: '0.8', zone: 'Under' },
        { color: '#34D399', label: '1.3', zone: 'Sweet' },
        { color: '#F87171', label: '1.5', zone: 'Caution' },
      ].map(({ color, label, zone }) => (
        <span key={label} className="inline-flex items-center gap-1 text-[10px]">
          <span className="inline-block w-5 border-t-2 border-dashed" style={{ borderColor: color }} />
          <span style={{ color }} className="font-semibold">{label}</span>
          <span className="text-ts">({zone})</span>
        </span>
      ))}
    </div>
  );
}

function ChartCard({ title, children, acwrLegend = false }) {
  return (
    <div className="bg-surface border border-bdr rounded-xl p-5">
      <div className="flex items-center justify-between gap-2 mb-4">
        <div className="text-sm font-semibold text-tp">{title}</div>
        {acwrLegend && <AcwrZoneLegend />}
      </div>
      <div className="relative h-48">{children}</div>
    </div>
  );
}
