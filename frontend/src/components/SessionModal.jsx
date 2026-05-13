import React from 'react';
import { fmtDate, fmtNum } from '../utils/fmt';

const MOTIVATION_LABELS = {
  very_low:  'Very Low — Hard to even start',
  low:       'Low — Going through the motions',
  moderate:  'Moderate — Neutral, consistent effort',
  high:      'High — Enthusiastic and focused',
  very_high: 'Very High — Highly driven and excited',
};

const APPETITE_LABELS = {
  no_change:  'No change',
  decreased:  'Decreased appetite',
  increased:  'Increased appetite',
};

const EXTERNAL_FACTOR_LABELS = {
  academic:     'Academic / Study Pressure',
  family:       'Family Issues',
  relationship: 'Relationship Concerns',
  financial:    'Financial Stress',
  injury:       'Injury / Physical Health',
  coach_team:   'Coach / Team Dynamics',
  none:         'None / Not Applicable',
};

const PSYCH_LABELS = {
  yes_urgent:    'Yes, urgently',
  yes_this_week: 'Yes, sometime this week',
  maybe:         'Maybe, unsure',
  no:            'No, I am fine',
};

const SYMPTOM_LABELS = {
  heavy_legs:       'Heavy legs / limbs',
  headache:         'Persistent headache',
  loss_of_appetite: 'Loss of appetite',
  increased_hr:     'Increased resting heart rate',
  slow_recovery:    'Slow recovery after exertion',
  frequent_illness: 'Frequent minor illness',
  joint_pain:       'Joint pain',
  none:             'None of the above',
};

const PERF_LABELS = {
  significant: 'Yes, significant decrease',
  slight:      'Yes, slight decrease',
  stable:      'No, performance is stable',
  improved:    'No, performance has improved',
};

function InfoRow({ label, value }) {
  if (value == null || value === '' || (Array.isArray(value) && value.length === 0)) return null;
  return (
    <div className="flex gap-1 text-sm">
      <span className="text-ts shrink-0">{label}:</span>
      <span className="text-tp">{Array.isArray(value) ? value.join(', ') : String(value)}</span>
    </div>
  );
}

export default function SessionModal({ session: s, onClose }) {
  if (!s) return null;

  const hasExtended = s.moodMotivation || s.moodAppetite || s.fatigueSymptoms?.length ||
    s.fatiguePerformanceDecrease || s.moodNeedsPsychologist;

  return (
    <div
      className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        className="bg-surface border border-bdr rounded-2xl w-full max-w-lg p-6 space-y-5 overflow-y-auto max-h-[90vh]"
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

        {/* Sleep */}
        {(s.sleepTimeToBed || s.sleepWakeUpTime || s.sleepDuration != null || s.sleepDisturbances != null) && (
          <div>
            <div className="text-xs text-ts uppercase tracking-wide mb-2">Sleep Details</div>
            <div className="bg-card rounded-xl p-4 space-y-1.5">
              <div className="grid grid-cols-3 gap-2 mb-2">
                {s.sleepTimeToBed && (
                  <div className="text-center">
                    <div className="text-[10px] text-ts">Time to Bed</div>
                    <div className="text-sm font-bold text-tp">{s.sleepTimeToBed}</div>
                  </div>
                )}
                {s.sleepWakeUpTime && (
                  <div className="text-center">
                    <div className="text-[10px] text-ts">Wake-up</div>
                    <div className="text-sm font-bold text-tp">{s.sleepWakeUpTime}</div>
                  </div>
                )}
                {s.sleepDuration != null && (
                  <div className="text-center">
                    <div className="text-[10px] text-ts">Duration</div>
                    <div className="text-sm font-bold text-tp">{s.sleepDuration} hrs</div>
                  </div>
                )}
              </div>
              <InfoRow label="Disturbances" value={s.sleepDisturbances ? (s.sleepDisturbanceDetails || 'Yes') : 'None'} />
              {(s.sleepRoomTemp || s.sleepRoomNoise || s.sleepRoomLight) && (
                <InfoRow
                  label="Room Conditions"
                  value={[s.sleepRoomTemp, s.sleepRoomNoise, s.sleepRoomLight].filter(Boolean).join(', ')}
                />
              )}
            </div>
          </div>
        )}

        {/* Mood */}
        {hasExtended && (s.moodMotivation || s.moodAppetite || s.moodExternalFactors?.length || s.moodNeedsPsychologist) && (
          <div>
            <div className="text-xs text-ts uppercase tracking-wide mb-2">Mood Assessment</div>
            <div className="bg-card rounded-xl p-4 space-y-1.5">
              <InfoRow label="Motivation"       value={MOTIVATION_LABELS[s.moodMotivation]} />
              <InfoRow label="Appetite"         value={APPETITE_LABELS[s.moodAppetite]} />
              <InfoRow
                label="External Factors"
                value={(s.moodExternalFactors || []).map(k => EXTERNAL_FACTOR_LABELS[k]).filter(Boolean)}
              />
              <InfoRow label="Psychologist"     value={PSYCH_LABELS[s.moodNeedsPsychologist]} />
            </div>
          </div>
        )}

        {/* Fatigue */}
        {hasExtended && (s.fatigueSymptoms?.length || s.fatiguePerformanceDecrease) && (
          <div>
            <div className="text-xs text-ts uppercase tracking-wide mb-2">Fatigue Assessment</div>
            <div className="bg-card rounded-xl p-4 space-y-1.5">
              <InfoRow
                label="Symptoms"
                value={(s.fatigueSymptoms || []).map(k => SYMPTOM_LABELS[k]).filter(Boolean)}
              />
              <InfoRow label="Performance"     value={PERF_LABELS[s.fatiguePerformanceDecrease]} />
              <InfoRow label="Description"     value={s.fatiguePerformanceDescription} />
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
