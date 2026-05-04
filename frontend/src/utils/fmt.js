export const fmtDate = (d) =>
  d ? new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';

export const fmtNum = (n, dec = 0) =>
  n != null ? Number(n).toFixed(dec) : '—';
