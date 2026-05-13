const EWMA_LAMBDA = 2 / 29;

export function num(value) {
  return Number(value) || 0;
}

export function dayKey(date) {
  const dt = new Date(date);
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}`;
}

export function sessionTrainingLoad(s) {
  const stored = num(s.primaryLoad) + num(s.secondaryLoad);
  if (stored > 0) return stored;
  return (num(s.primaryDuration) * num(s.primaryRpe))
    + (s.hasSecondary ? num(s.secondaryDuration) * num(s.secondaryRpe) : 0);
}

export function sessionSkillLoad(s) {
  const stored = num(s.skillLoad);
  if (stored > 0) return stored;
  return (num(s.skillDuration) * num(s.skillRpe))
    + (num(s.skillSubDuration) * num(s.skillSubRpe));
}

export function buildDailyRecords(sessions) {
  const byDay = new Map();
  sessions.forEach(s => {
    const key = dayKey(s.date);
    const rec = byDay.get(key) || {
      date: s.date,
      trainingLoad: 0,
      skillLoad: 0,
      totalLoad: 0,
      readinessPercent: null,
    };
    const trainingLoad = sessionTrainingLoad(s);
    const skillLoad = sessionSkillLoad(s);
    rec.trainingLoad += trainingLoad;
    rec.skillLoad += skillLoad;
    rec.totalLoad += trainingLoad + skillLoad;
    if (s.readinessPercent != null) rec.readinessPercent = s.readinessPercent;
    byDay.set(key, rec);
  });
  return [...byDay.values()].sort((a, b) => new Date(a.date) - new Date(b.date));
}

export function scaledGrade(load) {
  return load <= 0 ? 0 : (Math.log(load) / Math.log(1000)) * 10;
}

export function buildFlutterSeries(records, getLoad) {
  if (!records.length) return [];
  let chronic = 0;
  const runningLoads = [];

  return records.map((record, i) => {
    const load = getLoad(record);
    runningLoads.push(load);

    // Acute = 7-day rolling average (sum / 7)
    const cutoff = new Date(record.date);
    cutoff.setDate(cutoff.getDate() - 7);
    const sum7 = records
      .slice(0, i + 1)
      .filter(r => new Date(r.date) > cutoff)
      .reduce((sum, r) => sum + getLoad(r), 0);
    const acute = sum7 / 7;

    // Chronic = EWMA of acute values (not raw loads)
    chronic = i === 0 ? acute : (acute * EWMA_LAMBDA) + (chronic * (1 - EWMA_LAMBDA));

    // Running population std dev of all loads so far
    const n = runningLoads.length;
    const mean = runningLoads.reduce((a, b) => a + b, 0) / n;
    const sigma = n > 1
      ? Math.sqrt(runningLoads.map(l => Math.pow(l - mean, 2)).reduce((a, b) => a + b, 0) / n)
      : 0;

    const zScore = sigma === 0 ? 0 : (load - chronic) / sigma;

    return {
      date: record.date,
      load,
      acute,
      chronic,
      acwr: chronic === 0 ? 0 : acute / chronic,
      exertion: scaledGrade(load),
      zScore,
      targetLow: Math.round(chronic * 0.8),
      targetHigh: Math.round(chronic * 1.3),
      readinessPercent: record.readinessPercent,
    };
  });
}

export function computeRollingACWR(sessions) {
  const records = buildDailyRecords(sessions);
  return buildFlutterSeries(records, r => r.totalLoad).map(d => ({
    date: d.date,
    acwr: Math.round(d.acwr * 100) / 100,
  }));
}

export function computeStats(sessions) {
  const records = buildDailyRecords(sessions);
  if (!records.length) return {
    acuteLoad: 0, chronicLoad: 0, acwr: 0,
    lastReadiness: null, zScore: 0, stdDev: 0,
    targetLow: 0, targetHigh: 0,
  };

  // Per-record 7-day acute averages
  const acuteByIdx = records.map((rec, i) => {
    const cutoff = new Date(rec.date);
    cutoff.setDate(cutoff.getDate() - 7);
    const sum7 = records.slice(0, i + 1)
      .filter(r => new Date(r.date) > cutoff)
      .reduce((s, r) => s + r.totalLoad, 0);
    return sum7 / 7;
  });

  // Chronic = EWMA of acute values
  let chronic = 0;
  for (let i = 0; i < acuteByIdx.length; i++) {
    chronic = i === 0 ? acuteByIdx[i] : (acuteByIdx[i] * EWMA_LAMBDA) + (chronic * (1 - EWMA_LAMBDA));
  }
  const acute = acuteByIdx[acuteByIdx.length - 1];

  const loads = records.map(r => r.totalLoad);
  const mean = loads.reduce((a, b) => a + b, 0) / loads.length;
  const sigma = Math.sqrt(loads.map(l => Math.pow(l - mean, 2)).reduce((a, b) => a + b, 0) / loads.length);
  const lastLoad = records[records.length - 1].totalLoad;

  const zScore = sigma === 0 ? 0 : (lastLoad - chronic) / sigma;

  return {
    acuteLoad: Math.round(acute * 10) / 10,
    chronicLoad: Math.round(chronic * 10) / 10,
    acwr: chronic > 0 ? Math.round((acute / chronic) * 100) / 100 : 0,
    lastReadiness: records[records.length - 1]?.readinessPercent ?? null,
    zScore: Math.round(zScore * 100) / 100,
    stdDev: Math.round(sigma * 10) / 10,
    targetLow: Math.round(chronic * 0.8),
    targetHigh: Math.round(chronic * 1.3),
  };
}
