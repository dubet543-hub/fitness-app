export function computeRollingACWR(sessions) {
  const sorted = [...sessions].sort((a, b) => new Date(a.date) - new Date(b.date));
  if (!sorted.length) return [];
  const lambda = 2 / 29;
  let ewma = sorted[0].totalLoad || 0;
  return sorted.map((s, i) => {
    if (i > 0) ewma = (s.totalLoad || 0) * lambda + ewma * (1 - lambda);
    const cutoff = new Date(s.date); cutoff.setDate(cutoff.getDate() - 6);
    const acute = sorted.slice(0, i + 1)
      .filter(x => new Date(x.date) >= cutoff)
      .reduce((sum, x) => sum + (x.totalLoad || 0), 0);
    return { date: s.date, acwr: ewma > 0 ? Math.round((acute / ewma) * 100) / 100 : 0 };
  });
}

export function computeStats(sessions) {
  if (!sessions.length) return { acuteLoad: 0, chronicLoad: 0, acwr: 0, lastReadiness: null };
  const sorted = [...sessions].sort((a, b) => new Date(a.date) - new Date(b.date));
  const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 7);
  const acute = sessions.filter(s => new Date(s.date) >= cutoff).reduce((sum, s) => sum + (s.totalLoad || 0), 0);
  const lambda = 2 / 29;
  let ewma = sorted[0].totalLoad || 0;
  for (let i = 1; i < sorted.length; i++) ewma = (sorted[i].totalLoad || 0) * lambda + ewma * (1 - lambda);
  return {
    acuteLoad:    Math.round(acute),
    chronicLoad:  Math.round(ewma * 10) / 10,
    acwr:         ewma > 0 ? Math.round((acute / ewma) * 100) / 100 : 0,
    lastReadiness: sorted[sorted.length - 1]?.readinessPercent ?? null,
  };
}
