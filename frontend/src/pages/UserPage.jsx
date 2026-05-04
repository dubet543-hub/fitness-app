import React, { useEffect, useState, useMemo } from 'react';
import { Bar, Line, Doughnut } from 'react-chartjs-2';
import NavBar from '../components/NavBar';
import StatCard from '../components/StatCard';
import Badge from '../components/Badge';
import SessionModal from '../components/SessionModal';
import { api, getUser } from '../api';
import { computeStats, computeRollingACWR } from '../utils/acwr';
import { fmtDate, fmtNum } from '../utils/fmt';
import { CHART_OPTS, DONUT_OPTS, COLORS } from '../utils/chartDefaults';
import { acwrColor, acwrLabel, readinessColor } from '../components/Badge';

export default function UserPage() {
  const user = getUser();
  const [sessions, setSessions] = useState([]);
  const [from, setFrom]         = useState('');
  const [to, setTo]             = useState('');
  const [tab, setTab]           = useState('charts');
  const [selected, setSelected] = useState(null);
  const [loading, setLoading]   = useState(true);

  async function load(f, t) {
    setLoading(true);
    try {
      let url = '/sessions?limit=500';
      if (f) url += `&from=${f}`;
      if (t) url += `&to=${t}`;
      setSessions(await api.get(url));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  const stats = useMemo(() => computeStats(sessions), [sessions]);
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
    <div className="min-h-screen bg-bg">
      <NavBar />
      <main className="max-w-6xl mx-auto px-4 sm:px-6 py-8 space-y-8">

        {/* Header + date filter */}
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-tp">
              Welcome back, <span className="text-accent">{user?.name?.split(' ')[0]}</span>
            </h1>
            <p className="text-sm text-ts mt-1">
              Your training overview · <span className="text-tp">{user?.sport || 'General'}</span>
            </p>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <input type="date" value={from} onChange={e => setFrom(e.target.value)} className="!w-auto text-xs" />
            <span className="text-ts text-xs">to</span>
            <input type="date" value={to}   onChange={e => setTo(e.target.value)}   className="!w-auto text-xs" />
            <button onClick={() => load(from, to)}  className="bg-accent hover:bg-orange-600 text-white text-xs px-4 py-2 rounded-lg font-semibold transition">Apply</button>
            <button onClick={() => { setFrom(''); setTo(''); load(); }} className="border border-bdr text-ts hover:text-tp text-xs px-3 py-2 rounded-lg transition">Clear</button>
          </div>
        </div>

        {/* Stat row */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          <StatCard label="Acute Load (7d)" sub="AU">{stats.acuteLoad}</StatCard>
          <StatCard label="Chronic Load" sub="EWMA 28d">{stats.chronicLoad}</StatCard>
          <StatCard label="ACWR">
            <Badge color={acwrColor(stats.acwr)}>
              {stats.acwr > 0 ? `${stats.acwr} ${acwrLabel(stats.acwr)}` : 'No data'}
            </Badge>
          </StatCard>
          <StatCard label="Last Readiness" sub="%">
            {stats.lastReadiness != null ? stats.lastReadiness.toFixed(0) : '—'}
          </StatCard>
        </div>

        {/* Tabs */}
        <div className="flex gap-2">
          {['charts', 'sessions'].map(t => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition ${tab === t ? 'bg-accent text-white' : 'text-ts hover:text-tp hover:bg-card'}`}
            >
              {t === 'charts' ? 'Charts' : 'Session Log'}
            </button>
          ))}
        </div>

        {/* Charts panel */}
        {tab === 'charts' && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <ChartCard title="Session Load History">
                <Bar
                  data={{
                    labels,
                    datasets: [{ data: sorted.map(s => s.totalLoad || 0), backgroundColor: '#FF6B35', borderRadius: 4 }],
                  }}
                  options={CHART_OPTS}
                />
              </ChartCard>
              <ChartCard title="ACWR Trend">
                <Line
                  data={{
                    labels: acwrData.map(d => fmtDate(d.date)),
                    datasets: [
                      { data: acwrData.map(d => d.acwr), borderColor: '#FF6B35', backgroundColor: 'rgba(255,107,53,.1)', tension: .35, pointRadius: 2, fill: true },
                      { data: Array(acwrData.length).fill(1.5), borderColor: '#f87171', borderDash: [4, 4], borderWidth: 1, pointRadius: 0, fill: false },
                      { data: Array(acwrData.length).fill(0.8), borderColor: '#4ade80', borderDash: [4, 4], borderWidth: 1, pointRadius: 0, fill: false },
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
              <ChartCard title="Training Type Distribution" fixedHeight={false}>
                <div className="flex items-center justify-center h-48">
                  {Object.keys(typeCounts).length > 0
                    ? <Doughnut
                        data={{
                          labels: Object.keys(typeCounts),
                          datasets: [{ data: Object.values(typeCounts), backgroundColor: COLORS, borderWidth: 0, hoverOffset: 6 }],
                        }}
                        options={{ ...DONUT_OPTS, maintainAspectRatio: false }}
                      />
                    : <span className="text-ts text-sm">No data</span>
                  }
                </div>
              </ChartCard>
            </div>
          </div>
        )}

        {/* Sessions table */}
        {tab === 'sessions' && (
          <div className="bg-surface border border-bdr rounded-xl overflow-hidden">
            <div className="px-5 py-4 border-b border-bdr flex items-center justify-between">
              <div className="text-sm font-semibold text-tp">Session History</div>
              <div className="text-xs text-ts">{sessions.length} session{sessions.length !== 1 ? 's' : ''}</div>
            </div>
            {loading ? (
              <div className="py-16 text-center text-ts text-sm">Loading…</div>
            ) : sessions.length === 0 ? (
              <div className="py-16 text-center text-ts text-sm">No sessions found.</div>
            ) : (
              <div className="overflow-x-auto">
                <table>
                  <thead>
                    <tr>
                      {['Date', 'Primary Types', 'Skill Types', 'Total Load', 'Grade', 'Readiness'].map(h => (
                        <th key={h}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {[...sessions].sort((a, b) => new Date(b.date) - new Date(a.date)).map(s => (
                      <tr key={s._id} onClick={() => setSelected(s)}>
                        <td className="text-tp whitespace-nowrap">{fmtDate(s.date)}</td>
                        <td className="text-ts">{(s.primaryTypes || []).join(', ') || '—'}</td>
                        <td className="text-ts">{(s.skillTypes   || []).join(', ') || '—'}</td>
                        <td className="font-mono text-tp">{fmtNum(s.totalLoad)}</td>
                        <td>
                          {s.scaledGrade != null
                            ? <Badge color={s.scaledGrade >= 7 ? 'red' : s.scaledGrade >= 4 ? 'yellow' : 'green'}>{s.scaledGrade.toFixed(1)}</Badge>
                            : '—'}
                        </td>
                        <td>
                          {s.readinessPercent != null
                            ? <Badge color={readinessColor(s.readinessPercent)}>{s.readinessPercent.toFixed(0)}%</Badge>
                            : '—'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </main>

      <SessionModal session={selected} onClose={() => setSelected(null)} />
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
