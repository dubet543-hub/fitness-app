import React, { useEffect, useId, useMemo, useRef, useState } from 'react';
import { Chart } from 'react-chartjs-2';
import { Icon, downloadCsv } from './ui';
import { chartTheme, STATUS } from '../utils/adminCharts';

// Interactive admin chart.
//  • HTML tooltip — full date first, then every series at that point (value
//    leads, line key, series name).
//  • Crosshair snapping to the nearest point; hover is synced across every
//    chart in the same `group` (e.g. Load history ↔ ACWR trend).
//  • Click (or Enter) opens the chart in a full-screen viewer focused on the
//    clicked point; the viewer's action button runs `onPick(index)`.
//    `selected` draws a band.
//  • Keyboard: focus the chart, ← → / Home / End step through points, Enter
//    picks, Esc clears; the current readout is announced to screen readers.
// Datasets may set `unit` (appended to the value) and `isThreshold` (excluded
// from the tooltip and from sync).

const groups = new Map(); // group id → Set<Chart>

function pointsAt(chart, index) {
  const els = [];
  chart.data.datasets.forEach((ds, di) => {
    if (ds.isThreshold || !chart.isDatasetVisible(di)) return;
    if (ds.data[index] == null) return;
    els.push({ datasetIndex: di, index });
  });
  return els;
}

function activate(chart, index) {
  if (!chart?.ctx) return;
  const els = index == null ? [] : pointsAt(chart, index);
  if (!els.length) {
    chart.setActiveElements([]);
    chart.tooltip?.setActiveElements([], { x: 0, y: 0 });
  } else {
    const el = chart.getDatasetMeta(els[0].datasetIndex).data[index];
    chart.setActiveElements(els);
    chart.tooltip?.setActiveElements(els, { x: el?.x ?? 0, y: el?.y ?? 0 });
  }
  chart.$hoverIndex = index;
  chart.update('none');
  chart.$onHover?.(index);
}

function syncGroup(group, source, index) {
  groups.get(group)?.forEach(ch => { if (ch !== source) activate(ch, index); });
}

// Crosshair, selection band and hover sync.
const interactPlugin = {
  id: 'adminInteract',
  afterEvent(chart, args, opts) {
    const e = args.event;
    if (e.type === 'mousemove') {
      const hit = chart.getElementsAtEventForMode(e, opts.horizontal ? 'nearest' : 'index', { intersect: !!opts.horizontal }, false);
      const idx = hit.length ? hit[0].index : null;
      if (idx !== chart.$hoverIndex) {
        chart.$hoverIndex = idx;
        chart.$onHover?.(idx);
        if (opts.group) syncGroup(opts.group, chart, idx);
      }
      if (opts.cursor === 'zoom-in') chart.canvas.style.cursor = 'zoom-in';
      else if (opts.cursor) chart.canvas.style.cursor = idx != null ? opts.cursor : 'default';
    } else if (e.type === 'mouseout') {
      chart.$hoverIndex = null;
      chart.$onHover?.(null);
      if (opts.group) syncGroup(opts.group, chart, null);
    }
  },
  beforeDatasetsDraw(chart, _args, opts) {
    if (opts.selected == null || opts.horizontal) return;
    const meta = chart.getDatasetMeta(0);
    const el = meta?.data?.[opts.selected];
    if (!el) return;
    const { ctx, chartArea } = chart;
    const n = meta.data.length;
    const w = Math.max(10, (chartArea.right - chartArea.left) / Math.max(n, 1));
    ctx.save();
    ctx.fillStyle = 'rgba(255, 107, 53, 0.12)';
    ctx.fillRect(el.x - w / 2, chartArea.top, w, chartArea.bottom - chartArea.top);
    ctx.restore();
  },
  afterDatasetsDraw(chart, _args, opts) {
    if (opts.horizontal) return;
    const act = chart.getActiveElements?.().length ? chart.getActiveElements() : (chart.tooltip?.getActiveElements?.() || []);
    if (!act.length) return;
    const x = act[0].element.x;
    const { ctx, chartArea } = chart;
    ctx.save();
    ctx.strokeStyle = chartTheme().crosshair;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(Math.round(x) + 0.5, chartArea.top);
    ctx.lineTo(Math.round(x) + 0.5, chartArea.bottom);
    ctx.stroke();
    ctx.restore();
  },
};

const swatchColor = ds => {
  if (ds.tipColor) return ds.tipColor;
  const c = ds.borderColor && typeof ds.borderColor === 'string' && ds.type !== 'bar' ? ds.borderColor : ds.backgroundColor;
  return typeof c === 'string' ? c : '#8E8E93';
};

// Builds the tooltip with DOM APIs (labels can be user data — never innerHTML).
function externalTooltip(titles, unitFor) {
  return ({ chart, tooltip }) => {
    const host = chart.canvas.parentNode;
    let el = host.querySelector(':scope > .chart-tip');
    if (!el) {
      el = document.createElement('div');
      el.className = 'chart-tip';
      el.setAttribute('aria-hidden', 'true');
      host.appendChild(el);
    }
    if (tooltip.opacity === 0 || !tooltip.dataPoints?.length) { el.style.opacity = '0'; return; }

    const idx = tooltip.dataPoints[0].dataIndex;
    el.replaceChildren();
    const head = document.createElement('div');
    head.className = 'chart-tip-title';
    head.textContent = titles?.[idx] ?? tooltip.title?.[0] ?? '';
    el.appendChild(head);
    [...tooltip.dataPoints].sort((a, b) => (a.dataset.tipOrder ?? 5) - (b.dataset.tipOrder ?? 5)).forEach(dp => {
      const ds = dp.dataset;
      if (ds.isThreshold) return;
      const row = document.createElement('div');
      row.className = 'chart-tip-row';
      const key = document.createElement('span');
      key.className = ds.type === 'bar' || chart.config.type === 'bar' && !ds.type ? 'chart-tip-box' : 'chart-tip-line';
      key.style.background = swatchColor(ds);
      const val = document.createElement('span');
      val.className = 'chart-tip-val';
      const raw = chart.options.indexAxis === 'y' ? dp.parsed.x : dp.parsed.y;
      val.textContent = `${Number.isInteger(raw) ? raw : Number(raw).toFixed(raw < 10 ? 2 : 1)}${unitFor(ds)}`;
      const lab = document.createElement('span');
      lab.className = 'chart-tip-lab';
      lab.textContent = ds.label || '';
      row.append(key, val, lab);
      el.appendChild(row);
    });

    const { chartArea } = chart;
    const hostW = host.clientWidth;
    el.style.opacity = '1';
    const tipW = el.offsetWidth;
    let left = tooltip.caretX + 14;
    if (left + tipW > hostW - 4) left = tooltip.caretX - tipW - 14;
    el.style.left = `${Math.max(4, left)}px`;
    el.style.top = `${chart.options.indexAxis === 'y' ? Math.max(0, tooltip.caretY - 20) : chartArea.top}px`;
  };
}

// Paints the canvas background so downloaded PNGs aren't transparent.
const bgPlugin = {
  id: 'viewerBg',
  beforeDraw(chart, _args, opts) {
    if (!opts?.color) return;
    const { ctx, width, height } = chart;
    ctx.save();
    ctx.globalCompositeOperation = 'destination-over';
    ctx.fillStyle = opts.color;
    ctx.fillRect(0, 0, width, height);
    ctx.restore();
  },
};

const unitOf = ds => (ds.unit ? ` ${ds.unit}` : '');
const fmtVal = v => (v == null ? '—' : Number.isInteger(v) ? v.toLocaleString('en-IN') : Number(v).toFixed(Math.abs(v) < 10 ? 2 : 1));

export default function InteractiveChart({
  type = 'line', data, options, group, titles, onPick, pickLabel, selected, label, title, subtitle,
  height = 'h-60', horizontal = false, tooltip = true, onHover, expandable = true,
}) {
  const ref = useRef(null);
  const kbIndex = useRef(null);
  const [announce, setAnnounce] = useState('');
  const [viewer, setViewer] = useState(null); // { index } while the full-screen view is open
  const hintId = useId();
  const n = data.labels?.length || 0;
  const name = title || label || 'Chart';

  // Latest hover callback, called for pointer, keyboard and synced hovers alike.
  useEffect(() => { if (ref.current) ref.current.$onHover = onHover; });

  useEffect(() => {
    const chart = ref.current;
    if (!chart || !group) return undefined;
    if (!groups.has(group)) groups.set(group, new Set());
    groups.get(group).add(chart);
    return () => { groups.get(group)?.delete(chart); };
  }, [group]);

  const open = idx => setViewer({ index: idx ?? selected ?? null });

  const merged = useMemo(() => ({
    ...options,
    onClick: (evt, _els, chart) => {
      const hit = chart.getElementsAtEventForMode(evt, horizontal ? 'nearest' : 'index', { intersect: horizontal }, false);
      const idx = hit.length ? hit[0].index : null;
      if (expandable) open(idx);
      else if (onPick && idx != null) onPick(idx);
    },
    plugins: {
      ...options?.plugins,
      tooltip: { ...options?.plugins?.tooltip, enabled: false, external: tooltip ? externalTooltip(titles, unitOf) : undefined },
      adminInteract: { group, selected, horizontal, cursor: expandable ? 'zoom-in' : onPick ? 'pointer' : null },
    },
  }), [options, onPick, titles, group, selected, horizontal, tooltip, expandable]);

  function readout(i) {
    const chart = ref.current;
    if (!chart) return '';
    const parts = chart.data.datasets
      .filter((ds, di) => !ds.isThreshold && chart.isDatasetVisible(di) && ds.data[i] != null)
      .map(ds => `${ds.label}: ${ds.data[i]}${unitOf(ds)}`);
    return `${titles?.[i] ?? chart.data.labels[i]}. ${parts.join(', ') || 'No data'}.`;
  }

  function step(i) {
    const idx = Math.max(0, Math.min(n - 1, i));
    kbIndex.current = idx;
    activate(ref.current, idx);
    if (group) syncGroup(group, ref.current, idx);
    setAnnounce(readout(idx));
  }

  function onKeyDown(e) {
    if (!n || e.target !== e.currentTarget) return;
    const cur = kbIndex.current ?? (selected ?? n - 1);
    const keys = { ArrowRight: cur + 1, ArrowDown: cur + 1, ArrowLeft: cur - 1, ArrowUp: cur - 1, Home: 0, End: n - 1 };
    if (e.key in keys) { e.preventDefault(); step(keys[e.key]); }
    else if (e.key === 'Enter') {
      e.preventDefault();
      if (expandable) open(kbIndex.current);
      else if (onPick && kbIndex.current != null) onPick(kbIndex.current);
    } else if (e.key === 'Escape') { clear(); }
  }

  function clear() {
    kbIndex.current = null;
    activate(ref.current, null);
    if (group) syncGroup(group, ref.current, null);
  }

  return (
    <>
      <div className={`chart-frame group/chart relative ${height}`} tabIndex={0} role="group"
           aria-label={`${name}${expandable ? ' — press Enter to open it' : ''}`} aria-describedby={hintId}
           onKeyDown={onKeyDown} onFocus={e => { if (e.target === e.currentTarget) step(kbIndex.current ?? (selected ?? n - 1)); }}
           onBlur={e => { if (!e.currentTarget.contains(e.relatedTarget)) clear(); }}>
        <Chart ref={ref} type={type} data={data} options={merged} plugins={[interactPlugin]} />
        {expandable && (
          <button type="button" onClick={() => open(null)} aria-label={`Open ${name} in a larger view`} title="Open chart"
                  className="absolute top-0 right-0 w-11 h-11 sm:w-9 sm:h-9 rounded-md flex items-center justify-center bg-bg/80 border border-bdr text-ts
                             opacity-70 group-hover/chart:opacity-100 focus:opacity-100 hover:text-tp transition-opacity">
            <Icon name="expand" className="w-4 h-4" />
          </button>
        )}
        <span id={hintId} className="sr-only">
          Use the arrow keys to move through points{expandable ? ', Enter to open the chart' : onPick ? ', Enter to open one' : ''}. Values are also listed in the table.
        </span>
        <span className="sr-only" aria-live="polite">{announce}</span>
      </div>
      {viewer && (
        <ChartViewer type={type} data={data} options={options} titles={titles} horizontal={horizontal}
                     initialIndex={viewer.index} onPick={onPick} pickLabel={pickLabel}
                     title={name} subtitle={subtitle} onClose={() => setViewer(null)} />
      )}
    </>
  );
}

// Full-screen view of one chart: bigger plot, selected-point details with the
// chart's action, series toggles, data table, PNG and CSV export.
function ChartViewer({ type, data, options, titles, horizontal, initialIndex, onPick, pickLabel, title, subtitle, onClose }) {
  const ref = useRef(null);
  const closeRef = useRef(null);
  const n = data.labels?.length || 0;
  const [sel, setSel] = useState(initialIndex ?? null);
  const [hidden, setHidden] = useState(() => Object.fromEntries(data.datasets.map((ds, i) => [i, !!ds.hidden])));
  const [showTable, setShowTable] = useState(false);
  const series = data.datasets.map((ds, i) => ({ ds, i })).filter(({ ds }) => !ds.isThreshold)
    .sort((a, b) => (a.ds.tipOrder ?? 5) - (b.ds.tipOrder ?? 5));
  const thresholds = data.datasets.map((ds, i) => ({ ds, i })).filter(({ ds }) => ds.isThreshold);
  const thresholdsOn = thresholds.length ? !hidden[thresholds[0].i] : false;
  const at = i => titles?.[i] ?? data.labels[i];

  useEffect(() => {
    const prev = document.activeElement;
    const overflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    closeRef.current?.focus();
    return () => { document.body.style.overflow = overflow; prev?.focus?.(); };
  }, []);

  // Keys are handled at the document level: clicking the plot (a canvas) drops
  // focus to <body>, and ← → / Esc / Enter must keep working after that.
  const keyRef = useRef(null);
  // Attached on the next tick so the Enter that opened the viewer can't also trigger its action.
  useEffect(() => {
    const h = e => keyRef.current?.(e);
    const t = setTimeout(() => document.addEventListener('keydown', h), 0);
    return () => { clearTimeout(t); document.removeEventListener('keydown', h); };
  }, []);

  const vdata = useMemo(() => ({
    ...data,
    datasets: data.datasets.map((ds, i) => ({
      ...ds,
      hidden: !!hidden[i],
      pointRadius: ds.type === 'bar' ? undefined : (ds.pointRadius ?? 0) || 2.5,
    })),
  }), [data, hidden]);

  const vopts = useMemo(() => {
    const scales = Object.fromEntries(Object.entries(options?.scales || {}).map(([k, v]) => [k, {
      ...v, ticks: { ...v.ticks, font: { size: 12 }, maxTicksLimit: v.ticks?.maxTicksLimit ? Math.max(v.ticks.maxTicksLimit, 12) : undefined },
    }]));
    return {
      ...options,
      maintainAspectRatio: false,
      scales,
      onClick: (evt, _els, chart) => {
        const hit = chart.getElementsAtEventForMode(evt, horizontal ? 'nearest' : 'index', { intersect: horizontal }, false);
        if (hit.length) setSel(hit[0].index);
      },
      plugins: {
        ...options?.plugins,
        tooltip: { ...options?.plugins?.tooltip, enabled: false, external: externalTooltip(titles, unitOf) },
        adminInteract: { selected: sel, horizontal, cursor: 'pointer' },
        viewerBg: { color: chartTheme().canvas },
      },
    };
  }, [options, sel, titles, horizontal]);

  keyRef.current = e => {
    if (e.key === 'Escape') { e.stopPropagation(); onClose(); return; }
    if (['INPUT', 'BUTTON', 'TR', 'A'].includes(e.target.tagName) && (e.key === 'Enter' || e.key === ' ')) return;
    if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
      e.preventDefault();
      setSel(cur => Math.max(0, Math.min(n - 1, (cur ?? n - 1) + (e.key === 'ArrowRight' ? 1 : -1))));
    } else if (e.key === 'Enter' && onPick && sel != null) { e.preventDefault(); act(); }
  };

  function act() { const i = sel; onClose(); onPick(i); }
  const actionText = sel == null ? '' : typeof pickLabel === 'function' ? pickLabel(sel) : (pickLabel || 'Open');
  const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

  function downloadPng() {
    const url = ref.current?.toBase64Image('image/png', 1);
    if (!url) return;
    const a = Object.assign(document.createElement('a'), { href: url, download: `${slug || 'chart'}.png` });
    document.body.appendChild(a); a.click(); a.remove();
  }
  const csvCols = [['Date', i => at(i)], ...series.map(({ ds }) => [`${ds.label}${ds.unit ? ` (${ds.unit})` : ''}`, i => ds.data[i]])];
  const exportCsv = () => downloadCsv(`${slug || 'chart'}.csv`, csvCols, [...Array(n).keys()]);

  return (
    <div className="fixed inset-0 z-50 bg-black/70 flex items-stretch sm:items-center justify-center sm:p-6" onMouseDown={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div role="dialog" aria-modal="true" aria-label={`${title} chart`}
           className="w-full sm:max-w-6xl bg-surface sm:border border-bdr sm:rounded-xl shadow-2xl flex flex-col max-h-dvh sm:max-h-[92vh]">
        {/* Header */}
        <div className="flex items-start gap-3 px-5 sm:px-6 pt-5 pb-4 border-b border-bdr">
          <div className="min-w-0 flex-1">
            <h2 className="display text-[24px] leading-tight text-tp">{title}</h2>
            {subtitle && <p className="text-sm text-ts mt-1">{subtitle}</p>}
          </div>
          <div className="flex items-center gap-1.5 shrink-0">
            <button onClick={downloadPng} className="hidden sm:inline-flex items-center gap-1.5 h-9 px-3 rounded-lg border border-bdr text-xs font-semibold text-tp hover:border-ts/60">
              <Icon name="download" className="w-3.5 h-3.5" /> PNG
            </button>
            <button onClick={exportCsv} className="hidden sm:inline-flex items-center gap-1.5 h-9 px-3 rounded-lg border border-bdr text-xs font-semibold text-tp hover:border-ts/60">
              <Icon name="download" className="w-3.5 h-3.5" /> CSV
            </button>
            <button ref={closeRef} onClick={onClose} aria-label="Close chart" className="w-11 h-11 rounded-lg flex items-center justify-center text-ts hover:text-tp hover:bg-card">
              <Icon name="x" className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="overflow-y-auto px-5 sm:px-6 py-5 space-y-5">
          {/* Series toggles */}
          {(series.length > 1 || thresholds.length > 0) && (
            <LegendToggle items={[
              ...series.map(({ ds, i }) => ({
                key: i, label: ds.label, kind: ds.type === 'bar' || type === 'bar' && !ds.type ? 'box' : 'line',
                color: ds.tipColor || (typeof ds.borderColor === 'string' && ds.type !== 'bar' ? ds.borderColor : typeof ds.backgroundColor === 'string' ? ds.backgroundColor : '#8E8E93'),
                on: !hidden[i], onToggle: series.length > 1 ? () => setHidden(h => ({ ...h, [i]: !h[i] })) : undefined,
              })),
              ...(thresholds.length ? [{ key: 'zones', label: 'Zone lines', kind: 'dash', color: STATUS.good, on: thresholdsOn,
                onToggle: () => setHidden(h => ({ ...h, ...Object.fromEntries(thresholds.map(t => [t.i, thresholdsOn])) })) }] : []),
            ]} />
          )}

          {/* Plot */}
          <div className="chart-frame relative h-[48vh] min-h-[260px]">
            <Chart ref={ref} type={type} data={vdata} options={vopts} plugins={[interactPlugin, bgPlugin]} />
          </div>
          <p className="text-xs text-ts -mt-2">Click a {horizontal ? 'bar' : 'point'} to select it · ← → to step through · Esc to close</p>

          {/* Selected point */}
          <section className="rounded-xl border border-bdr bg-bg p-4" aria-live="polite">
            {sel == null ? (
              <p className="text-sm text-ts">Select a {horizontal ? 'bar' : 'day'} on the chart to see its values{onPick ? ' and open it' : ''}.</p>
            ) : (
              <div className="flex flex-col md:flex-row md:items-center gap-4">
                <div className="min-w-0 flex-1">
                  <div className="label-caps text-accent">Selected</div>
                  <div className="display text-[20px] text-tp mt-0.5">{at(sel)}</div>
                  <div className="flex flex-wrap gap-x-6 gap-y-2 mt-2">
                    {series.filter(({ i }) => !hidden[i]).map(({ ds, i }) => (
                      <div key={i} className="flex items-center gap-2">
                        <span className="w-3 h-[3px] rounded" style={{ background: ds.tipColor || (typeof ds.borderColor === 'string' && ds.type !== 'bar' ? ds.borderColor : ds.backgroundColor) }} />
                        <span className="num text-[22px] text-tp">{fmtVal(ds.data[sel])}{ds.data[sel] != null ? unitOf(ds) : ''}</span>
                        <span className="text-sm text-ts">{ds.label}</span>
                      </div>
                    ))}
                  </div>
                </div>
                <div className="flex flex-wrap gap-2 md:shrink-0">
                  <button onClick={() => setSel(i => Math.max(0, (i ?? 0) - 1))} disabled={sel <= 0} aria-label="Previous"
                          className="w-11 h-11 rounded-lg border border-bdr text-tp flex items-center justify-center disabled:opacity-40 hover:border-ts/60">
                    <Icon name="back" className="w-4 h-4" />
                  </button>
                  <button onClick={() => setSel(i => Math.min(n - 1, (i ?? -1) + 1))} disabled={sel >= n - 1} aria-label="Next"
                          className="w-11 h-11 rounded-lg border border-bdr text-tp flex items-center justify-center disabled:opacity-40 hover:border-ts/60">
                    <Icon name="chevron" className="w-4 h-4" />
                  </button>
                  {onPick && (
                    <button onClick={act} className="flex-1 md:flex-none inline-flex items-center justify-center gap-2 h-11 px-4 rounded-lg bg-accent text-white text-sm font-semibold whitespace-nowrap hover:brightness-110">
                      {actionText} <Icon name="chevron" className="w-4 h-4" />
                    </button>
                  )}
                </div>
              </div>
            )}
          </section>

          {/* Data table */}
          <div>
            <button onClick={() => setShowTable(v => !v)} aria-expanded={showTable}
                    className="inline-flex items-center gap-2 min-h-[44px] text-sm font-semibold text-tp hover:text-accent">
              <Icon name="chevron" className={`w-4 h-4 transition-transform ${showTable ? 'rotate-90' : ''}`} />
              {showTable ? 'Hide' : 'Show'} data table <span className="text-ts font-normal">· {n} rows</span>
            </button>
            {showTable && (
              <div className="mt-2 max-h-[40vh] overflow-auto rounded-lg border border-bdr">
                <table>
                  <thead><tr>{csvCols.map(([h]) => <th key={h}>{h}</th>)}</tr></thead>
                  <tbody>
                    {[...Array(n).keys()].map(i => (
                      <tr key={i} onClick={() => setSel(i)} tabIndex={0} onKeyDown={e => e.key === 'Enter' && setSel(i)}
                          aria-selected={sel === i} className={sel === i ? '!bg-accent/10' : ''}>
                        {csvCols.map(([h, get], c) => <td key={h} className={c === 0 ? 'text-tp whitespace-nowrap' : 'num text-[15px] text-tp'}>{c === 0 ? get(i) : fmtVal(get(i))}</td>)}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
          <div className="flex sm:hidden gap-2">
            <button onClick={downloadPng} className="flex-1 inline-flex items-center justify-center gap-1.5 h-11 rounded-lg border border-bdr text-sm font-semibold text-tp"><Icon name="download" className="w-4 h-4" /> PNG</button>
            <button onClick={exportCsv} className="flex-1 inline-flex items-center justify-center gap-1.5 h-11 rounded-lg border border-bdr text-sm font-semibold text-tp"><Icon name="download" className="w-4 h-4" /> CSV</button>
          </div>
        </div>
      </div>
    </div>
  );
}

// Legend whose items toggle their series. items: [{ key, label, color, kind: 'box'|'line'|'dash', on, onToggle }]
export function LegendToggle({ items }) {
  return (
    <div className="flex gap-1 flex-wrap" role="group" aria-label="Show or hide series">
      {items.map(i => {
        const key = i.kind === 'box'
          ? <span className="w-2.5 h-2.5 rounded-sm" style={{ background: i.on ? i.color : 'transparent', boxShadow: `inset 0 0 0 1.5px ${i.color}` }} />
          : <span className={`w-4 border-t-2 ${i.kind === 'dash' ? 'border-dashed' : ''}`} style={{ borderColor: i.color, opacity: i.on ? 1 : 0.4 }} />;
        if (!i.onToggle) return <span key={i.key} className="inline-flex items-center gap-1.5 px-2 min-h-[44px] sm:min-h-[32px] text-xs text-tp">{key}{i.label}</span>;
        return (
          <button key={i.key} type="button" onClick={i.onToggle} aria-pressed={i.on} title={i.on ? `Hide ${i.label}` : `Show ${i.label}`}
                  className={`inline-flex items-center gap-1.5 px-2 min-h-[44px] sm:min-h-[32px] rounded-md text-xs transition-colors hover:bg-bg ${i.on ? 'text-tp' : 'text-ts/60 line-through'}`}>
            {key}{i.label}
          </button>
        );
      })}
    </div>
  );
}
