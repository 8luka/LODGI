// app/javascript/scoring/score_simplified.js
//
// The SIMPLIFIED fit-score engine (spec: simplified_scoring_spec.md). Parallel to score.js
// so the old multi-slider system stays switchable behind the SCORING_V2 flag.
//
// The split: commute and near-station are now HARD FILTERS (handled in maps_controller.js),
// not score terms. The score is driven by exactly two things — the single Peace & Quiet
// slider plus the 9 category toggles — over the same server-side relative normalization.
// Pure functions: no DOM access, no async, no side effects.

const TOGGLE_WEIGHT = 0.5; // Fixed weight each active toggle contributes. Tunable.

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
// All sub-scores come straight from `normalizedInputs` — already in [0, 1], higher = better.

function collectTerms({ normalizedInputs, peaceQuietSlider, toggles }) {
  const terms = [];
  const n = normalizedInputs || {};

  // The one remaining slider — keeps the old weight curve: slider_value / 3.0.
  if (peaceQuietSlider > 0) {
    terms.push({ label: "Peace & quiet", weight: peaceQuietSlider / 3.0, subscore: n.peace_quiet ?? 0.5 });
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
// Used by the ?debug=1 breakdown. contribution = weight × subscore.
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
