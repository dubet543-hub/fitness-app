import React, { useEffect, useRef, useState } from 'react';
import { api } from '../api';
import { computeBCA } from '../utils/bodyComposition';
import { Avatar, Button, Field, Icon, Segmented, useToast } from './ui';

const SEX_OPTIONS = [{ value: 'male', label: 'Male' }, { value: 'female', label: 'Female' }];
// Local calendar date (not UTC) — matches how every date input/display else-
// where in admin treats "today", so the date shown here is the one the coach
// actually expects, regardless of the stored timestamp's exact UTC time.
const toDateInput = d => {
  const x = new Date(d);
  return `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, '0')}-${String(x.getDate()).padStart(2, '0')}`;
};
const todayStr = () => toDateInput(new Date());

// Lets a coach enter/correct an athlete's body-composition measurements
// directly, for athletes who can't or haven't run the analysis themselves in
// the app. Uses the same formulae (computeBCA) so the stored estimate is
// identical to what the app would have computed from the same inputs.
// Editing an existing reading (initial._id set) updates that exact document;
// adding a fresh one creates a new reading dated today.
export default function BodyCompDialog({ athlete, initial, onClose, onSaved }) {
  const [form, setForm] = useState({
    sex: initial?.isMale === false ? 'female' : 'male',
    weightKg: initial?.weightKg ?? '',
    heightCm: initial?.heightCm ?? '',
    neckCm: initial?.neckCm ?? '',
    abdomenCm: initial?.abdomenCm ?? '',
    hipCm: initial?.hipCm ?? '',
    date: initial?.date ? toDateInput(initial.date) : todayStr(),
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const toast = useToast();
  const closeRef = useRef(null);

  useEffect(() => {
    const prev = document.activeElement;
    closeRef.current?.focus();
    const onKey = e => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => { document.removeEventListener('keydown', onKey); prev?.focus?.(); };
  }, []);

  const isMale = form.sex === 'male';
  const num = v => (v === '' ? NaN : Number(v));
  const fields = [
    { key: 'weightKg', label: 'Weight (kg)' },
    { key: 'heightCm', label: 'Height (cm)' },
    { key: 'neckCm', label: 'Neck (cm)' },
    { key: 'abdomenCm', label: 'Abdomen (cm)' },
    ...(isMale ? [] : [{ key: 'hipCm', label: 'Hip (cm)' }]),
  ];
  const missing = fields.some(f => Number.isNaN(num(form[f.key])) || num(form[f.key]) <= 0);
  const preview = !missing ? computeBCA({
    isMale, weightKg: num(form.weightKg), heightCm: num(form.heightCm),
    neckCm: num(form.neckCm), abdomenCm: num(form.abdomenCm), hipCm: isMale ? undefined : num(form.hipCm),
  }) : null;

  async function save() {
    if (missing) { setError('Fill in every measurement (all must be greater than 0).'); return; }
    if (!preview) { setError("Those measurements don't produce a valid estimate — double-check them."); return; }
    setBusy(true); setError('');
    try {
      const payload = {
        date: form.date,
        isMale, weightKg: preview.weightKg, heightCm: preview.heightCm,
        neckCm: preview.neckCm, abdomenCm: preview.abdomenCm, hipCm: isMale ? undefined : preview.hipCm,
        bfPercent: preview.bfPercent, bfKg: preview.bfKg, lbm: preview.lbm,
        smmPercent: preview.smmPercent, smi: preview.smi, ffmi: preview.ffmi,
      };
      if (initial?._id) {
        await api.put(`/admin/athletes/${athlete._id}/body-composition/${initial._id}`, payload);
      } else {
        await api.post(`/admin/athletes/${athlete._id}/body-composition`, payload);
      }
      toast(`${athlete.name}'s body composition was saved.`);
      onSaved();
    } catch (e) {
      setError(e?.message || 'Could not save the measurements. Please try again.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/60 flex items-end sm:items-center justify-center sm:p-6" onMouseDown={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div role="dialog" aria-modal="true" aria-labelledby="bodycomp-title"
           className="w-full sm:max-w-lg bg-surface border border-bdr rounded-t-2xl sm:rounded-xl shadow-2xl max-h-[92dvh] overflow-y-auto">
        <div className="flex items-start gap-3 px-5 pt-5 pb-4 border-b border-bdr">
          <Avatar name={athlete.name} size="w-10 h-10 text-sm" />
          <div className="min-w-0 flex-1">
            <h2 id="bodycomp-title" className="display text-[22px] leading-tight text-tp">Body composition</h2>
            <div className="text-sm text-ts truncate">{athlete.name} · enter measurements directly</div>
          </div>
          <button ref={closeRef} onClick={onClose} aria-label="Close" className="w-11 h-11 -mr-2 -mt-1 rounded-lg flex items-center justify-center text-ts hover:text-tp hover:bg-card">
            <Icon name="x" className="w-5 h-5" />
          </button>
        </div>

        <div className="px-5 py-5 space-y-4">
          <div>
            <div className="label-caps mb-2">Sex</div>
            <Segmented label="Sex" size="md" value={form.sex} options={SEX_OPTIONS} onChange={v => setForm(f => ({ ...f, sex: v }))} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            {fields.map(fl => (
              <Field key={fl.key} label={fl.label} htmlFor={`bc-${fl.key}`}>
                <input id={`bc-${fl.key}`} type="number" inputMode="decimal" step="0.01" min="0" className="h-11"
                       value={form[fl.key]} onChange={e => setForm(f => ({ ...f, [fl.key]: e.target.value }))} />
              </Field>
            ))}
            <Field label="Date" htmlFor="bc-date">
              <input id="bc-date" type="date" className="h-11" max={todayStr()}
                     value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} />
            </Field>
          </div>

          {preview && (
            <div className="rounded-lg border border-bdr bg-bg px-4 py-3 grid grid-cols-3 gap-3 text-center">
              <div><div className="text-xs text-ts">Body fat</div><div className="num text-[17px] text-tp mt-0.5">{preview.bfPercent.toFixed(1)}%</div></div>
              <div><div className="text-xs text-ts">Lean mass</div><div className="num text-[17px] text-tp mt-0.5">{preview.lbm.toFixed(1)} kg</div></div>
              <div><div className="text-xs text-ts">FFMI</div><div className="num text-[17px] text-tp mt-0.5">{preview.ffmi.toFixed(1)}</div></div>
            </div>
          )}
          {error && <div role="alert" className="text-sm text-[rgb(var(--c-danger))]">{error}</div>}
        </div>

        <div className="flex gap-2 justify-end px-5 py-4 border-t border-bdr">
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" onClick={save} disabled={busy || missing}>
            {busy ? 'Saving…' : 'Save measurements'}
          </Button>
        </div>
      </div>
    </div>
  );
}
