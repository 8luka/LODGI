// app/javascript/scoring/score.js
//
// The fit-score formula (specs: score_formula_spec.md + score_normalization_spec.md).
// Pure functions — no DOM access, no async, no side effects.
//
// Normalization now happens SERVER-SIDE (score_normalization_spec.md): the engine receives
// `normalizedInputs`, a map of pre-normalized [0, 1] values where higher is always better.
// It runs a plain weighted average over the active terms — it never sees raw distances/times,
// so the old f_* sub-score functions are gone. Drives the live re-rank entirely in the browser.

const TOGGLE_WEIGHT = 0.5; // Tunable: see §7. Fixed weight each active toggle contributes.

// The 9 toggle categories, each mapped to the normalizedInputs field it reads.
// `field(n)` returns the [0, 1] sub-score for that category (or null when data is absent).
const TOGGLE_TERMS = [
  { key: "convenience_store",  label: "Convenience",  field: (n) => n.konbini },
  { key: "supermarket",        label: "Supermarket",  field: (n) => n.supermarket },
  { key: "atm",                label: "ATM",          field: (n) => n.atm },
  { key: "cafe",               label: "Café",         field: (n) => n.cafe },
  { key: "restaurant",         label: "Restaurant",   field: (n) => n.restaurant },
  { key: "bar",                label: "Bar",          field: (n) => n.bar },
  { key: "park",               label: "Park",         field: (n) => ((n.park_nearest ?? 0) + (n.park_fifth ?? 0)) / 2 },
  { key: "gym",                label: "Gym",          field: (n) => n.gym },
  { key: "tourist_attraction", label: "Tourist",      field: (n) => n.tourist },
];

// ── Term collection ─────────────────────────────────────────────────────────────────
// Returns the array of active { label, weight, subscore } terms for the given inputs.
// A term is active iff its slider is non-zero / its toggle is on (commute also requires an anchor).
// All sub-scores come straight from `normalizedInputs` — already in [0, 1], higher = better.

function collectTerms({ normalizedInputs, sliders, toggles, hasAnchor }) {
  const terms = [];
  const n = normalizedInputs || {};

  // Slider terms
  // Commute needs an anchor AND cached travel times. n.commute is absent (undefined) until the
  // anchor's times are cached — for a brand-new anchor (e.g. a fresh map pin) that lags the page.
  // Skip the term while it's absent so the slider stays inert instead of scoring every property
  // against a 0 subscore (which would drag all scores down uniformly). A property with no route
  // normalizes to 0, not undefined, so genuinely-unreachable listings still count.
  if (sliders.commute > 0 && hasAnchor && n.commute != null) {
    terms.push({ label: "Commute", weight: sliders.commute / 3.0, subscore: n.commute });
  }
  if (sliders.peace_quiet > 0) {
    terms.push({ label: "Peace & quiet", weight: sliders.peace_quiet / 3.0, subscore: n.peace_quiet ?? 0.5 });
  }
  if (sliders.near_station > 0) {
    terms.push({ label: "Near station", weight: sliders.near_station / 3.0, subscore: n.station ?? 0 });
  }

  // Toggle terms — each active toggle adds one term with the fixed TOGGLE_WEIGHT.
  for (const t of TOGGLE_TERMS) {
    if (toggles[t.key]) {
      terms.push({ label: t.label, weight: TOGGLE_WEIGHT, subscore: t.field(n) ?? 0 });
    }
  }

  return terms;
}

function rawFractionFromTerms(terms) {
  if (terms.length === 0) return null; // caller maps this to the neutral default
  const numerator = terms.reduce((sum, t) => sum + t.weight * t.subscore, 0);
  const denominator = terms.reduce((sum, t) => sum + t.weight, 0);
  return numerator / denominator;
}

// ── Public API ──────────────────────────────────────────────────────────────────────

// computeScore(inputs) → integer 0–100. Neutral 50 when no terms are active.
function computeScore(inputs) {
  const raw = rawFractionFromTerms(collectTerms(inputs));
  if (raw == null) return 50;
  return Math.round(100 * raw);
}

// describeScore(inputs) → { score, terms: [{ label, weight, subscore, contribution }] }
// Used by the §7.4 debug breakdown. contribution = weight × subscore (pre-normalization).
function describeScore(inputs) {
  const terms = collectTerms(inputs).map((t) => ({
    ...t,
    contribution: t.weight * t.subscore,
  }));
  return { score: computeScore(inputs), terms };
}

export {
  computeScore,
  describeScore,
  TOGGLE_WEIGHT,
};
