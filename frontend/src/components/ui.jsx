import React, { createContext, useCallback, useContext, useMemo, useRef, useState } from 'react';

// Shared admin UI primitives — one icon set, one card, one button system, so
// every section looks and behaves the same.

const ICONS = {
  users:    'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  list:     'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01',
  chart:    'M3 3v18h18M7 16l4-4 4 4 5-6',
  moon:     'M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z',
  card:     'M2 7a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2zM2 10h20',
  userPlus: 'M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M8.5 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM20 8v6M23 11h-6',
  menu:     'M3 6h18M3 12h18M3 18h18',
  download: 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3',
  search:   'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM21 21l-4.35-4.35',
  back:     'M19 12H5M12 19l-7-7 7-7',
  chevron:  'M9 18l6-6-6-6',
  x:        'M18 6 6 18M6 6l12 12',
  alert:    'M12 9v4M12 17h.01M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z',
  eye:      'M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  eyeOff:   'M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19M1 1l22 22M14.12 14.12a3 3 0 1 1-4.24-4.24',
  check:    'M20 6 9 17l-5-5',
  target:   'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  body:     'M12 5a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM6 8h12M12 8v7M9 22l3-7 3 7',
  refresh:  'M23 4v6h-6M1 20v-6h6M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15',
  expand:   'M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7',
  sun:      'M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42',
  monitor:  'M4 4h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM8 21h8M12 16v5',
  arrowUp:  'M12 19V5M5 12l7-7 7 7',
  arrowDown:'M12 5v14M19 12l-7 7-7-7',
  sort:     'M7 15l5 5 5-5M7 9l5-5 5 5',
  info:     'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM12 16v-4M12 8h.01',
  logout:   'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9',
  activity: 'M22 12h-4l-3 9L9 3l-3 9H2',
  heart:    'M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z',
  calendar: 'M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z',
};

export function Icon({ name, className = 'w-4 h-4', strokeWidth = 2 }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor"
         strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={ICONS[name]} />
    </svg>
  );
}

const BTN = {
  primary:   'bg-accent text-white hover:brightness-110 border border-accent',
  secondary: 'bg-card text-tp border border-bdr hover:border-ts/60',
  ghost:     'text-ts hover:text-tp hover:bg-card border border-transparent',
  danger:    'text-[rgb(var(--c-danger))] border border-red-500/40 hover:bg-red-500/10',
};

export function Button({ variant = 'secondary', icon, children, className = '', ...props }) {
  return (
    <button
      type="button"
      {...props}
      className={`inline-flex items-center justify-center gap-1.5 rounded-lg px-3.5 h-11 sm:h-9 text-xs font-semibold
        transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${BTN[variant]} ${className}`}
    >
      {icon && <Icon name={icon} className="w-3.5 h-3.5" />}
      {children}
    </button>
  );
}

export function PageHeader({ title, subtitle, actions, eyebrow }) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 pb-5 border-b border-bdr">
      <div>
        {eyebrow && <div className="text-sm text-ts mb-1">{eyebrow}</div>}
        <h1 className="display text-[40px] leading-none text-tp">{title}</h1>
        {subtitle && <p className="text-sm text-ts mt-2 max-w-2xl">{subtitle}</p>}
      </div>
      {actions && <div className="flex gap-2 flex-wrap">{actions}</div>}
    </div>
  );
}

export function Card({ title, subtitle, actions, children, className = '', bodyClassName = 'p-5' }) {
  return (
    <section className={`card rounded-xl ${className}`}>
      {(title || actions) && (
        <div className="flex items-start justify-between gap-3 px-5 pt-4 pb-3.5 border-b border-bdr">
          <div className="min-w-0">
            {title && <h2 className="display text-[19px] leading-tight text-tp">{title}</h2>}
            {subtitle && <p className="text-xs text-ts mt-0.5">{subtitle}</p>}
          </div>
          {actions}
        </div>
      )}
      <div className={bodyClassName}>{children}</div>
    </section>
  );
}

// Toolbar of labelled filter controls; children are <Field>s and buttons.
export function FilterBar({ children }) {
  return (
    <div className="card rounded-xl p-4 flex flex-wrap items-end gap-3">
      {children}
    </div>
  );
}

export function Field({ label, htmlFor, children, className = '' }) {
  return (
    <div className={`flex flex-col gap-1.5 ${className}`}>
      <label htmlFor={htmlFor} className="text-xs font-medium text-ts uppercase tracking-wider">{label}</label>
      {children}
    </div>
  );
}

export function AthleteSelect({ id, athletes, value, onChange, allLabel }) {
  return (
    <select id={id} value={value} onChange={e => onChange(e.target.value)} className="!w-auto min-w-[220px] h-11 sm:h-9">
      {allLabel !== undefined
        ? <option value="">{allLabel}</option>
        : <option value="" disabled>Select an athlete…</option>}
      {athletes.map(a => (
        <option key={a._id} value={a._id}>
          {a.name}{a.sport ? ` · ${a.sport}` : ''}{a.active === false ? ' (inactive)' : ''}
        </option>
      ))}
    </select>
  );
}

export function Avatar({ name, size = 'w-8 h-8 text-xs' }) {
  const initials = (name || '?').split(/\s+/).filter(Boolean).slice(0, 2).map(s => s[0].toUpperCase()).join('');
  return (
    <span className={`${size} shrink-0 rounded-full bg-card text-tp ring-1 ring-bdr font-semibold inline-flex items-center justify-center`}>
      {initials}
    </span>
  );
}

export function EmptyState({ icon = 'chart', title, hint, action }) {
  return (
    <div className="py-14 px-6 flex flex-col items-center text-center">
      <span className="w-12 h-12 rounded-full card-inset flex items-center justify-center text-ts mb-3">
        <Icon name={icon} className="w-5 h-5" />
      </span>
      <div className="text-sm font-semibold text-tp">{title}</div>
      {hint && <div className="text-xs text-ts mt-1 max-w-sm">{hint}</div>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

export function ErrorBanner({ message, onRetry }) {
  if (!message) return null;
  return (
    <div role="alert" className="flex items-center gap-3 bg-red-500/10 border border-red-500/40 rounded-xl px-4 py-3 text-sm text-[rgb(var(--c-danger))]">
      <Icon name="alert" className="w-4 h-4 shrink-0" />
      <span className="flex-1">{message}</span>
      {onRetry && <Button variant="danger" icon="refresh" onClick={onRetry}>Retry</Button>}
    </div>
  );
}

export function Skeleton({ className = 'h-4 w-full' }) {
  return <div className={`animate-pulse motion-reduce:animate-none rounded-lg bg-card ${className}`} />;
}

export function TableSkeleton({ rows = 5 }) {
  return (
    <div className="p-5 space-y-3" aria-busy="true" aria-label="Loading">
      {Array.from({ length: rows }).map((_, i) => <Skeleton key={i} className="h-8 w-full" />)}
    </div>
  );
}

// Stat tile. The number stays in ink (text never wears the data colour); the
// colour rides a key mark beside the label. When the value *means* a state,
// pass `status` so it shows as icon + word, never colour alone.
export function Metric({ label, value, sub, color, status }) {
  return (
    <div className="rounded-xl p-3.5 min-w-0 card-inset">
      <div className="flex items-center gap-1.5 text-xs text-ts">
        {color && <span className="w-2 h-2 rounded-sm shrink-0" style={{ background: color }} aria-hidden="true" />}
        <span className="truncate">{label}</span>
      </div>
      <div className="num text-[26px] text-tp leading-none mt-2 truncate">{value}</div>
      {status ? (
        <div className="flex items-center gap-1 text-xs font-semibold mt-0.5 truncate" style={{ color: status.color }}>
          <Icon name={status.icon || 'info'} className="w-3 h-3 shrink-0" />
          <span className="truncate">{status.label}</span>
        </div>
      ) : sub && <div className="text-xs text-ts mt-0.5 truncate">{sub}</div>}
    </div>
  );
}

// Status shown as dot + value + word, for table cells.
export function StatusValue({ value, status }) {
  return (
    <span className="inline-flex items-center gap-1.5 whitespace-nowrap">
      <span className="w-2 h-2 rounded-full shrink-0" style={{ background: status.color }} aria-hidden="true" />
      <span className="text-tp">{value}</span>
      <span className="text-xs text-ts">{status.short || status.label}</span>
    </span>
  );
}

// ── Sortable tables ───────────────────────────────────────────────────────────
// useSort(rows, { key: row => value }, initialKey, initialDir)
export function useSort(rows, accessors, initialKey, initialDir = 'desc') {
  const [sort, setSort] = useState({ key: initialKey, dir: initialDir });
  const sorted = useMemo(() => {
    const get = accessors[sort.key];
    if (!get) return rows;
    const mul = sort.dir === 'asc' ? 1 : -1;
    return [...rows].sort((a, b) => {
      const va = get(a), vb = get(b);
      if (va == null && vb == null) return 0;
      if (va == null) return 1;            // blanks always last
      if (vb == null) return -1;
      return (typeof va === 'string' ? va.localeCompare(vb) : va - vb) * mul;
    });
  }, [rows, sort, accessors]);
  const toggle = key => setSort(s => ({ key, dir: s.key === key && s.dir === 'desc' ? 'asc' : s.key === key ? 'desc' : (key === 'name' ? 'asc' : 'desc') }));
  return { sorted, sort, toggle };
}

export function SortTh({ label, sortKey, sort, onSort, className = '' }) {
  if (!sortKey) return <th className={className}>{label}</th>;
  const active = sort.key === sortKey;
  return (
    <th className={className} aria-sort={active ? (sort.dir === 'asc' ? 'ascending' : 'descending') : 'none'}>
      <button type="button" onClick={() => onSort(sortKey)}
              className={`inline-flex items-center gap-1 whitespace-nowrap hover:text-tp transition-colors ${active ? 'text-tp' : ''}`}>
        {label}
        <Icon name={active ? (sort.dir === 'asc' ? 'arrowUp' : 'arrowDown') : 'sort'} className={`w-3 h-3 ${active ? '' : 'opacity-40'}`} />
      </button>
    </th>
  );
}

// ── Toasts ────────────────────────────────────────────────────────────────────
// Brief confirmation of an action; polite live region, never steals focus,
// auto-dismisses after 4s.
const ToastCtx = createContext(() => {});
export const useToast = () => useContext(ToastCtx);

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const nextId = useRef(0);
  const notify = useCallback((message, tone = 'success') => {
    const id = ++nextId.current;
    setToasts(t => [...t, { id, message, tone }]);
    setTimeout(() => setToasts(t => t.filter(x => x.id !== id)), 4000);
  }, []);
  return (
    <ToastCtx.Provider value={notify}>
      {children}
      <div aria-live="polite" className="fixed bottom-4 right-4 left-4 sm:left-auto z-50 flex flex-col gap-2 items-end pointer-events-none">
        {toasts.map(t => (
          <div key={t.id} role="status"
               className="pointer-events-auto flex items-center gap-2.5 bg-card border border-bdr shadow-2xl rounded-lg pl-3 pr-4 py-3 text-sm text-tp max-w-sm">
            <span className={t.tone === 'error' ? 'text-[rgb(var(--c-danger))]' : 'text-[rgb(var(--c-success))]'}>
              <Icon name={t.tone === 'error' ? 'alert' : 'check'} />
            </span>
            {t.message}
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
}

// ── CSV export ────────────────────────────────────────────────────────────────
// columns: [[header, row => value], ...]
export function downloadCsv(filename, columns, rows) {
  const esc = v => {
    const str = v == null ? '' : String(v);
    return /[",\n]/.test(str) ? `"${str.replace(/"/g, '""')}"` : str;
  };
  const csv = [columns.map(([h]) => esc(h)).join(','), ...rows.map(r => columns.map(([, get]) => esc(get(r))).join(','))].join('\r\n');
  const url = URL.createObjectURL(new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' }));
  const a = Object.assign(document.createElement('a'), { href: url, download: filename });
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

// Status as a dot + word — colour never carries the meaning alone.
export function ConditionChip({ condition, size = 'sm' }) {
  if (!condition) return null;
  return (
    <span className={`inline-flex items-center gap-1.5 font-semibold whitespace-nowrap ${size === 'lg' ? 'text-sm' : 'text-[13px]'}`}
          style={{ color: condition.color }}>
      <span className={`${size === 'lg' ? 'w-2.5 h-2.5' : 'w-2 h-2'} rounded-full shrink-0`} style={{ background: condition.color }} aria-hidden="true" />
      {condition.label}
    </span>
  );
}

// Tiny trend line for table rows; the last point is marked. Hover (or focus +
// arrow keys) reads out each day's value.
export function Sparkline({ values, dates, unit = '', width = 96, height = 28, color = 'rgb(var(--c-ts))', label }) {
  const [hi, setHi] = useState(null);
  const pts = values.map(v => (v == null ? 0 : v));
  if (pts.length < 2 || pts.every(v => v === 0)) {
    return <span className="text-xs text-ts">—</span>;
  }
  const max = Math.max(...pts, 1);
  const step = width / (pts.length - 1);
  const y = v => height - 3 - (v / max) * (height - 6);
  const d = pts.map((v, i) => `${i ? 'L' : 'M'}${(i * step).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
  const idx = hi ?? pts.length - 1;
  const fmtD = dt => (dt ? new Date(dt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' }) : '');
  const onMove = e => {
    const r = e.currentTarget.getBoundingClientRect();
    setHi(Math.max(0, Math.min(pts.length - 1, Math.round(((e.clientX - r.left) / r.width) * (pts.length - 1)))));
  };
  return (
    <span className="relative inline-block align-middle" onMouseLeave={() => setHi(null)}>
      <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} className="overflow-visible block" onMouseMove={onMove}
           tabIndex={0} role="img" aria-label={label}
           onFocus={() => setHi(pts.length - 1)} onBlur={() => setHi(null)}
           onKeyDown={e => {
             if (e.key === 'ArrowLeft') { e.preventDefault(); setHi(Math.max(0, idx - 1)); }
             if (e.key === 'ArrowRight') { e.preventDefault(); setHi(Math.min(pts.length - 1, idx + 1)); }
           }}>
        <path d={`${d} L${(pts.length - 1) * step},${height} L0,${height} Z`} fill={color} opacity="0.08" />
        <path d={d} fill="none" stroke={color} strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" />
        {hi != null && <line x1={idx * step} x2={idx * step} y1="0" y2={height} stroke="rgb(var(--c-tp))" strokeOpacity="0.3" />}
        <circle cx={idx * step} cy={y(pts[idx])} r={hi != null ? 3.5 : 2.5} fill={color} stroke="rgb(var(--c-surface))" strokeWidth={hi != null ? 2 : 0} />
      </svg>
      {hi != null && (
        <span className="absolute z-10 -top-8 -translate-x-1/2 whitespace-nowrap rounded-md border border-bdr bg-bg px-2 py-1 text-[11px] text-tp pointer-events-none"
              style={{ left: Math.min(Math.max(idx * step, 30), width - 10) }} role="status">
          <span className="text-ts">{fmtD(dates?.[idx])}</span> <span className="font-semibold">{pts[idx] ? `${Math.round(pts[idx])}${unit ? ` ${unit}` : ''}` : 'rest'}</span>
        </span>
      )}
    </span>
  );
}

// Progress ring (0–100) with the value in the middle.
export function Ring({ value, size = 132, stroke = 10, color = 'rgb(var(--c-accent))', caption }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const pct = value == null ? 0 : Math.max(0, Math.min(100, value));
  return (
    <div className="relative shrink-0" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90" aria-hidden="true">
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="rgb(var(--c-card))" strokeWidth={stroke} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round"
                strokeDasharray={c} strokeDashoffset={c * (1 - pct / 100)} style={{ transition: 'stroke-dashoffset .6s ease-out' }} />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="num text-[38px] leading-none text-tp">{value == null ? '—' : Math.round(value)}<span className="text-lg text-ts">{value == null ? '' : '%'}</span></span>
        {caption && <span className="label-caps mt-1">{caption}</span>}
      </div>
    </div>
  );
}

// ── Form controls ─────────────────────────────────────────────────────────────
// Checkbox row: box and label always aligned on one line, whole row clickable.
export function Checkbox({ checked, onChange, label, hint, disabled }) {
  return (
    <label className={`flex items-start gap-3 py-1.5 min-h-[36px] ${disabled ? 'opacity-50' : 'cursor-pointer'}`}>
      <input type="checkbox" className="peer sr-only" checked={checked} disabled={disabled}
             onChange={e => onChange(e.target.checked)} />
      <span aria-hidden="true"
            className={`mt-0.5 w-[18px] h-[18px] shrink-0 rounded-[5px] border flex items-center justify-center transition-colors
              peer-focus-visible:ring-2 peer-focus-visible:ring-accent peer-focus-visible:ring-offset-2 peer-focus-visible:ring-offset-bg
              ${checked ? 'bg-accent border-accent text-white' : 'border-[rgb(var(--c-bdr-strong))] bg-bg'}`}>
        {checked && <Icon name="check" className="w-3 h-3" strokeWidth={3} />}
      </span>
      <span className="min-w-0">
        <span className="block text-sm text-tp leading-snug">{label}</span>
        {hint && <span className="block text-xs text-ts mt-0.5">{hint}</span>}
      </span>
    </label>
  );
}

// On/off switch with its label to the left.
export function Switch({ checked, onChange, label }) {
  return (
    <label className="inline-flex items-center gap-3 cursor-pointer min-h-[36px]">
      <span className="text-sm text-ts">{label}</span>
      <input type="checkbox" role="switch" className="peer sr-only" checked={checked} onChange={e => onChange(e.target.checked)} />
      <span aria-hidden="true"
            className={`relative w-10 h-6 rounded-full transition-colors peer-focus-visible:ring-2 peer-focus-visible:ring-accent
              ${checked ? 'bg-accent' : 'bg-[rgb(var(--c-off))]'}`}>
        <span className={`absolute top-1 left-1 w-4 h-4 rounded-full bg-white shadow-sm transition-transform ${checked ? 'translate-x-4' : ''}`} />
      </span>
    </label>
  );
}

// Segmented choice (radio group). options: [{ value, label }]
export function Segmented({ value, onChange, options, label, size = 'sm' }) {
  return (
    <div role="radiogroup" aria-label={label} className="inline-flex p-0.5 rounded-lg bg-bg border border-bdr">
      {options.map(o => {
        const on = o.value === value;
        return (
          <button key={o.value} type="button" role="radio" aria-checked={on} onClick={() => onChange(o.value)}
                  className={`px-3 ${size === 'sm' ? 'h-8' : 'h-11 sm:h-10'} rounded-md text-xs font-semibold whitespace-nowrap transition-colors
                    ${on ? (o.tone ? '' : 'bg-card text-tp') : 'text-ts hover:text-tp'}`}
                  style={on && o.tone ? { background: `${o.tone}26`, color: o.tone } : undefined}>
            {o.label}
          </button>
        );
      })}
    </div>
  );
}

// Underline tabs used for in-page sections.
export function Tabs({ value, onChange, tabs, label }) {
  return (
    <div role="tablist" aria-label={label} className="flex gap-6 border-b border-bdr overflow-x-auto">
      {tabs.map(t => {
        const on = t.value === value;
        return (
          <button key={t.value} role="tab" aria-selected={on} onClick={() => onChange(t.value)}
                  className={`relative min-h-[44px] text-[15px] whitespace-nowrap transition-colors ${on ? 'text-tp font-semibold' : 'text-ts hover:text-tp'}`}>
            {t.label}
            {t.count != null && <span className="num text-[15px] text-ts ml-1.5">{t.count}</span>}
            {on && <span className="absolute left-0 right-0 -bottom-px h-[2px] bg-accent" />}
          </button>
        );
      })}
    </div>
  );
}
