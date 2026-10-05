import React, { useEffect, useId, useMemo, useRef, useState } from 'react';
import { Chart } from 'react-chartjs-2';

// Interactive admin chart.
//  • HTML tooltip — full date first, then every series at that point (value
//    leads, line key, series name).
//  • Crosshair snapping to the nearest point; hover is synced across every
//    chart in the same `group` (e.g. Load history ↔ ACWR trend).
//  • Click / Enter picks a point (`onPick(index)`); `selected` draws a band.
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
      if (opts.pickable) chart.canvas.style.cursor = idx != null ? 'pointer' : 'default';
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
    ctx.strokeStyle = 'rgba(237, 237, 239, 0.28)';
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

export default function InteractiveChart({
  type = 'line', data, options, group, titles, onPick, selected, label, height = 'h-60', horizontal = false,
  tooltip = true, onHover,
}) {
  const ref = useRef(null);
  const kbIndex = useRef(null);
  const [announce, setAnnounce] = useState('');
  const hintId = useId();
  const n = data.labels?.length || 0;

  // Latest hover callback, called for pointer, keyboard and synced hovers alike.
  useEffect(() => { if (ref.current) ref.current.$onHover = onHover; });

  useEffect(() => {
    const chart = ref.current;
    if (!chart || !group) return undefined;
    if (!groups.has(group)) groups.set(group, new Set());
    groups.get(group).add(chart);
    return () => { groups.get(group)?.delete(chart); };
  }, [group]);

  const unitFor = ds => (ds.unit ? ` ${ds.unit}` : '');

  const merged = useMemo(() => ({
    ...options,
    onClick: onPick
      ? (evt, _els, chart) => {
          const hit = chart.getElementsAtEventForMode(evt, horizontal ? 'nearest' : 'index', { intersect: horizontal }, false);
          if (hit.length) onPick(hit[0].index);
        }
      : undefined,
    plugins: {
      ...options?.plugins,
      tooltip: { ...options?.plugins?.tooltip, enabled: false, external: tooltip ? externalTooltip(titles, unitFor) : undefined },
      adminInteract: { group, selected, pickable: !!onPick, horizontal },
    },
  }), [options, onPick, titles, group, selected, horizontal, tooltip]);

  function readout(i) {
    const chart = ref.current;
    if (!chart) return '';
    const parts = chart.data.datasets
      .filter((ds, di) => !ds.isThreshold && chart.isDatasetVisible(di) && ds.data[i] != null)
      .map(ds => `${ds.label}: ${ds.data[i]}${unitFor(ds)}`);
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
    if (!n) return;
    const cur = kbIndex.current ?? (selected ?? n - 1);
    const keys = { ArrowRight: cur + 1, ArrowDown: cur + 1, ArrowLeft: cur - 1, ArrowUp: cur - 1, Home: 0, End: n - 1 };
    if (e.key in keys) { e.preventDefault(); step(keys[e.key]); }
    else if (e.key === 'Enter' && onPick && kbIndex.current != null) { e.preventDefault(); onPick(kbIndex.current); }
    else if (e.key === 'Escape') { clear(); }
  }

  function clear() {
    kbIndex.current = null;
    activate(ref.current, null);
    if (group) syncGroup(group, ref.current, null);
  }

  return (
    <div className={`chart-frame relative ${height}`} tabIndex={0} role="group"
         aria-label={label} aria-describedby={hintId}
         onKeyDown={onKeyDown} onFocus={() => step(kbIndex.current ?? (selected ?? n - 1))} onBlur={clear}>
      <Chart ref={ref} type={type} data={data} options={merged} plugins={[interactPlugin]} />
      <span id={hintId} className="sr-only">
        Use the arrow keys to move through points{onPick ? ', Enter to open one' : ''}. Values are also listed in the table.
      </span>
      <span className="sr-only" aria-live="polite">{announce}</span>
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
