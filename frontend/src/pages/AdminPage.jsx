import React, { useEffect, useState, useMemo } from 'react';
import { Bar, Line, Doughnut } from 'react-chartjs-2';
import NavBar from '../components/NavBar';
import StatCard from '../components/StatCard';
import Badge from '../components/Badge';
import SessionModal from '../components/SessionModal';
import { api } from '../api';
import { computeRollingACWR } from '../utils/acwr';
import { fmtDate, fmtNum } from '../utils/fmt';
import { CHART_OPTS, DONUT_OPTS, COLORS } from '../utils/chartDefaults';
import { acwrColor, acwrLabel, readinessColor } from '../components/Badge';

const SECTIONS = ['Overview', 'Athletes', 'Sessions', 'Analytics', 'Create Athlete'];

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

  // Create athlete form
  const [form, setForm]               = useState({ name: '', email: '', password: '', sport: '' });
  const [formErr, setFormErr]         = useState('');
  const [formOk, setFormOk]           = useState('');
  const [creating, setCreating]       = useState(false);

  // ── Load data per section ──────────────────────────────────────────────
  useEffect(() => {
    if (section === 'Overview') loadDash();
    if (section === 'Athletes') loadAthletes();
    if (section === 'Sessions') loadSessions();
    if (section === 'Create Athlete') loadAthletes();
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
    if (!id) return;
    try { setAnalSess(await api.get(`/admin/athletes/${id}/sessions?limit=200`)); } catch {}
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
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                    <StatCard label="Acute Load" sub="AU">{athDetail.summary.acuteLoad}</StatCard>
                    <StatCard label="Chronic Load">{athDetail.summary.chronicLoad}</StatCard>
                    <StatCard label="ACWR">
                      <Badge color={acwrColor(athDetail.summary.acwr)}>
                        {athDetail.summary.acwr || 0} {acwrLabel(athDetail.summary.acwr)}
                      </Badge>
                    </StatCard>
                    <StatCard label="Sessions">{athDetail.summary.totalSessions || 0}</StatCard>
                  </div>

                  <AthCharts sessions={athDetail.sessions} />

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
              {analSessions.length > 0 && <AthCharts sessions={analSessions} showTypes />}
              {analAthId && analSessions.length === 0 && <p className="text-ts text-sm">No sessions found.</p>}
            </div>
          )}

          {/* ── Create Athlete ── */}
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
function AthCharts({ sessions, showTypes = false }) {
  const sorted = useMemo(() => [...sessions].sort((a, b) => new Date(a.date) - new Date(b.date)), [sessions]);
  const labels = sorted.map(s => fmtDate(s.date));
  const acwrData = useMemo(() => computeRollingACWR(sessions), [sessions]);

  const typeCounts = useMemo(() => {
    const c = {};
    sessions.forEach(s => {
      [...(s.primaryTypes || []), ...(s.skillTypes || [])].forEach(t => { c[t] = (c[t] || 0) + 1; });
    });
    return c;
  }, [sessions]);

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <ChartCard title="Load History">
          <Bar
            data={{ labels, datasets: [{ data: sorted.map(s => s.totalLoad || 0), backgroundColor: '#FF6B35', borderRadius: 4 }] }}
            options={CHART_OPTS}
          />
        </ChartCard>
        <ChartCard title="ACWR Trend">
          <Line
            data={{
              labels: acwrData.map(d => fmtDate(d.date)),
              datasets: [
                { data: acwrData.map(d => d.acwr), borderColor: '#FF6B35', backgroundColor: 'rgba(255,107,53,.1)', tension: .35, pointRadius: 2, fill: true },
                { data: Array(acwrData.length).fill(1.5), borderColor: '#f87171', borderDash: [4,4], borderWidth: 1, pointRadius: 0, fill: false },
                { data: Array(acwrData.length).fill(0.8), borderColor: '#4ade80', borderDash: [4,4], borderWidth: 1, pointRadius: 0, fill: false },
              ],
            }}
            options={{ ...CHART_OPTS, plugins: { ...CHART_OPTS.plugins, legend: { display: false } } }}
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

function ChartCard({ title, children }) {
  return (
    <div className="bg-surface border border-bdr rounded-xl p-5">
      <div className="text-sm font-semibold text-tp mb-4">{title}</div>
      <div className="relative h-48">{children}</div>
    </div>
  );
}
