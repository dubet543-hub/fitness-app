import React, { useEffect, useRef, useState } from 'react';
import { api } from '../api';
import { downloadAthleteReport, REPORT_PERIODS } from '../utils/pdfReport';
import { Avatar, Button, Checkbox, ConditionChip, Icon, Segmented, useToast } from './ui';
import { CONDITION } from '../utils/athleteStatus';

const SECTIONS = [
  { key: 'workload', label: 'Training load & ACWR', hint: 'Load history and ACWR trend charts' },
  { key: 'recovery', label: 'Readiness & wellness', hint: 'Readiness trend, wellness ratings and averages' },
  { key: 'body', label: 'Body composition', hint: 'Latest analysis, progress chart and suggestions' },
  { key: 'log', label: 'Session log', hint: 'Every session in the period' },
];

// Choose period + sections, then build the athlete PDF. Pass `sessions` /
// `bodyComposition` when the page already has them; otherwise they're fetched.
export default function ReportDialog({ athlete, sessions: given, bodyComposition: givenBody, onClose }) {
  const [period, setPeriod] = useState('28');
  const [sections, setSections] = useState({ workload: true, recovery: true, body: true, log: true });
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

  const none = !Object.values(sections).some(Boolean);

  async function download() {
    setBusy(true); setError('');
    try {
      const [sessions, bodyComposition] = await Promise.all([
        given ?? api.get(`/admin/athletes/${athlete._id}/sessions?limit=365`),
        givenBody !== undefined ? givenBody : api.get(`/admin/athletes/${athlete._id}/body-composition`).catch(() => null),
      ]);
      // Let the button show its busy state before the (synchronous) PDF build.
      await new Promise(r => setTimeout(r, 30));
      downloadAthleteReport(athlete, { sessions, bodyComposition, period, sections, condition: athlete.cond });
      toast(`${athlete.name}'s report downloaded`);
      onClose();
    } catch (e) {
      setError(e?.message || 'Could not build the report. Please try again.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/60 flex items-end sm:items-center justify-center sm:p-6" onMouseDown={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div role="dialog" aria-modal="true" aria-labelledby="report-title"
           className="w-full sm:max-w-lg bg-surface border border-bdr rounded-t-2xl sm:rounded-xl shadow-2xl max-h-[92dvh] overflow-y-auto">
        <div className="flex items-start gap-3 px-5 pt-5 pb-4 border-b border-bdr">
          <Avatar name={athlete.name} size="w-10 h-10 text-sm" />
          <div className="min-w-0 flex-1">
            <h2 id="report-title" className="display text-[22px] leading-tight text-tp">PDF report</h2>
            <div className="text-sm text-ts truncate">{athlete.name} · {athlete.sport || 'General'}</div>
          </div>
          {athlete.cond && <ConditionChip condition={athlete.active === false ? { ...CONDITION.nodata, label: 'Inactive' } : athlete.cond} />}
          <button ref={closeRef} onClick={onClose} aria-label="Close" className="w-11 h-11 -mr-2 -mt-1 rounded-lg flex items-center justify-center text-ts hover:text-tp hover:bg-card">
            <Icon name="x" className="w-5 h-5" />
          </button>
        </div>

        <div className="px-5 py-5 space-y-5">
          <div>
            <div className="label-caps mb-2">Period</div>
            <Segmented label="Report period" size="md" value={period} onChange={setPeriod} options={REPORT_PERIODS} />
            <p className="text-xs text-ts mt-1.5">ACWR and chronic load always use the full history, so they match the console.</p>
          </div>
          <fieldset>
            <legend className="label-caps mb-1">Include</legend>
            <div className="rounded-lg border border-bdr bg-bg px-3 py-1.5">
              {SECTIONS.map(s => (
                <Checkbox key={s.key} label={s.label} hint={s.hint} checked={sections[s.key]}
                          onChange={v => setSections(x => ({ ...x, [s.key]: v }))} />
              ))}
            </div>
            <p className="text-xs text-ts mt-1.5">The header, condition and headline numbers are always included.</p>
          </fieldset>
          {error && <div role="alert" className="text-sm text-[rgb(var(--c-danger))]">{error}</div>}
        </div>

        <div className="flex gap-2 justify-end px-5 py-4 border-t border-bdr">
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" icon="download" onClick={download} disabled={busy || none}>
            {busy ? 'Building PDF…' : 'Download PDF'}
          </Button>
        </div>
      </div>
    </div>
  );
}
