import React, { useEffect, useMemo, useState } from 'react';
import { api } from '../api';
import {
  AthleteSelect, Avatar, Button, Card, Checkbox, EmptyState, Field, Icon, Segmented, Skeleton, Switch, Tabs, useToast,
} from '../components/ui';
import { STATUS } from '../utils/adminCharts';

// ── Admin › Subscriptions ───────────────────────────────────────────────────
// Assign / upgrade / downgrade / suspend / cancel / extend / comp plans per
// athlete, edit the plan catalogue + billing defaults, and read the complete
// audit history. Everything here only rewrites subscription records — athlete
// data is never touched, so downgrades lock features without deleting reports.

const SUB_STATUS = {
  trial:     { label: 'Free trial',   color: STATUS.info },
  active:    { label: 'Active',       color: STATUS.good },
  grace:     { label: 'Grace period', color: STATUS.warning },
  suspended: { label: 'Suspended',    color: STATUS.serious },
  cancelled: { label: 'Cancelled',    color: STATUS.critical },
  expired:   { label: 'Expired',      color: STATUS.critical },
  none:      { label: 'No plan',      color: STATUS.none },
};

const ACTION_LABEL = {
  assign: 'Plan assigned', change_plan: 'Plan changed', suspend: 'Suspended', resume: 'Resumed',
  cancel: 'Cancelled', extend: 'Term extended', set_expiry: 'Expiry date set', set_trial: 'Trial end set',
  set_grace: 'Grace period set', override_features: 'Feature access changed',
};
const humanAction = a => ACTION_LABEL[a] || (a || '').replace(/_/g, ' ').replace(/^./, c => c.toUpperCase());

const fmtDate  = v => (v ? new Date(v).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) : '—');
const fmtStamp = v => (v ? new Date(v).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
const inr      = n => `₹${Number(n || 0).toLocaleString('en-IN')}`;
const relDays  = v => {
  if (!v) return '';
  const d = Math.round((new Date(v) - Date.now()) / 864e5);
  return d === 0 ? 'today' : d > 0 ? `in ${d} day${d === 1 ? '' : 's'}` : `${-d} day${d === -1 ? '' : 's'} ago`;
};

function StatusDot({ status, size = 'sm' }) {
  const s = SUB_STATUS[status] || SUB_STATUS.none;
  return (
    <span className={`inline-flex items-center gap-1.5 font-semibold ${size === 'lg' ? 'text-sm' : 'text-[13px]'}`} style={{ color: s.color }}>
      <span className="w-2 h-2 rounded-full" style={{ background: s.color }} aria-hidden="true" />
      {s.label}
    </span>
  );
}

export default function SubscriptionsSection({ athletes }) {
  const [billing, setBilling] = useState(null); // { settings, plans, featureNames }
  const [athleteId, setAthId] = useState('');
  const [detail, setDetail]   = useState(null); // { subscription, entitlements, history }
  const [audit, setAudit]     = useState(null);
  const [tab, setTab]         = useState('athlete');
  const [busy, setBusy]       = useState(false);
  const toast = useToast();
  const fail = e => toast(e?.message || String(e), 'error');

  const loadBilling = () => api.get('/admin/billing').then(setBilling).catch(fail);
  const loadDetail  = id => id && api.get(`/admin/athletes/${id}/subscription`).then(setDetail).catch(fail);
  const loadAudit   = () => api.get('/admin/billing/audit?limit=200').then(setAudit).catch(e => { setAudit([]); fail(e); });

  useEffect(() => { loadBilling(); }, []);
  useEffect(() => { setDetail(null); loadDetail(athleteId); }, [athleteId]);
  useEffect(() => { if (tab === 'audit') loadAudit(); }, [tab]);

  async function act(body, okMsg) {
    if (!athleteId) return false;
    setBusy(true);
    try {
      await api.post(`/admin/athletes/${athleteId}/subscription`, body);
      await loadDetail(athleteId);
      toast(okMsg);
      return true;
    } catch (e) { fail(e); return false; }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-6">
      <Tabs label="Subscription views" value={tab} onChange={setTab} tabs={[
        { value: 'athlete', label: 'Athlete access' },
        { value: 'plans', label: 'Plans & defaults' },
        { value: 'audit', label: 'Audit log' },
      ]} />

      {tab === 'athlete' && (
        <AthleteManager athletes={athletes} athleteId={athleteId} setAthId={setAthId} detail={detail}
                        plans={billing?.plans || []} featureNames={billing?.featureNames || {}} act={act} busy={busy} />
      )}
      {tab === 'plans' && (billing
        ? <PlansAndSettings billing={billing} reload={loadBilling} toast={toast} fail={fail} />
        : <Skeleton className="h-80 w-full" />)}
      {tab === 'audit' && <AuditLog rows={audit} />}
    </div>
  );
}

// ── Per-athlete access ──────────────────────────────────────────────────────

function AthleteManager({ athletes, athleteId, setAthId, detail, plans, featureNames, act, busy }) {
  const [query, setQuery] = useState('');
  const shown = athletes.filter(a => !query.trim() || [a.name, a.email].some(v => v?.toLowerCase().includes(query.trim().toLowerCase())));
  const athlete = athletes.find(a => a._id === athleteId);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-[300px_minmax(0,1fr)] gap-6 items-start">
      {/* Athlete list */}
      {/* Phones: a compact picker keeps the details in view. */}
      <div className="lg:hidden">
        <Field label="Athlete" htmlFor="sub-ath-m">
          <AthleteSelect id="sub-ath-m" athletes={athletes} value={athleteId} onChange={setAthId} />
        </Field>
      </div>
      <Card title="Athletes" subtitle={`${athletes.length} on the roster`} bodyClassName="p-0" className="hidden lg:block lg:sticky lg:top-6">
        <div className="p-3 border-b border-bdr">
          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-ts"><Icon name="search" /></span>
            <input type="search" value={query} onChange={e => setQuery(e.target.value)} placeholder="Search athletes"
                   aria-label="Search athletes" className="!pl-9 h-11 sm:h-10" />
          </div>
        </div>
        <ul className="max-h-[60vh] overflow-y-auto py-1" role="listbox" aria-label="Choose an athlete">
          {shown.map(a => {
            const on = a._id === athleteId;
            return (
              <li key={a._id}>
                <button role="option" aria-selected={on} onClick={() => setAthId(a._id)}
                        className={`relative w-full flex items-center gap-3 px-4 py-2.5 text-left transition-colors ${on ? 'bg-card' : 'hover:bg-card/60'}`}>
                  {on && <span className="absolute left-0 top-2 bottom-2 w-[3px] rounded-full bg-accent" />}
                  <Avatar name={a.name} size="w-8 h-8 text-[11px]" />
                  <span className="min-w-0 flex-1">
                    <span className={`block text-sm truncate ${on ? 'text-tp font-semibold' : 'text-tp'}`}>{a.name}</span>
                    <span className="block text-xs text-ts truncate">{a.email}</span>
                  </span>
                </button>
              </li>
            );
          })}
          {shown.length === 0 && <li className="px-4 py-6 text-sm text-ts text-center">No athletes match.</li>}
        </ul>
      </Card>

      {/* Detail */}
      <div className="min-w-0">
        {!athleteId ? (
          <Card><EmptyState icon="card" title="Choose an athlete" hint="Pick someone from the list to see their plan, change their access or review their history." /></Card>
        ) : !detail ? (
          <div className="space-y-4"><Skeleton className="h-44 w-full" /><Skeleton className="h-64 w-full" /></div>
        ) : (
          <AthleteAccess key={athleteId} athlete={athlete} detail={detail} plans={plans} featureNames={featureNames} act={act} busy={busy} />
        )}
      </div>
    </div>
  );
}

function AthleteAccess({ athlete, detail, plans, featureNames, act, busy }) {
  const ent = detail.entitlements;
  const sub = detail.subscription;
  const currentPlan = plans.find(p => p.key === sub?.plan);

  const [planKey, setPlanKey] = useState(sub?.plan || '');
  const [comp, setComp] = useState(false);
  const [extendDays, setDays] = useState(30);
  const [expiry, setExpiry] = useState('');
  const [trialEnd, setTrialEnd] = useState('');
  const [grace, setGrace] = useState(sub?.graceDays ?? '');
  const [note, setNote] = useState('');
  const [overrides, setOverrides] = useState({});

  useEffect(() => {
    const o = sub?.featureOverrides || {};
    const map = {};
    (o.grant || []).forEach(f => { map[f] = 'grant'; });
    (o.revoke || []).forEach(f => { map[f] = 'revoke'; });
    setOverrides(map);
  }, [detail]);

  const withNote = body => (note.trim() ? { ...body, note: note.trim() } : body);
  const run = async (body, msg) => { if (await act(withNote(body), msg)) setNote(''); };

  const savedOverrides = useMemo(() => {
    const o = sub?.featureOverrides || {};
    return JSON.stringify({ g: [...(o.grant || [])].sort(), r: [...(o.revoke || [])].sort() });
  }, [sub]);
  const grant = Object.keys(overrides).filter(f => overrides[f] === 'grant');
  const revoke = Object.keys(overrides).filter(f => overrides[f] === 'revoke');
  const overridesDirty = JSON.stringify({ g: [...grant].sort(), r: [...revoke].sort() }) !== savedOverrides;
  const planFeatures = currentPlan?.features || [];

  return (
    <div className="space-y-6">
      {/* Summary */}
      <section className="card rounded-xl p-6">
        <div className="flex flex-col sm:flex-row sm:items-start gap-5">
          <div className="flex items-center gap-4 flex-1 min-w-0">
            <Avatar name={athlete?.name} size="w-14 h-14 text-lg" />
            <div className="min-w-0">
              <div className="text-sm text-ts truncate">{athlete?.name} · {athlete?.email}</div>
              <div className="display text-[26px] sm:text-[30px] leading-tight text-tp break-words">{ent.planName || (ent.status === 'trial' ? 'Free trial' : 'No plan')}</div>
              <div className="flex items-center gap-3 mt-1 flex-wrap">
                <StatusDot status={ent.status} size="lg" />
                {ent.complimentary && <span className="text-xs font-semibold text-ts border border-bdr rounded px-1.5 py-0.5">Complimentary</span>}
                {currentPlan && <span className="text-sm text-ts">{inr(currentPlan.priceInr)} / {currentPlan.durationDays} days</span>}
              </div>
            </div>
          </div>
        </div>
        <dl className="grid grid-cols-2 md:grid-cols-4 gap-px mt-6 rounded-lg overflow-hidden border border-bdr bg-bdr">
          {[
            ['Trial ends', ent.trialEndsAt],
            ['Expires', ent.expiresAt],
            ['Grace until', ent.graceEndsAt],
          ].map(([l, v]) => (
            <div key={l} className="bg-bg px-4 py-3">
              <dt className="label-caps">{l}</dt>
              <dd className="text-[15px] text-tp font-semibold mt-1">{fmtDate(v)}</dd>
              <dd className="text-xs text-ts">{relDays(v)}</dd>
            </div>
          ))}
          <div className="bg-bg px-4 py-3">
            <dt className="label-caps">Grace days</dt>
            <dd className="text-[15px] text-tp font-semibold mt-1">{sub?.graceDays ?? 'Default'}</dd>
          </div>
        </dl>
        <div className="mt-6">
          <div className="label-caps mb-2">Unlocked features · {ent.features.length} of {Object.keys(featureNames).length}</div>
          <ul className="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-1.5">
            {Object.entries(featureNames).map(([key, label]) => {
              const on = ent.features.includes(key);
              return (
                <li key={key} className={`flex items-center gap-2 text-sm ${on ? 'text-tp' : 'text-ts/70'}`}>
                  <span className={`w-4 h-4 rounded-full flex items-center justify-center ${on ? 'text-white' : ''}`}
                        style={{ background: on ? STATUS.good : 'transparent', boxShadow: on ? 'none' : 'inset 0 0 0 1.5px #3a3a40' }}>
                    {on && <Icon name="check" className="w-2.5 h-2.5" strokeWidth={3.5} />}
                  </span>
                  {label}
                </li>
              );
            })}
          </ul>
        </div>
      </section>

      {/* Audit note */}
      <Field label="Note for the audit log (optional)" htmlFor="sub-note">
        <input id="sub-note" value={note} onChange={e => setNote(e.target.value)} className="h-11"
               placeholder="e.g. Paid at front desk, receipt #1042" />
        <span className="text-xs text-ts">Saved with the next change you make below.</span>
      </Field>

      {/* Plan */}
      <Card title="Plan" subtitle="Start a new paid term, or switch plans while keeping the current dates.">
        <div role="radiogroup" aria-label="Plan" className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {plans.map(p => {
            const on = planKey === p.key;
            return (
              <button key={p.key} type="button" role="radio" aria-checked={on} onClick={() => setPlanKey(p.key)}
                      className={`text-left rounded-lg border p-4 transition-colors ${on ? 'border-accent bg-accent/[0.06]' : 'border-bdr bg-bg hover:border-[#3a3a40]'}`}>
                <div className="flex items-center gap-3">
                  <span className={`w-[18px] h-[18px] rounded-full border-2 flex items-center justify-center shrink-0 ${on ? 'border-accent' : 'border-[#3a3a40]'}`}>
                    {on && <span className="w-2 h-2 rounded-full bg-accent" />}
                  </span>
                  <span className="text-[15px] font-semibold text-tp flex-1">{p.name}</span>
                  {sub?.plan === p.key && <span className="text-xs text-ts">Current</span>}
                </div>
                <div className="pl-[30px] mt-1">
                  <span className="num text-2xl text-tp">{inr(p.priceInr)}</span>
                  <span className="text-sm text-ts"> / {p.durationDays} days · {p.features.length} features{p.active ? '' : ' · hidden'}</span>
                </div>
              </button>
            );
          })}
        </div>
        <div className="flex flex-col sm:flex-row sm:items-center gap-4 mt-5 pt-5 border-t border-bdr">
          <Checkbox checked={comp} onChange={setComp} label="Complimentary" hint="No payment — recorded as a free term" />
          <div className="flex gap-2 flex-wrap sm:ml-auto">
            <Button disabled={busy || !planKey} onClick={() => run({ action: 'change_plan', plan: planKey }, 'Plan switched — dates and data unchanged')}>
              Switch plan, keep dates
            </Button>
            <Button variant="primary" disabled={busy || !planKey} onClick={() => run({ action: 'assign', plan: planKey, complimentary: comp }, 'Plan assigned — new term started')}>
              Start new term
            </Button>
          </div>
        </div>
      </Card>

      {/* Dates */}
      <Card title="Dates & grace" subtitle="Each change applies on its own row.">
        <div className="divide-y divide-bdr">
          <DateRow label={sub?.status === 'trial' ? 'Extend trial' : 'Extend term'} hint="Adds days to the current end date">
            <div className="relative w-36">
              <input type="number" min="1" value={extendDays} onChange={e => setDays(e.target.value)} className="h-10 !pr-12" aria-label="Days to extend" />
              <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-ts">days</span>
            </div>
            <Button disabled={busy || !(Number(extendDays) > 0)} onClick={() => run({ action: 'extend', days: Number(extendDays) }, `Extended by ${extendDays} days`)}>Extend</Button>
          </DateRow>
          <DateRow label="Expiry date" hint={`Currently ${fmtDate(ent.expiresAt)}`}>
            <input type="date" value={expiry} onChange={e => setExpiry(e.target.value)} className="h-10 !w-44" aria-label="New expiry date" />
            <Button disabled={busy || !expiry} onClick={() => run({ action: 'set_expiry', expiresAt: expiry }, 'Expiry date set')}>Set</Button>
          </DateRow>
          <DateRow label="Trial end" hint={`Currently ${fmtDate(ent.trialEndsAt)}`}>
            <input type="date" value={trialEnd} onChange={e => setTrialEnd(e.target.value)} className="h-10 !w-44" aria-label="New trial end date" />
            <Button disabled={busy || !trialEnd} onClick={() => run({ action: 'set_trial', trialEndsAt: trialEnd }, 'Trial end set')}>Set</Button>
          </DateRow>
          <DateRow label="Grace period" hint="Leave blank to use the default">
            <div className="relative w-36">
              <input type="number" min="0" value={grace} onChange={e => setGrace(e.target.value)} placeholder="Default" className="h-10 !pr-12" aria-label="Grace days" />
              <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-ts">days</span>
            </div>
            <Button disabled={busy} onClick={() => run({ action: 'set_grace', graceDays: grace === '' ? null : Number(grace) }, 'Grace period set')}>Set</Button>
          </DateRow>
        </div>
      </Card>

      {/* Feature overrides */}
      <Card title="Feature access" subtitle="Override the plan for this athlete only. “Plan” follows whatever the plan includes."
            bodyClassName="p-0"
            actions={overridesDirty && <span className="text-xs font-semibold" style={{ color: STATUS.warning }}>Unsaved changes</span>}>
        <div className="overflow-x-auto">
          <table className="static">
            <thead><tr><th>Feature</th><th>In plan</th><th>Access</th><th>Result</th></tr></thead>
            <tbody>
              {Object.entries(featureNames).map(([key, label]) => {
                const mode = overrides[key] || 'plan';
                const on = mode === 'grant' || (mode === 'plan' && planFeatures.includes(key));
                return (
                  <tr key={key}>
                    <td className="text-tp">{label}</td>
                    <td>{planFeatures.includes(key)
                      ? <Icon name="check" className="w-4 h-4 text-tp" />
                      : <span className="text-ts">—</span>}</td>
                    <td>
                      <Segmented label={`${label} access`} value={mode}
                                 onChange={v => setOverrides(o => { const n = { ...o }; if (v === 'plan') delete n[key]; else n[key] = v; return n; })}
                                 options={[
                                   { value: 'plan', label: 'Plan' },
                                   { value: 'grant', label: 'Grant', tone: STATUS.good },
                                   { value: 'revoke', label: 'Revoke', tone: STATUS.critical },
                                 ]} />
                    </td>
                    <td><span className="inline-flex items-center gap-1.5 text-[13px] font-semibold" style={{ color: on ? STATUS.good : 'rgb(var(--c-ts))' }}>
                      <span className="w-1.5 h-1.5 rounded-full" style={{ background: on ? STATUS.good : '#55555b' }} />{on ? 'On' : 'Off'}
                    </span></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <div className="flex justify-end gap-2 p-4 border-t border-bdr">
          <Button disabled={busy || !overridesDirty} onClick={() => setOverrides(() => {
            const o = sub?.featureOverrides || {}; const m = {};
            (o.grant || []).forEach(f => { m[f] = 'grant'; }); (o.revoke || []).forEach(f => { m[f] = 'revoke'; }); return m;
          })}>Discard</Button>
          <Button variant="primary" disabled={busy || !overridesDirty}
                  onClick={() => run({ action: 'override_features', grant, revoke }, 'Feature access saved')}>Save feature access</Button>
        </div>
      </Card>

      {/* Access */}
      <Card title="Account access">
        <div className="flex flex-col sm:flex-row sm:items-center gap-4">
          <p className="text-sm text-ts flex-1">
            {sub?.status === 'suspended'
              ? 'Access is paused. Resuming restores the plan with its existing dates.'
              : 'Suspending pauses access without ending the term. Cancelling ends access now; their data is kept either way.'}
          </p>
          <div className="flex gap-2 shrink-0">
            {sub?.status !== 'suspended'
              ? <Button disabled={busy} onClick={() => run({ action: 'suspend' }, 'Subscription suspended')}>Suspend</Button>
              : <Button variant="primary" disabled={busy} onClick={() => run({ action: 'resume' }, 'Subscription resumed')}>Resume</Button>}
            <Button variant="danger" disabled={busy || sub?.status === 'cancelled'}
                    onClick={() => window.confirm(`Cancel ${athlete?.name || 'this athlete'}'s subscription? Access ends immediately; their data is kept.`)
                      && run({ action: 'cancel' }, 'Subscription cancelled')}>
              Cancel subscription
            </Button>
          </div>
        </div>
      </Card>

      {/* History */}
      <Card title="Change history" subtitle="Everything changed on this athlete's subscription">
        <History rows={detail.history} />
      </Card>
    </div>
  );
}

function DateRow({ label, hint, children }) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-[200px_minmax(0,1fr)] gap-2 sm:gap-6 py-3.5 first:pt-0 last:pb-0 items-center">
      <div>
        <div className="text-sm font-semibold text-tp">{label}</div>
        {hint && <div className="text-xs text-ts">{hint}</div>}
      </div>
      <div className="flex items-center gap-2 flex-wrap">{children}</div>
    </div>
  );
}

function History({ rows }) {
  if (!rows?.length) return <p className="text-sm text-ts">No changes recorded yet.</p>;
  return (
    <ol className="relative border-l border-bdr ml-1.5 space-y-5">
      {rows.map(r => (
        <li key={r._id || r.createdAt + r.action} className="pl-5 relative">
          <span className="absolute -left-[5px] top-1.5 w-[9px] h-[9px] rounded-full bg-accent ring-4 ring-surface" />
          <div className="flex items-baseline gap-2 flex-wrap">
            <span className="text-sm font-semibold text-tp">{humanAction(r.action)}</span>
            <span className="text-xs text-ts">{fmtStamp(r.createdAt)} · {r.actor?.name || 'System'}</span>
          </div>
          <div className="text-[13px] text-ts mt-0.5">{summariseChange(r)}</div>
          {r.note && <div className="text-[13px] text-tp mt-1 border-l-2 border-bdr pl-2">“{r.note}”</div>}
        </li>
      ))}
    </ol>
  );
}

// ── Plans & billing defaults ────────────────────────────────────────────────

function PlansAndSettings({ billing, reload, toast, fail }) {
  const [settings, setSettings] = useState(billing.settings);
  const [plans, setPlans] = useState(billing.plans);
  const [busy, setBusy] = useState(false);
  const featureNames = billing.featureNames;

  useEffect(() => { setSettings(billing.settings); setPlans(billing.plans); }, [billing]);

  const settingsDirty = Number(settings.trialDays) !== billing.settings.trialDays || Number(settings.graceDays) !== billing.settings.graceDays;
  const isDirty = p => {
    const o = billing.plans.find(x => x.key === p.key) || {};
    return o.name !== p.name || Number(o.priceInr) !== Number(p.priceInr) || Number(o.durationDays) !== Number(p.durationDays)
      || !!o.active !== !!p.active || (o.appleProductId || '') !== (p.appleProductId || '')
      || [...(o.features || [])].sort().join() !== [...p.features].sort().join();
  };

  async function saveSettings() {
    setBusy(true);
    try {
      await api.put('/admin/billing/settings', { trialDays: Number(settings.trialDays), graceDays: Number(settings.graceDays) });
      toast('Defaults saved'); reload();
    } catch (e) { fail(e); }
    setBusy(false);
  }

  async function savePlan(p) {
    setBusy(true);
    try {
      await api.put(`/admin/billing/plans/${p.key}`, {
        name: p.name, priceInr: Number(p.priceInr), durationDays: Number(p.durationDays),
        features: p.features, active: p.active, appleProductId: p.appleProductId || '',
      });
      toast(`${p.name} saved`); reload();
    } catch (e) { fail(e); }
    setBusy(false);
  }

  const patchPlan = (key, patch) => setPlans(plans.map(p => (p.key === key ? { ...p, ...patch } : p)));

  const daysInput = (id, value, onChange) => (
    <div className="relative w-40">
      <input id={id} type="number" min="0" value={value} onChange={e => onChange(e.target.value)} className="h-11 !pr-12" />
      <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-ts">days</span>
    </div>
  );

  return (
    <div className="space-y-6">
      <Card title="Defaults for new athletes" subtitle="Apply to accounts created from now on.">
        <div className="flex flex-wrap items-end gap-5">
          <Field label="Free trial" htmlFor="def-trial">{daysInput('def-trial', settings.trialDays, v => setSettings({ ...settings, trialDays: v }))}</Field>
          <Field label="Grace period after expiry" htmlFor="def-grace">{daysInput('def-grace', settings.graceDays, v => setSettings({ ...settings, graceDays: v }))}</Field>
          <Button variant="primary" className="sm:!h-11" disabled={busy || !settingsDirty} onClick={saveSettings}>Save defaults</Button>
        </div>
      </Card>

      <div className="grid grid-cols-1 2xl:grid-cols-2 gap-6">
        {plans.map(p => {
          const dirty = isDirty(p);
          return (
            <Card key={p.key} title={p.name || p.key} subtitle={`Plan id: ${p.key}`}
                  actions={<Switch label={p.active ? 'Available' : 'Hidden'} checked={!!p.active} onChange={v => patchPlan(p.key, { active: v })} />}>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <Field label="Name" htmlFor={`${p.key}-name`} className="sm:col-span-3">
                  <input id={`${p.key}-name`} value={p.name} onChange={e => patchPlan(p.key, { name: e.target.value })} className="h-11" />
                </Field>
                <Field label="Price per term" htmlFor={`${p.key}-price`}>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm text-ts">₹</span>
                    <input id={`${p.key}-price`} type="number" min="0" value={p.priceInr} onChange={e => patchPlan(p.key, { priceInr: e.target.value })} className="h-11 !pl-7" />
                  </div>
                </Field>
                <Field label="Term length" htmlFor={`${p.key}-term`}>
                  <div className="relative">
                    <input id={`${p.key}-term`} type="number" min="1" value={p.durationDays} onChange={e => patchPlan(p.key, { durationDays: e.target.value })} className="h-11 !pr-12" />
                    <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-ts">days</span>
                  </div>
                </Field>
                <div className="flex flex-col justify-end pb-1">
                  <span className="label-caps">Works out to</span>
                  <span className="num text-xl text-tp">{inr(Math.round(Number(p.priceInr || 0) / Math.max(1, Number(p.durationDays || 1)) * 30))}<span className="text-sm text-ts"> / month</span></span>
                </div>
                <Field label="Apple App Store product id (iOS purchases)" htmlFor={`${p.key}-apple`} className="sm:col-span-3">
                  <input id={`${p.key}-apple`} value={p.appleProductId || ''} placeholder="com.solidcore.ams.plan.…"
                         onChange={e => patchPlan(p.key, { appleProductId: e.target.value })} className="h-11 font-mono text-[13px]" />
                </Field>
              </div>

              <fieldset className="mt-6">
                <legend className="label-caps mb-2">Included features · {p.features.length} of {Object.keys(featureNames).length}</legend>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-6 rounded-lg border border-bdr bg-bg px-4 py-2">
                  {Object.entries(featureNames).map(([key, label]) => (
                    <Checkbox key={key} label={label} checked={p.features.includes(key)}
                              onChange={v => patchPlan(p.key, { features: v ? [...p.features, key] : p.features.filter(f => f !== key) })} />
                  ))}
                </div>
              </fieldset>

              <div className="flex items-center justify-end gap-3 mt-5 pt-5 border-t border-bdr">
                {dirty && <span className="text-xs font-semibold mr-auto" style={{ color: STATUS.warning }}>Unsaved changes</span>}
                <Button disabled={busy || !dirty} onClick={() => setPlans(plans.map(x => (x.key === p.key ? billing.plans.find(o => o.key === p.key) : x)))}>Discard</Button>
                <Button variant="primary" disabled={busy || !dirty} onClick={() => savePlan(p)}>Save plan</Button>
              </div>
            </Card>
          );
        })}
      </div>
    </div>
  );
}

// ── Audit log ───────────────────────────────────────────────────────────────

function AuditLog({ rows }) {
  const [query, setQuery] = useState('');
  if (!rows) return <Skeleton className="h-80 w-full" />;
  const q = query.trim().toLowerCase();
  const shown = rows.filter(r => !q || [r.user?.name, r.actor?.name, humanAction(r.action), r.note].some(v => v?.toLowerCase().includes(q)));
  return (
    <Card title="Audit log" subtitle={`${shown.length} of ${rows.length} entries · newest first`} bodyClassName="p-0"
          actions={
            <div className="relative w-56 hidden sm:block">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-ts"><Icon name="search" /></span>
              <input type="search" value={query} onChange={e => setQuery(e.target.value)} placeholder="Search log" aria-label="Search audit log" className="!pl-9 h-9" />
            </div>
          }>
      {shown.length === 0 ? <EmptyState icon="list" title={rows.length ? 'No entries match' : 'No changes recorded yet'} /> : (
        <div className="overflow-x-auto">
          <table className="static">
            <thead><tr><th>When</th><th>Athlete</th><th>Change</th><th>Details</th><th>By</th><th>Note</th></tr></thead>
            <tbody>
              {shown.map(r => (
                <tr key={r._id || r.createdAt + r.action}>
                  <td className="whitespace-nowrap text-ts">{fmtStamp(r.createdAt)}</td>
                  <td className="text-tp whitespace-nowrap">{r.user?.name || '—'}</td>
                  <td className="text-tp font-semibold whitespace-nowrap">{humanAction(r.action)}</td>
                  <td className="text-ts">{summariseChange(r)}</td>
                  <td className="text-ts whitespace-nowrap">{r.actor?.name || 'System'}</td>
                  <td className="text-ts">{r.note || ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}

/** Human summary of what changed between the before/after snapshots. */
function summariseChange(r) {
  const b = r.before || {}, a = r.after || {};
  const name = k => (k ? k.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()) : 'none');
  const bits = [];
  if (b.plan !== a.plan && (b.plan || a.plan)) bits.push(`Plan: ${name(b.plan)} → ${name(a.plan)}`);
  if (b.status !== a.status && (b.status || a.status)) bits.push(`Status: ${b.status || '—'} → ${a.status || '—'}`);
  if (String(b.expiresAt) !== String(a.expiresAt) && (b.expiresAt || a.expiresAt)) bits.push(`Expires: ${fmtDate(b.expiresAt)} → ${fmtDate(a.expiresAt)}`);
  if (String(b.trialEndsAt) !== String(a.trialEndsAt) && (b.trialEndsAt || a.trialEndsAt)) bits.push(`Trial ends: ${fmtDate(b.trialEndsAt)} → ${fmtDate(a.trialEndsAt)}`);
  if (JSON.stringify(b.featureOverrides) !== JSON.stringify(a.featureOverrides) && a.featureOverrides) bits.push('Feature access changed');
  if (b.trialDays !== undefined && b.trialDays !== a.trialDays) bits.push(`Trial days: ${b.trialDays} → ${a.trialDays}`);
  if (b.graceDays !== undefined && b.graceDays !== a.graceDays) bits.push(`Grace days: ${b.graceDays ?? 'default'} → ${a.graceDays ?? 'default'}`);
  if (b.priceInr !== undefined && b.priceInr !== a.priceInr) bits.push(`Price: ${inr(b.priceInr)} → ${inr(a.priceInr)}`);
  return bits.join(' · ') || '—';
}
