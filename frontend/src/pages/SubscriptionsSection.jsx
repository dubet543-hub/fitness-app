import React, { useEffect, useState } from 'react';
import { api } from '../api';
import Badge from '../components/Badge';

// ── Admin › Subscriptions ───────────────────────────────────────────────────
// Assign / upgrade / downgrade / suspend / cancel / extend / comp plans per
// athlete, edit the plan catalogue + billing defaults, and read the complete
// audit history. Everything here only rewrites subscription records — athlete
// data is never touched, so downgrades lock features without deleting reports.

const STATUS_COLOR = {
  trial: 'blue', active: 'green', grace: 'yellow',
  suspended: 'red', cancelled: 'red', expired: 'red', none: 'gray',
};

const fmtDate  = (v) => (v ? new Date(v).toLocaleDateString() : '—');
const fmtStamp = (v) => (v ? new Date(v).toLocaleString() : '—');
const inr      = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`;

const inputCls = 'bg-bg border border-bdr rounded-lg px-3 py-2 text-sm text-tp w-full';
const btnCls   = 'px-3 py-2 rounded-lg text-sm font-medium border border-bdr text-ts hover:text-tp hover:bg-card transition disabled:opacity-40';
const btnAccent = 'px-3 py-2 rounded-lg text-sm font-semibold bg-accent/15 text-accent border border-accent/40 hover:bg-accent/25 transition disabled:opacity-40';

export default function SubscriptionsSection({ athletes }) {
  const [billing, setBilling]   = useState(null); // { settings, plans, featureNames }
  const [athleteId, setAthId]   = useState('');
  const [detail, setDetail]     = useState(null); // { subscription, entitlements, history }
  const [audit, setAudit]       = useState([]);
  const [tab, setTab]           = useState('Athlete');
  const [msg, setMsg]           = useState('');
  const [err, setErr]           = useState('');
  const [busy, setBusy]         = useState(false);

  const flash = (m) => { setMsg(m); setErr(''); setTimeout(() => setMsg(''), 3500); };
  const fail  = (e) => { setErr(e.message || String(e)); setMsg(''); };

  const loadBilling = () => api.get('/admin/billing').then(setBilling).catch(fail);
  const loadDetail  = (id) =>
    id && api.get(`/admin/athletes/${id}/subscription`).then(setDetail).catch(fail);
  const loadAudit   = () => api.get('/admin/billing/audit?limit=200').then(setAudit).catch(fail);

  useEffect(() => { loadBilling(); }, []);
  useEffect(() => { setDetail(null); loadDetail(athleteId); }, [athleteId]);
  useEffect(() => { if (tab === 'Audit log') loadAudit(); }, [tab]);

  async function act(body, okMsg) {
    if (!athleteId) return;
    setBusy(true);
    try {
      await api.post(`/admin/athletes/${athleteId}/subscription`, body);
      await loadDetail(athleteId);
      flash(okMsg);
    } catch (e) { fail(e); }
    setBusy(false);
  }

  const featureNames = billing?.featureNames || {};
  const plans = billing?.plans || [];

  return (
    <div className="space-y-6">
      {/* Sub-tabs */}
      <div className="flex gap-2">
        {['Athlete', 'Plans & Settings', 'Audit log'].map((t) => (
          <button key={t} onClick={() => setTab(t)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition ${
              tab === t ? 'bg-accent/15 text-accent' : 'text-ts hover:text-tp hover:bg-card'}`}>
            {t}
          </button>
        ))}
      </div>

      {msg && <div className="text-sm text-green-400 bg-green-500/10 border border-green-500/30 rounded-lg px-4 py-2">{msg}</div>}
      {err && <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/30 rounded-lg px-4 py-2">{err}</div>}

      {tab === 'Athlete' && (
        <AthleteManager
          athletes={athletes} athleteId={athleteId} setAthId={setAthId}
          detail={detail} plans={plans} featureNames={featureNames}
          act={act} busy={busy}
        />
      )}

      {tab === 'Plans & Settings' && billing && (
        <PlansAndSettings billing={billing} reload={loadBilling} flash={flash} fail={fail} />
      )}

      {tab === 'Audit log' && <AuditTable rows={audit} />}
    </div>
  );
}

// ── Per-athlete manager ─────────────────────────────────────────────────────

function AthleteManager({ athletes, athleteId, setAthId, detail, plans, featureNames, act, busy }) {
  const [planKey, setPlanKey]   = useState('');
  const [comp, setComp]         = useState(false);
  const [extendDays, setDays]   = useState(30);
  const [expiry, setExpiry]     = useState('');
  const [trialEnd, setTrialEnd] = useState('');
  const [grace, setGrace]       = useState('');
  const [note, setNote]         = useState('');
  const [grant, setGrant]       = useState([]);
  const [revoke, setRevoke]     = useState([]);

  useEffect(() => {
    const o = detail?.subscription?.featureOverrides;
    setGrant(o?.grant || []);
    setRevoke(o?.revoke || []);
  }, [detail]);

  const ent = detail?.entitlements;
  const sub = detail?.subscription;
  const withNote = (body) => (note.trim() ? { ...body, note: note.trim() } : body);
  const toggle = (list, setList, f) =>
    setList(list.includes(f) ? list.filter((x) => x !== f) : [...list, f]);

  return (
    <div className="space-y-6">
      <select className={inputCls + ' max-w-md'} value={athleteId} onChange={(e) => setAthId(e.target.value)}>
        <option value="">Select athlete…</option>
        {athletes.map((a) => <option key={a._id} value={a._id}>{a.name} — {a.email}</option>)}
      </select>

      {athleteId && !detail && <div className="text-ts text-sm">Loading…</div>}

      {ent && (
        <>
          {/* Current state */}
          <div className="bg-card border border-bdr rounded-xl p-5 space-y-3">
            <div className="flex flex-wrap items-center gap-3">
              <Badge color={STATUS_COLOR[ent.status] || 'gray'}>{ent.status.toUpperCase()}</Badge>
              {ent.planName && <span className="text-tp font-semibold">{ent.planName}</span>}
              {ent.complimentary && <Badge color="blue">COMPLIMENTARY</Badge>}
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-sm">
              <Info label="Trial ends"   value={fmtDate(ent.trialEndsAt)} />
              <Info label="Expires"      value={fmtDate(ent.expiresAt)} />
              <Info label="Grace until"  value={fmtDate(ent.graceEndsAt)} />
              <Info label="Grace days"   value={sub?.graceDays ?? 'default'} />
            </div>
            <div>
              <div className="text-xs text-ts uppercase tracking-wide mb-1.5">Unlocked features</div>
              <div className="flex flex-wrap gap-1.5">
                {ent.features.length === 0 && <span className="text-ts text-sm">none</span>}
                {ent.features.map((f) => <Badge key={f} color="green">{featureNames[f] || f}</Badge>)}
              </div>
            </div>
          </div>

          {/* Note applied to every action */}
          <input className={inputCls} placeholder="Optional note recorded in the audit log…"
            value={note} onChange={(e) => setNote(e.target.value)} />

          {/* Assign / change plan */}
          <Card title="Assign / change plan">
            <div className="flex flex-wrap items-center gap-3">
              <select className={inputCls + ' max-w-xs'} value={planKey} onChange={(e) => setPlanKey(e.target.value)}>
                <option value="">Select plan…</option>
                {plans.map((p) => (
                  <option key={p.key} value={p.key}>{p.name} — {inr(p.priceInr)}/yr</option>
                ))}
              </select>
              <label className="flex items-center gap-2 text-sm text-ts">
                <input type="checkbox" checked={comp} onChange={(e) => setComp(e.target.checked)} />
                Complimentary
              </label>
              <button className={btnAccent} disabled={busy || !planKey}
                onClick={() => act(withNote({ action: 'assign', plan: planKey, complimentary: comp }),
                  'Plan assigned — new term started')}>
                Assign (new term)
              </button>
              <button className={btnCls} disabled={busy || !planKey}
                onClick={() => act(withNote({ action: 'change_plan', plan: planKey }),
                  'Plan changed — same term, data untouched')}>
                Upgrade / downgrade (keep term)
              </button>
            </div>
          </Card>

          {/* State controls */}
          <Card title="Status">
            <div className="flex flex-wrap gap-3">
              {sub?.status !== 'suspended' ? (
                <button className={btnCls} disabled={busy}
                  onClick={() => act(withNote({ action: 'suspend' }), 'Subscription suspended')}>
                  Suspend
                </button>
              ) : (
                <button className={btnAccent} disabled={busy}
                  onClick={() => act(withNote({ action: 'resume' }), 'Subscription resumed')}>
                  Resume
                </button>
              )}
              <button className={btnCls} disabled={busy}
                onClick={() => window.confirm('Cancel this subscription? Data is retained; access ends immediately.')
                  && act(withNote({ action: 'cancel' }), 'Subscription cancelled')}>
                Cancel
              </button>
            </div>
          </Card>

          {/* Dates */}
          <Card title="Dates & grace">
            <div className="flex flex-wrap items-end gap-3">
              <Field label={sub?.status === 'trial' ? 'Extend trial by (days)' : 'Extend term by (days)'}>
                <input type="number" className={inputCls + ' w-28'} value={extendDays}
                  onChange={(e) => setDays(e.target.value)} />
              </Field>
              <button className={btnCls} disabled={busy}
                onClick={() => act(withNote({ action: 'extend', days: Number(extendDays) }), 'Extended')}>
                Extend
              </button>
              <Field label="Set expiry date">
                <input type="date" className={inputCls} value={expiry} onChange={(e) => setExpiry(e.target.value)} />
              </Field>
              <button className={btnCls} disabled={busy || !expiry}
                onClick={() => act(withNote({ action: 'set_expiry', expiresAt: expiry }), 'Expiry set')}>
                Set expiry
              </button>
              <Field label="Set trial end">
                <input type="date" className={inputCls} value={trialEnd} onChange={(e) => setTrialEnd(e.target.value)} />
              </Field>
              <button className={btnCls} disabled={busy || !trialEnd}
                onClick={() => act(withNote({ action: 'set_trial', trialEndsAt: trialEnd }), 'Trial end set')}>
                Set trial end
              </button>
              <Field label="Grace days (blank = default)">
                <input type="number" className={inputCls + ' w-28'} value={grace}
                  onChange={(e) => setGrace(e.target.value)} />
              </Field>
              <button className={btnCls} disabled={busy}
                onClick={() => act(withNote({ action: 'set_grace', graceDays: grace === '' ? null : Number(grace) }),
                  'Grace period set')}>
                Set grace
              </button>
            </div>
          </Card>

          {/* Per-athlete feature overrides */}
          <Card title="Individual feature access (overrides the plan)">
            <div className="grid sm:grid-cols-2 gap-4">
              <OverrideList title="Grant extra features" list={grant}
                onToggle={(f) => toggle(grant, setGrant, f)} featureNames={featureNames} color="green" />
              <OverrideList title="Revoke plan features" list={revoke}
                onToggle={(f) => toggle(revoke, setRevoke, f)} featureNames={featureNames} color="red" />
            </div>
            <button className={btnAccent + ' mt-3'} disabled={busy}
              onClick={() => act(withNote({ action: 'override_features', grant, revoke }), 'Overrides saved')}>
              Save overrides
            </button>
          </Card>

          {/* History */}
          <Card title="Change history">
            <AuditTable rows={detail.history} compact />
          </Card>
        </>
      )}
    </div>
  );
}

// ── Plans & billing settings ────────────────────────────────────────────────

function PlansAndSettings({ billing, reload, flash, fail }) {
  const [settings, setSettings] = useState(billing.settings);
  const [plans, setPlans]       = useState(billing.plans);
  const [busy, setBusy]         = useState(false);
  const featureNames = billing.featureNames;

  useEffect(() => { setSettings(billing.settings); setPlans(billing.plans); }, [billing]);

  async function saveSettings() {
    setBusy(true);
    try {
      await api.put('/admin/billing/settings', {
        trialDays: Number(settings.trialDays), graceDays: Number(settings.graceDays),
      });
      flash('Billing defaults saved'); reload();
    } catch (e) { fail(e); }
    setBusy(false);
  }

  async function savePlan(p) {
    setBusy(true);
    try {
      await api.put(`/admin/billing/plans/${p.key}`, {
        name: p.name, priceInr: Number(p.priceInr), durationDays: Number(p.durationDays),
        features: p.features, active: p.active,
      });
      flash(`${p.name} saved`); reload();
    } catch (e) { fail(e); }
    setBusy(false);
  }

  const patchPlan = (key, patch) =>
    setPlans(plans.map((p) => (p.key === key ? { ...p, ...patch } : p)));

  return (
    <div className="space-y-6">
      <Card title="Defaults for new users">
        <div className="flex flex-wrap items-end gap-3">
          <Field label="Free trial (days)">
            <input type="number" className={inputCls + ' w-28'} value={settings.trialDays}
              onChange={(e) => setSettings({ ...settings, trialDays: e.target.value })} />
          </Field>
          <Field label="Default grace period (days)">
            <input type="number" className={inputCls + ' w-28'} value={settings.graceDays}
              onChange={(e) => setSettings({ ...settings, graceDays: e.target.value })} />
          </Field>
          <button className={btnAccent} disabled={busy} onClick={saveSettings}>Save defaults</button>
        </div>
      </Card>

      {plans.map((p) => (
        <Card key={p.key} title={`Plan — ${p.key}`}>
          <div className="flex flex-wrap items-end gap-3 mb-3">
            <Field label="Name">
              <input className={inputCls + ' w-56'} value={p.name}
                onChange={(e) => patchPlan(p.key, { name: e.target.value })} />
            </Field>
            <Field label="Price (₹/term)">
              <input type="number" className={inputCls + ' w-32'} value={p.priceInr}
                onChange={(e) => patchPlan(p.key, { priceInr: e.target.value })} />
            </Field>
            <Field label="Term (days)">
              <input type="number" className={inputCls + ' w-28'} value={p.durationDays}
                onChange={(e) => patchPlan(p.key, { durationDays: e.target.value })} />
            </Field>
            <label className="flex items-center gap-2 text-sm text-ts pb-2">
              <input type="checkbox" checked={p.active}
                onChange={(e) => patchPlan(p.key, { active: e.target.checked })} />
              Available
            </label>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mb-3">
            {Object.entries(featureNames).map(([key, label]) => (
              <label key={key} className="flex items-center gap-2 text-sm text-ts">
                <input type="checkbox" checked={p.features.includes(key)}
                  onChange={(e) => patchPlan(p.key, {
                    features: e.target.checked
                      ? [...p.features, key]
                      : p.features.filter((f) => f !== key),
                  })} />
                {label}
              </label>
            ))}
          </div>
          <button className={btnAccent} disabled={busy} onClick={() => savePlan(p)}>
            Save {p.name}
          </button>
        </Card>
      ))}
    </div>
  );
}

// ── Audit table ─────────────────────────────────────────────────────────────

function AuditTable({ rows, compact = false }) {
  if (!rows?.length) return <div className="text-ts text-sm">No entries yet.</div>;
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-xs text-ts uppercase tracking-wide border-b border-bdr">
            <th className="py-2 pr-4">When</th>
            {!compact && <th className="py-2 pr-4">Athlete</th>}
            <th className="py-2 pr-4">Action</th>
            <th className="py-2 pr-4">By</th>
            <th className="py-2 pr-4">Change</th>
            <th className="py-2">Note</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r._id || r.createdAt + r.action} className="border-b border-bdr/50 text-ts align-top">
              <td className="py-2 pr-4 whitespace-nowrap">{fmtStamp(r.createdAt)}</td>
              {!compact && <td className="py-2 pr-4">{r.user?.name || '—'}</td>}
              <td className="py-2 pr-4"><Badge color="blue">{r.action}</Badge></td>
              <td className="py-2 pr-4">{r.actor?.name || 'system'}</td>
              <td className="py-2 pr-4">{summariseChange(r)}</td>
              <td className="py-2">{r.note || ''}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** Human summary of what changed between the before/after snapshots. */
function summariseChange(r) {
  const b = r.before || {}, a = r.after || {};
  const bits = [];
  if (b.plan !== a.plan) bits.push(`plan ${b.plan || '—'} → ${a.plan || '—'}`);
  if (b.status !== a.status) bits.push(`status ${b.status || '—'} → ${a.status || '—'}`);
  if (String(b.expiresAt) !== String(a.expiresAt) && (b.expiresAt || a.expiresAt))
    bits.push(`expires ${fmtDate(b.expiresAt)} → ${fmtDate(a.expiresAt)}`);
  if (String(b.trialEndsAt) !== String(a.trialEndsAt) && (b.trialEndsAt || a.trialEndsAt))
    bits.push(`trial ${fmtDate(b.trialEndsAt)} → ${fmtDate(a.trialEndsAt)}`);
  if (JSON.stringify(b.featureOverrides) !== JSON.stringify(a.featureOverrides) && a.featureOverrides)
    bits.push('overrides changed');
  if (b.trialDays !== undefined && b.trialDays !== a.trialDays) bits.push(`trial days ${b.trialDays} → ${a.trialDays}`);
  if (b.graceDays !== undefined && b.graceDays !== a.graceDays) bits.push(`grace ${b.graceDays} → ${a.graceDays}`);
  if (b.priceInr !== undefined && b.priceInr !== a.priceInr) bits.push(`price ${inr(b.priceInr)} → ${inr(a.priceInr)}`);
  return bits.join(', ') || '—';
}

// ── Small shared pieces ─────────────────────────────────────────────────────

function Card({ title, children }) {
  return (
    <div className="bg-card border border-bdr rounded-xl p-5">
      <div className="text-sm font-semibold text-tp mb-3">{title}</div>
      {children}
    </div>
  );
}

function Field({ label, children }) {
  return (
    <div>
      <div className="text-xs text-ts mb-1">{label}</div>
      {children}
    </div>
  );
}

function Info({ label, value }) {
  return (
    <div>
      <div className="text-xs text-ts uppercase tracking-wide">{label}</div>
      <div className="text-tp">{value}</div>
    </div>
  );
}

function OverrideList({ title, list, onToggle, featureNames, color }) {
  return (
    <div>
      <div className={`text-xs uppercase tracking-wide mb-1.5 ${color === 'green' ? 'text-green-400' : 'text-red-400'}`}>
        {title}
      </div>
      <div className="space-y-1.5">
        {Object.entries(featureNames).map(([key, label]) => (
          <label key={key} className="flex items-center gap-2 text-sm text-ts">
            <input type="checkbox" checked={list.includes(key)} onChange={() => onToggle(key)} />
            {label}
          </label>
        ))}
      </div>
    </div>
  );
}
