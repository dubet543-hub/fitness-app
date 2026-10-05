// Admin chart system — one place for series colours, chrome and mark specs so
// every admin chart reads the same way, in both the dark and light themes.
//
// Every palette below is validated with the dataviz skill's checker against
// the surface it renders on:
//  • Series: categorical slots 1–3, all pairs pass CVD ΔE ≥ 8 and the
//    normal-vision floor in each mode. (Light aqua sits at 2.8:1 on white —
//    allowed because every chart has a legend, tooltips and a table view.)
//  • Load ramp: one hue, monotone lightness, visible steps, low end ≥ 2:1.
//  • Status: text-grade contrast (≥ 4.5:1) on light; always icon + label.
// Colour follows the entity, never the tab or rank: load is always slot 1,
// acute always slot 2, chronic always slot 3.
import './chartDefaults'; // registers Chart.js components

const PALETTES = {
  dark: {
    series: { load: '#3987e5', acute: '#d95926', chronic: '#199e70' },
    // dim → bright: brighter means heavier on a dark surface
    ramp: ['#7a371a', '#9e451d', '#c05221', '#e06025', '#ff7a3d', '#ffa776'],
    status: { good: '#0ca30c', warning: '#fab219', serious: '#ec835a', critical: '#d03b3b', info: '#60A5FA', none: '#8B949E' },
    ink: { primary: '#E6EDF3', muted: '#8B949E' },
    grid: '#262c36',
    surface: '#18181B',
    crosshair: 'rgba(237, 237, 239, 0.28)',
    canvas: '#111113',
  },
  light: {
    series: { load: '#2a78d6', acute: '#eb6834', chronic: '#1baf7a' },
    // light → dark: darker means heavier on a light surface
    ramp: ['#ee9c66', '#e07a41', '#cc5f25', '#a94c1a', '#843b14', '#5e2a0e'],
    status: { good: '#15803D', warning: '#A16207', serious: '#B54708', critical: '#B91C1C', info: '#1D4ED8', none: '#6B6B72' },
    ink: { primary: '#16161A', muted: '#6B6B72' },
    grid: '#EBEBE7',
    surface: '#FFFFFF',
    crosshair: 'rgba(22, 22, 26, 0.25)',
    canvas: '#FFFFFF',
  },
};

// The admin shell sets the resolved theme before its children render, so every
// chart and colour lookup below reads the current palette.
let THEME = 'dark';
export const setChartTheme = t => { THEME = t === 'light' ? 'light' : 'dark'; };
export const chartTheme = () => PALETTES[THEME];
export const themeName = () => THEME;

const live = section => new Proxy({}, { get: (_, k) => PALETTES[THEME][section][k], ownKeys: () => Object.keys(PALETTES[THEME][section]), getOwnPropertyDescriptor: () => ({ enumerable: true, configurable: true }) });

export const SERIES = live('series');
// Reserved status scale — only where the colour *means* a state, and always
// paired with a text label or icon.
export const STATUS = live('status');
export const loadRamp = () => PALETTES[THEME].ramp;

export const wash = hex => `${hex}1A`; // ~10% area fill

// Axis dates drop the year — the card subtitle and tooltips carry the context.
export const shortDate = d => new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' });

const axis = (extra = {}) => ({
  ticks: { color: chartTheme().ink.muted, font: { size: 10 }, ...extra.ticks },
  grid: { color: chartTheme().grid, lineWidth: 1, drawTicks: false, ...extra.grid },
  border: { display: false },
  ...extra.rest,
});

export function chartOptions({ yMin, yMax, yTitle, yStep, xTicks = 7, reverse = false, horizontal = false } = {}) {
  const valueAxis = axis({
    ticks: { maxTicksLimit: 7, padding: 6, stepSize: yStep },
    rest: {
      min: yMin, max: yMax, reverse, beginAtZero: yMin == null,
      title: yTitle ? { display: true, text: yTitle, color: chartTheme().ink.muted, font: { size: 10 } } : undefined,
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
    plugins: { legend: { display: false } },
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
  pointHoverBorderColor: chartTheme().surface,
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
