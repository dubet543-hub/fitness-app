import React from 'react';

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
  primary:   'bg-accent text-white hover:bg-orange-600 border border-accent',
  secondary: 'bg-card text-tp border border-bdr hover:border-ts',
  ghost:     'text-ts hover:text-tp hover:bg-card border border-transparent',
  danger:    'text-red-300 border border-red-500/40 hover:bg-red-500/10',
};

export function Button({ variant = 'secondary', icon, children, className = '', ...props }) {
  return (
    <button
      type="button"
      {...props}
      className={`inline-flex items-center justify-center gap-1.5 rounded-lg px-3.5 h-9 text-xs font-semibold
        transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${BTN[variant]} ${className}`}
    >
      {icon && <Icon name={icon} className="w-3.5 h-3.5" />}
      {children}
    </button>
  );
}

export function PageHeader({ title, subtitle, actions }) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-3">
      <div>
        <h1 className="text-2xl font-bold text-tp tracking-tight">{title}</h1>
        {subtitle && <p className="text-sm text-ts mt-1">{subtitle}</p>}
      </div>
      {actions && <div className="flex gap-2 flex-wrap">{actions}</div>}
    </div>
  );
}

export function Card({ title, subtitle, actions, children, className = '', bodyClassName = 'p-5' }) {
  return (
    <section className={`bg-surface border border-bdr rounded-xl ${className}`}>
      {(title || actions) && (
        <div className="flex items-start justify-between gap-3 px-5 pt-4 pb-3 border-b border-bdr/70">
          <div className="min-w-0">
            {title && <h2 className="text-sm font-semibold text-tp">{title}</h2>}
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
    <div className="bg-surface border border-bdr rounded-xl p-4 flex flex-wrap items-end gap-3">
      {children}
    </div>
  );
}

export function Field({ label, htmlFor, children, className = '' }) {
  return (
    <div className={`flex flex-col gap-1.5 ${className}`}>
      <label htmlFor={htmlFor} className="text-[11px] font-medium text-ts uppercase tracking-wider">{label}</label>
      {children}
    </div>
  );
}

export function AthleteSelect({ id, athletes, value, onChange, allLabel }) {
  return (
    <select id={id} value={value} onChange={e => onChange(e.target.value)} className="!w-auto min-w-[220px] h-9">
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
    <span className={`${size} shrink-0 rounded-full bg-accent/15 text-accent font-bold inline-flex items-center justify-center`}>
      {initials}
    </span>
  );
}

export function EmptyState({ icon = 'chart', title, hint, action }) {
  return (
    <div className="py-14 px-6 flex flex-col items-center text-center">
      <span className="w-11 h-11 rounded-full bg-card border border-bdr flex items-center justify-center text-ts mb-3">
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
    <div role="alert" className="flex items-center gap-3 bg-red-500/10 border border-red-500/40 rounded-xl px-4 py-3 text-sm text-red-300">
      <Icon name="alert" className="w-4 h-4 shrink-0" />
      <span className="flex-1">{message}</span>
      {onRetry && <Button variant="danger" icon="refresh" onClick={onRetry}>Retry</Button>}
    </div>
  );
}

export function Skeleton({ className = 'h-4 w-full' }) {
  return <div className={`animate-pulse motion-reduce:animate-none rounded-md bg-card ${className}`} />;
}

export function TableSkeleton({ rows = 5 }) {
  return (
    <div className="p-5 space-y-3" aria-busy="true" aria-label="Loading">
      {Array.from({ length: rows }).map((_, i) => <Skeleton key={i} className="h-8 w-full" />)}
    </div>
  );
}

// Coloured tile for a single number — used for KPI rows across sections.
export function Metric({ label, value, sub, color = '#8B949E' }) {
  return (
    <div className="rounded-xl p-3.5 min-w-0" style={{ background: `${color}12`, border: `1px solid ${color}40` }}>
      <div className="text-[11px] text-ts">{label}</div>
      <div className="text-xl font-extrabold leading-tight mt-1 truncate tabular-nums" style={{ color }}>{value}</div>
      {sub && <div className="text-[11px] text-ts mt-0.5 truncate">{sub}</div>}
    </div>
  );
}
