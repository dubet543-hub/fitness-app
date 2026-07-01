// Body-composition compute + grading — ported verbatim from the mobile app
// (lib/screens/body_composition_screen.dart) so the admin shows the SAME result
// the athlete sees. Everything is derived from the stored input measurements.

const log10 = (x) => Math.log(x) / Math.log(10);

export function computeBCA({ isMale, weightKg, heightCm, neckCm, abdomenCm, hipCm }) {
  if (!weightKg || !heightCm || !neckCm || !abdomenCm) return null;

  let bfPct;
  if (isMale) {
    const diff = abdomenCm - neckCm;
    if (diff <= 0) return null;
    bfPct = 86.010 * log10(diff) - 70.041 * log10(heightCm) + 36.0;
  } else {
    if (!hipCm || hipCm <= 0) return null;
    const sum = abdomenCm + hipCm - neckCm;
    if (sum <= 0) return null;
    bfPct = 163.305 * log10(sum) - 97.684 * log10(heightCm) - 78.387;
  }
  bfPct = Math.min(50, Math.max(2, bfPct));

  const bfKg = (weightKg * bfPct) / 100;
  const lbm  = weightKg - bfKg;

  const bmc             = lbm * 0.065;
  const lst             = lbm * 0.935;
  const tsm             = lst * 0.5829;
  const essentialOrgans = lst * 0.1230;
  const skinConnective  = lst * 0.1123;
  const nonMuscleFluid  = lst * 0.1818;
  const asm             = tsm * 0.75;
  const axial           = tsm * 0.25;

  const hm = heightCm / 100;

  return {
    isMale, weightKg, heightCm, neckCm, abdomenCm, hipCm,
    bfPercent: bfPct, bfKg, lbm, bmc, lst, tsm,
    essentialOrgans, skinConnective, nonMuscleFluid, asm, axial,
    smmPercent: (tsm / weightKg) * 100,
    smi: tsm / (hm * hm),
    relativeAsm: (asm / weightKg) * 100,
    mbr: lbm / bmc,
    ffmi: lbm / (hm * hm),
    appendicularToTotal: (asm / weightKg) * 100,
    axialToTotal: (axial / weightKg) * 100,
  };
}

// ── Grades (label + color) — mirror the mobile grading functions ──────────────

const RED = '#EF4444', GREEN = '#00CF74', BLUE = '#4AADFF', AMBER = '#F59E0B', PURPLE = '#9D8AFF';
const G = (label, color) => ({ label, color });

export function gradeBF(pct, male) {
  if (male) {
    if (pct < 5)   return G('Below Essential', RED);
    if (pct <= 13) return G('Elite / Athletic', GREEN);
    if (pct <= 17) return G('Good / Competitive', BLUE);
    if (pct <= 24) return G('Moderate / Transition', AMBER);
    return G('High', RED);
  }
  if (pct < 12)  return G('Below Essential', RED);
  if (pct <= 20) return G('Elite / Athletic', GREEN);
  if (pct <= 24) return G('Good / Competitive', BLUE);
  if (pct <= 31) return G('Moderate / Transition', AMBER);
  return G('High', RED);
}

export function gradeFFMI(v, male) {
  if (male) {
    if (v < 18)  return G('Below Average', RED);
    if (v < 20)  return G('Average / Untrained', AMBER);
    if (v < 22)  return G('Good / Athletic', BLUE);
    if (v < 24)  return G('Advanced / Excellent', GREEN);
    if (v <= 25) return G('Elite Natural Limit', PURPLE);
    return G('Exceptional Outlier', PURPLE);
  }
  if (v < 15)  return G('Below Average', RED);
  if (v < 18)  return G('Good Baseline', AMBER);
  if (v < 20)  return G('Advanced Athletic', BLUE);
  if (v < 22)  return G('Elite / Exceptional', GREEN);
  return G('Exceptional', PURPLE);
}

export function gradeSMM(pct, male) {
  if (male) {
    if (pct < 39) return G('Deficient – Risk Zone', RED);
    if (pct < 43) return G('Sub-Optimal / Lean', AMBER);
    if (pct < 48) return G('Optimal / Athletic', GREEN);
    return G('Elite / Hypertrophic', BLUE);
  }
  if (pct < 32) return G('Deficient – Risk Zone', RED);
  if (pct < 36) return G('Sub-Optimal / Lean', AMBER);
  if (pct < 40) return G('Optimal / Athletic', GREEN);
  return G('Elite / Hypertrophic', BLUE);
}

export function gradeSMI(v, male) {
  if (male) {
    if (v < 8.5)   return G('Deficient – Risk Zone', RED);
    if (v < 9.5)   return G('Sub-Optimal / Lean', AMBER);
    if (v <= 11.5) return G('Optimal / Athletic', GREEN);
    return G('Elite / Hypertrophic', BLUE);
  }
  if (v < 7.0)  return G('Deficient – Risk Zone', RED);
  if (v < 8.0)  return G('Sub-Optimal / Lean', AMBER);
  if (v <= 9.5) return G('Optimal / Athletic', GREEN);
  return G('Elite / Hypertrophic', BLUE);
}

export function gradeRelASM(pct, male) {
  if (male) {
    if (pct < 19.4) return G('Clinical Risk (Sarcopenic)', RED);
    if (pct < 26.0) return G('Low / Under-Conditioned', AMBER);
    if (pct < 31.5) return G('Average / Healthy Baseline', BLUE);
    if (pct < 35.0) return G('Well-Conditioned', GREEN);
    return G('Elite / Highly Conditioned', PURPLE);
  }
  if (pct < 15.0) return G('Clinical Risk (Sarcopenic)', RED);
  if (pct < 21.0) return G('Low / Under-Conditioned', AMBER);
  if (pct < 26.5) return G('Average / Healthy Baseline', BLUE);
  if (pct < 30.0) return G('Well-Conditioned', GREEN);
  return G('Elite / Highly Conditioned', PURPLE);
}

export function gradeMBR(v) {
  if (v < 15) return G('Critical – Under-Muscled', RED);
  if (v < 19) return G('Weak / Sedentary', AMBER);
  if (v < 24) return G('Normal / Healthy Baseline', BLUE);
  return G('Strong / Athletic Framework', GREEN);
}

export function gradeAppendicular(pct, male) {
  if (male) {
    if (pct < 44) return G('Grade 4 – At Risk', RED);
    if (pct < 49) return G('Grade 3 – Compact', AMBER);
    if (pct < 54) return G('Grade 2 – Balanced', GREEN);
    return G('Grade 1 – Distal Lever Dominant', BLUE);
  }
  if (pct < 42) return G('Grade 4 – At Risk', RED);
  if (pct < 47) return G('Grade 3 – Compact', AMBER);
  if (pct < 52) return G('Grade 2 – Balanced', GREEN);
  return G('Grade 1 – Distal Lever Dominant', BLUE);
}

export function gradeAxial(pct, male) {
  if (male) {
    if (pct < 40) return G('Grade 4 – Structural Insufficiency', RED);
    if (pct < 46) return G('Grade 3 – Elongated / Locomotive', AMBER);
    if (pct < 56) return G('Grade 2 – Balanced Core Base', GREEN);
    return G('Grade 1 – Rotational Anchor', BLUE);
  }
  if (pct < 42) return G('Grade 4 – Structural Insufficiency', RED);
  if (pct < 48) return G('Grade 3 – Elongated / Locomotive', AMBER);
  if (pct < 58) return G('Grade 2 – Balanced Core Base', GREEN);
  return G('Grade 1 – Rotational Anchor', BLUE);
}

// Overall interpretation profile + suggestions (mirrors the app's report).
export function interpret(r) {
  const male = r.isMale;
  const isAtRisk   = r.bfPercent > (male ? 24 : 31) || r.smmPercent < (male ? 39 : 32);
  const isAthletic = r.bfPercent <= (male ? 13 : 20) && r.smmPercent >= (male ? 43 : 36);
  const overallLabel = isAtRisk ? 'Sub-optimal / At-Risk' : isAthletic ? 'Optimal / Athletic' : 'Balanced / Developing';
  const overallColor = isAtRisk ? RED : isAthletic ? GREEN : AMBER;

  const actions = [];
  if (r.bfPercent > (male ? 17 : 24))
    actions.push('Nutrition: Create a modest caloric deficit (300–500 kcal/day) with high protein intake (≥1.8g/kg) to reduce body fat while preserving lean mass.');
  if (r.smmPercent < (male ? 43 : 36))
    actions.push('Exercise: Prioritise progressive resistance training (3–5 sessions/week) with compound lifts to increase skeletal muscle mass.');
  if (r.relativeAsm < (male ? 31.5 : 26.5))
    actions.push('Focus on limb strengthening — squats, lunges, deadlifts, and upper-body pulls to develop appendicular muscle mass.');
  if (actions.length === 0)
    actions.push('Maintain current training and nutrition protocols. Focus on consistency and progressive overload.');
  actions.push('Follow-up body composition assessment recommended in 8–12 weeks to track adaptations.');

  return { overallLabel, overallColor, actions, limbDominant: r.appendicularToTotal > r.axialToTotal };
}
