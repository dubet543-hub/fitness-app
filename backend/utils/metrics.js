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

/** UTC day ordinal (days since epoch) — DST-immune calendar-day key. */
function dayOrdinal(dt) {
  const d = new Date(dt);
  return Math.floor(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) / 86400000);
}

/**
 * ACWR / load summary from a session history (each with `date` and `totalLoad`,
 * any order). Bucketed onto a contiguous per-CALENDAR-DAY grid — one point per
 * day from the first session through `now`, zero-load rest days included and
 * multiple same-day sessions summed — then the acute/chronic/z rolling metrics
 * are stepped once per day. This mirrors the app's day-grid in
 * lib/services/dashboard_metrics.dart exactly, so a coach's dashboard and the
 * athlete's app report the identical ACWR even for athletes with rest days or
 * more than one session per day. (Grid days are keyed in UTC; the app keys in
 * device-local time, so results agree up to the athlete/server timezone offset
 * at a day boundary — full alignment would require storing each athlete's tz.)
 *
 * @param {Array}  sessions  session docs (needs `date`, `totalLoad`)
 * @param {Date}   [now]     grid end (defaults to current server time)
 */
function loadSummary(sessions, now = new Date()) {
  if (!sessions || !sessions.length) {
    return { acuteLoad: 0, chronicLoad: 0, acwr: 0, stdDev: 0, zScore: 0,
             targetLow: 0, targetHigh: 0, totalSessions: 0 };
  }

  // Contiguous day grid: first session day → today (inclusive).
  const firstOrd = Math.min(...sessions.map(s => dayOrdinal(s.date)));
  const lastOrd  = Math.max(firstOrd, dayOrdinal(now));
  const dayCount = lastOrd - firstOrd + 1;

  const loads = new Array(dayCount).fill(0);
  for (const s of sessions) {
    const i = dayOrdinal(s.date) - firstOrd;
    if (i >= 0 && i < dayCount) loads[i] += s.totalLoad || 0;
  }

  const lambda = 2 / 29;
  let chronic = 0;
  let acuteLoad = 0, chronicLoad = 0, acwr = 0, sigma = 0, zScore = 0;
  let sum = 0, sumSq = 0; // running population variance of day loads

  for (let i = 0; i < dayCount; i++) {
    const load = loads[i];

    let acuteSum = 0;
    for (let j = Math.max(0, i - 6); j <= i; j++) acuteSum += loads[j];
    const acute = acuteSum / 7; // trailing 7-calendar-day average

    chronic = i === 0 ? acute : acute * lambda + chronic * (1 - lambda);

    sum += load;
    sumSq += load * load;
    const n = i + 1;
    const mean = sum / n;
    const variance = Math.max(0, sumSq / n - mean * mean);
    sigma = Math.sqrt(variance);

    acuteLoad   = acute;
    chronicLoad = chronic;
    acwr        = chronicLoad > 0 ? acuteLoad / chronicLoad : 0;
    zScore      = sigma === 0 ? 0 : (load - chronicLoad) / sigma;
  }

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
