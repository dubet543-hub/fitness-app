// ─── Shared performance metrics ─────────────────────────────────────────────
//
// These helpers mirror the Flutter app's lib/services/dashboard_metrics.dart and
// lib/screens/player_stats_screen.dart so the admin dashboard reports the SAME
// numbers athletes see in the app. Keep the two in sync when either changes.

/** Session RPE-style exertion on a fixed 0–10 scale, derived from load. */
function exertion(load) {
  const l = load || 0;
  return l > 0 ? Math.min(10, 2.087 * Math.log(l / 50 + 1) + 2) : 2;
}

/**
 * ACWR "optimality" on a 0–1 scale: peaks at the ~1.05 sweet spot and falls off
 * as the acute:chronic ratio drifts toward detraining (<0.8) or spikes (>1.3).
 */
function loadBalance(acwr) {
  return Math.max(0, Math.min(1, 1 - Math.abs((acwr || 0) - 1.05) / 1.05));
}

/**
 * Composite performance = 60% recovery readiness + 40% training-load balance.
 * @param {number} readinessFraction  readiness as a 0–1 fraction
 * @param {number} acwr               acute:chronic workload ratio
 * @returns {number} performance as a 0–1 fraction
 */
function performance(readinessFraction, acwr) {
  const r = Math.max(0, Math.min(1, readinessFraction || 0));
  return Math.max(0, Math.min(1, 0.6 * r + 0.4 * loadBalance(acwr)));
}

/** ACWR interpretation zone — labels match the app's player_stats_screen. */
function acwrZone(acwr) {
  const v = acwr || 0;
  if (v <= 0)   return { label: 'No Data',      level: 'none',    color: '#94A3B8' };
  if (v < 0.8)  return { label: 'Undertraining', level: 'low',     color: '#448AFF' };
  if (v <= 1.3) return { label: 'Sweet Spot',    level: 'optimal', color: '#69F0AE' };
  if (v <= 1.5) return { label: 'Caution',       level: 'caution', color: '#FFAB40' };
  return { label: 'Danger Zone', level: 'danger', color: '#FF5252' };
}

/** Athlete is flagged when workload spikes (ACWR > 1.5) or readiness is low (<25%). */
function isFlagged({ acwr = 0, readinessPercent = 100 } = {}) {
  return acwr > 1.5 || readinessPercent < 25;
}

function round(n, dp = 1) {
  const f = 10 ** dp;
  return Math.round((n || 0) * f) / f;
}

/**
 * ACWR / load summary from a session history (ascending by date, each with
 * `date` and `totalLoad`). Mirrors the logic previously inlined in the summary
 * endpoint so the dashboard's flagging uses the identical ACWR.
 */
function loadSummary(sessions) {
  if (!sessions || !sessions.length) {
    return { acuteLoad: 0, chronicLoad: 0, acwr: 0, stdDev: 0, zScore: 0,
             targetLow: 0, targetHigh: 0, totalSessions: 0 };
  }

  const loads  = sessions.map(s => s.totalLoad || 0);
  const lambda = 2 / 29;

  // Per-session 7-day acute averages
  const acuteByIdx = sessions.map((s, i) => {
    const dayCutoff = new Date(s.date); dayCutoff.setDate(dayCutoff.getDate() - 7);
    const sum7 = sessions.slice(0, i + 1)
      .filter(r => new Date(r.date) > dayCutoff)
      .reduce((acc, r) => acc + (r.totalLoad || 0), 0);
    return sum7 / 7;
  });

  // Chronic = EWMA of the acute values (not raw loads)
  let chronic = 0;
  for (let i = 0; i < acuteByIdx.length; i++) {
    chronic = i === 0 ? acuteByIdx[i] : acuteByIdx[i] * lambda + chronic * (1 - lambda);
  }
  const acuteLoad   = acuteByIdx[acuteByIdx.length - 1];
  const chronicLoad = chronic;
  const acwr        = chronicLoad > 0 ? acuteLoad / chronicLoad : 0;

  const mean     = loads.reduce((a, b) => a + b, 0) / loads.length;
  const sigma    = Math.sqrt(loads.map(l => (l - mean) ** 2).reduce((a, b) => a + b, 0) / loads.length);
  const lastLoad = loads[loads.length - 1];
  const zScore   = sigma === 0 ? 0 : (lastLoad - chronicLoad) / sigma;

  return {
    acuteLoad:    round(acuteLoad),
    chronicLoad:  round(chronicLoad),
    acwr:         round(acwr, 2),
    stdDev:       round(sigma),
    zScore:       round(zScore, 2),
    targetLow:    Math.round(chronicLoad * 0.8),
    targetHigh:   Math.round(chronicLoad * 1.3),
    totalSessions: sessions.length,
  };
}

module.exports = { exertion, loadBalance, performance, acwrZone, isFlagged, round, loadSummary };
