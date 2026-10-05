// Admin chart system — one place for series colours, chrome and mark specs so
// every admin chart reads the same way.
//
// Series colours are categorical slots validated for the admin's dark surfaces
// (#161B22 / #1C2333): all pairs pass CVD ΔE ≥ 8 and the normal-vision floor,
// and each clears 3:1 contrast. Colour follows the entity, never the tab or
// rank: load is always slot 1, acute always slot 2, chronic always slot 3.
import './chartDefaults'; // registers Chart.js components

export const SERIES = {
  load:    '#3987e5', // slot 1 · blue
  acute:   '#d95926', // slot 2 · orange
  chronic: '#199e70', // slot 3 · aqua
};
export const SINGLE = SERIES.load; // single-series charts use slot 1

// Reserved status scale — only where the colour *means* a state, and always
// paired with a text label or icon.
export const STATUS = {
  good:     '#0ca30c',
  warning:  '#fab219',
  serious:  '#ec835a',
  critical: '#d03b3b',
  info:     '#60A5FA',
  none:     '#8B949E',
};

const INK = { primary: '#E6EDF3', secondary: '#C9D1D9', muted: '#8B949E' };
const GRID = '#262c36';   // hairline, one step off the card surface
const SURFACE = '#1C2333';

export const wash = hex => `${hex}1A`; // ~10% area fill

// Axis dates drop the year — the card subtitle and tooltips carry the context.
export const shortDate = d => new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' });

const tooltip = {
  backgroundColor: '#0D1117',
  borderColor: '#30363D',
  borderWidth: 1,
  padding: 10,
  boxPadding: 4,
  titleColor: INK.muted,
  titleFont: { size: 11, weight: '500' },
  bodyColor: INK.primary,
  bodyFont: { size: 12, weight: '600' },
  usePointStyle: true, // line keys, not filled boxes
  filter: item => item.raw != null && !item.dataset.isThreshold,
  callbacks: {
    // Value leads, series name follows.
    label: ctx => (ctx.raw == null ? null : ` ${ctx.formattedValue}  ${ctx.dataset.label ?? ''}`),
  },
};

const axis = (extra = {}) => ({
  ticks: { color: INK.muted, font: { size: 10 }, ...extra.ticks },
  grid: { color: GRID, lineWidth: 1, drawTicks: false, ...extra.grid },
  border: { display: false },
  ...extra.rest,
});

export function chartOptions({ yMin, yMax, yTitle, yStep, xTicks = 7, reverse = false, horizontal = false } = {}) {
  const valueAxis = axis({
    ticks: { maxTicksLimit: 7, padding: 6, stepSize: yStep },
    rest: {
      min: yMin, max: yMax, reverse, beginAtZero: yMin == null,
      title: yTitle ? { display: true, text: yTitle, color: INK.muted, font: { size: 10 } } : undefined,
    },
  });
  const categoryAxis = axis({
    ticks: { maxRotation: 0, autoSkip: true, maxTicksLimit: horizontal ? undefined : xTicks, padding: 6 },
    grid: { display: false },
  });
  return {
    responsive: true,
    maintainAspectRatio: false,
    indexAxis: horizontal ? 'y' : 'x',
    interaction: horizontal ? { mode: 'nearest', intersect: true } : { mode: 'index', intersect: false },
    plugins: { legend: { display: false }, tooltip },
    scales: horizontal ? { x: valueAxis, y: categoryAxis } : { x: categoryAxis, y: valueAxis },
  };
}

// 2px line, no resting dots (the crosshair tooltip finds the X), an 8px
// hover dot ringed in the surface colour.
export const lineDataset = (label, data, color, { fill = false, dashed = false, thin = false } = {}) => ({
  type: 'line',
  label,
  data,
  borderColor: color,
  backgroundColor: fill ? wash(color) : color,
  fill,
  borderWidth: thin ? 1 : 2,
  borderDash: dashed ? [4, 4] : undefined,
  borderCapStyle: 'round',
  borderJoinStyle: 'round',
  tension: 0.3,
  cubicInterpolationMode: 'monotone', // no overshoot past real values
  pointRadius: 0,
  pointHitRadius: 12,
  pointHoverRadius: dashed ? 0 : 4,
  pointHoverBackgroundColor: color,
  pointHoverBorderColor: SURFACE,
  pointHoverBorderWidth: 2,
  pointStyle: 'line',
  spanGaps: true,
});

// Bars ≤ 24px, 4px rounded data-end, square at the baseline.
export const barDataset = (label, data, color, { horizontal = false } = {}) => ({
  type: 'bar',
  label,
  data,
  backgroundColor: color,
  hoverBackgroundColor: `${color}CC`,
  borderRadius: 4,
  borderSkipped: horizontal ? 'left' : 'bottom',
  maxBarThickness: 24,
  categoryPercentage: 0.8,
  barPercentage: 0.9,
  pointStyle: 'rect',
});

// A flat reference line (ACWR zone thresholds) — thin, dashed, not hoverable.
export const thresholdDataset = (label, value, n, color) => ({
  ...lineDataset(label, Array(n).fill(value), color, { dashed: true, thin: true }),
  pointHitRadius: 0,
  isThreshold: true,
});
