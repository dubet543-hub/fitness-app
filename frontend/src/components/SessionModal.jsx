import React from 'react';
import { fmtDate, fmtNum } from '../utils/fmt';

export default function SessionModal({ session: s, onClose }) {
  if (!s) return null;

  return (
    <div
      className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        className="bg-surface border border-bdr rounded-2xl w-full max-w-lg p-6 space-y-5"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-start justify-between">
          <div>
            <div className="text-base font-bold text-tp">{fmtDate(s.date)}</div>
            <div className="text-xs text-ts mt-0.5">
              {s.sessionType || [...(s.primaryTypes || []), ...(s.skillTypes || [])].join(' · ') || 'Training session'}
            </div>
          </div>
          <button onClick={onClose} className="text-ts hover:text-tp transition text-2xl leading-none">&times;</button>
        </div>

        {/* Quick stats */}
        <div className="grid grid-cols-2 gap-3">
          {[
            ['Total Load', `${fmtNum(s.totalLoad)} AU`],
            ['Grade', s.scaledGrade != null ? s.scaledGrade.toFixed(1) : '—'],
            ['Readiness', s.readinessPercent != null ? `${s.readinessPercent.toFixed(0)}%` : '—'],
            ['Duration', s.primaryDuration ? `${s.primaryDuration} min` : '—'],
            ['Z-Score', s.zScore != null ? s.zScore.toFixed(2) : '—'],
            ['Std Dev', s.standardDeviation != null ? s.standardDeviation.toFixed(1) : '—'],
          ].map(([l, v]) => (
            <div key={l} className="bg-card rounded-lg px-4 py-3">
              <div className="text-xs text-ts">{l}</div>
              <div className="text-base font-semibold text-tp mt-0.5">{v}</div>
            </div>
          ))}
        </div>

        {/* Primary */}
        <div>
          <div className="text-xs text-ts uppercase tracking-wide mb-2">Primary Training</div>
          <div className="space-y-1 text-sm">
            {s.primaryTypes?.length   && <div><span className="text-ts">Types: </span>{s.primaryTypes.join(', ')}</div>}
            {s.primaryRpe != null     && <div><span className="text-ts">RPE: </span>{s.primaryRpe}</div>}
            {s.primaryDuration != null && <div><span className="text-ts">Duration: </span>{s.primaryDuration} min</div>}
            {s.primaryLoad != null    && <div><span className="text-ts">Load: </span>{s.primaryLoad} AU</div>}
          </div>
        </div>

        {/* Secondary */}
        {(s.secondaryTypes?.length > 0 || s.secondaryDuration != null || s.secondaryRpe != null) && (
          <div>
            <div className="text-xs text-ts uppercase tracking-wide mb-2">Secondary Training</div>
            <div className="space-y-1 text-sm">
              {s.secondaryTypes?.length > 0 && <div><span className="text-ts">Types: </span>{s.secondaryTypes.join(', ')}</div>}
              {s.secondaryRpe != null && <div><span className="text-ts">RPE: </span>{s.secondaryRpe}</div>}
              {s.secondaryDuration != null && <div><span className="text-ts">Duration: </span>{s.secondaryDuration} min</div>}
              {s.secondaryLoad != null && <div><span className="text-ts">Load: </span>{s.secondaryLoad} AU</div>}
            </div>
          </div>
        )}

        {/* Skill */}
        {(s.skillTypes?.length > 0 || s.skillSubTypes?.length > 0) && (
          <div>
            <div className="text-xs text-ts uppercase tracking-wide mb-2">Skill / Supplemental</div>
            <div className="space-y-1 text-sm">
              {s.skillTypes?.length > 0 && <div><span className="text-ts">Types: </span>{s.skillTypes.join(', ')}</div>}
              {s.skillRpe != null      && <div><span className="text-ts">RPE: </span>{s.skillRpe}</div>}
              {s.skillDuration != null && <div><span className="text-ts">Duration: </span>{s.skillDuration} min</div>}
              {s.skillSubTypes?.length > 0 && <div><span className="text-ts">Subordinate Types: </span>{s.skillSubTypes.join(', ')}</div>}
              {s.skillSubRpe != null && <div><span className="text-ts">Subordinate RPE: </span>{s.skillSubRpe}</div>}
              {s.skillSubDuration != null && <div><span className="text-ts">Subordinate Duration: </span>{s.skillSubDuration} min</div>}
            </div>
          </div>
        )}

        {/* Notes */}
        {s.notes && (
          <div>
            <div className="text-xs text-ts uppercase tracking-wide mb-1">Notes</div>
            <p className="text-sm text-ts">{s.notes}</p>
          </div>
        )}
      </div>
    </div>
  );
}
