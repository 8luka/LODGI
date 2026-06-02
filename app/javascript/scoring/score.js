// app/javascript/scoring/score.js
//
// The fit-score formula (spec: score_formula_spec.md). Pure functions — no DOM access,
// no async, no side effects. Receives a property's data and the current user inputs and
// returns a 0–100 score. Drives the live re-rank entirely in the browser.

const TOGGLE_WEIGHT = 0.5; // Tunable: see §7. Fixed weight each active toggle contributes.

const NORMALIZATION_MODE = "realistic_max"; // or "calibrated" (§5) — single-switch constant.

// The 9 toggle categories, each mapped to the score_inputs field + sub-score it uses.
const TOGGLE_TERMS = [
  { key: "convenience_store",  label: "Convenience",  fn: (si) => f_proximity(si?.convenience_store?.nearest_m) },
  { key: "supermarket",        label: "Supermarket",  fn: (si) => f_proximity(si?.supermarket?.nearest_m) },
  { key: "atm",                label: "ATM",          fn: (si) => f_proximity(si?.atm?.nearest_m) },
  { key: "cafe",               label: "Café",         fn: (si) => f_density(si?.cafe?.tenth_m) },
  { key: "restaurant",         label: "Restaurant",   fn: (si) => f_density(si?.restaurant?.tenth_m) },
  { key: "bar",                label: "Bar",          fn: (si) => f_density(si?.bar?.tenth_m) },
  { key: "park",               label: "Park",         fn: (si) => f_park(si?.park?.nearest_m, si?.park?.fifth_m) },
  { key: "gym",                label: "Gym",          fn: (si) => f_proximity(si?.gym?.nearest_m) },
  { key: "tourist_attraction", label: "Tourist",      fn: (si) => f_density(si?.tourist_attraction?.tenth_m) },
];

// ── Sub-score functions — all return [0, 1], all null-safe ──────────────────────────

function f_commute(time_minutes) {
  if (time_minutes == null) return 0.0;
  if (time_minutes <= 15) return 1.0;
  if (time_minutes >= 60) return 0.0;
  return 1.0 - (time_minutes - 15) / 45.0;
}

// Peace & quiet is precomputed at seed time; read it straight through (neutral 0.5 if absent).
function f_quiet(peace_quiet_score) {
  return peace_quiet_score ?? 0.5;
}

function f_station(walk_minutes) {
  if (walk_minutes == null) return 0.0;
  if (walk_minutes <= 3) return 1.0;
  if (walk_minutes >= 15) return 0.0;
  return 1.0 - (walk_minutes - 3) / 12.0;
}

function f_proximity(nearest_m) {
  if (nearest_m == null) return 0.0;
  if (nearest_m <= 100) return 1.0;
  if (nearest_m >= 1000) return 0.0;
  return 1.0 - (nearest_m - 100) / 900.0;
}

function f_density(tenth_m) {
  if (tenth_m == null) return 0.0;
  if (tenth_m <= 200) return 1.0;
  if (tenth_m >= 1200) return 0.0;
  return 1.0 - (tenth_m - 200) / 1000.0;
}

function f_park(nearest_m, fifth_m) {
  if (nearest_m == null) return 0.0;
  const proximity_part = nearest_m <= 200 ? 1.0
                       : nearest_m >= 1500 ? 0.0
                       : 1.0 - (nearest_m - 200) / 1300.0;
  if (fifth_m == null) return proximity_part * 0.6; // partial signal if sparse data
  const density_part = fifth_m <= 800 ? 1.0
                     : fifth_m >= 2500 ? 0.0
                     : 1.0 - (fifth_m - 800) / 1700.0;
  return 0.6 * proximity_part + 0.4 * density_part;
}

// ── Term collection ─────────────────────────────────────────────────────────────────
// Returns the array of active { label, weight, subscore } terms for the given inputs.
// A term is active iff its slider is non-zero / its toggle is on (commute also requires an anchor).

function collectTerms({ scoreInputs, travelTimeToAnchor, sliders, toggles }) {
  const terms = [];
  const si = scoreInputs || {};

  // Slider terms
  if (sliders.commute > 0 && travelTimeToAnchor != null) {
    terms.push({ label: "Commute", weight: sliders.commute / 3.0, subscore: f_commute(travelTimeToAnchor) });
  }
  if (sliders.peace_quiet > 0) {
    terms.push({ label: "Peace & quiet", weight: sliders.peace_quiet / 3.0, subscore: f_quiet(si.peace_quiet_score) });
  }
  if (sliders.near_station > 0) {
    terms.push({ label: "Near station", weight: sliders.near_station / 3.0, subscore: f_station(si?.transit_station?.time_to_station) });
  }

  // Toggle terms — each active toggle adds one term with the fixed TOGGLE_WEIGHT.
  for (const t of TOGGLE_TERMS) {
    if (toggles[t.key]) {
      terms.push({ label: t.label, weight: TOGGLE_WEIGHT, subscore: t.fn(si) });
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

function normalize(rawFraction) {
  // rawFraction is in [0, 1].
  if (NORMALIZATION_MODE === "realistic_max") {
    return Math.round(100 * rawFraction);
  }
  // calibrated mode is applied across a property set, not per-property (see §5); the
  // per-property path falls back to realistic_max.
  return Math.round(100 * rawFraction);
}

// ── Public API ──────────────────────────────────────────────────────────────────────

// computeScore(inputs) → integer 0–100. Neutral 50 when no terms are active.
function computeScore(inputs) {
  const raw = rawFractionFromTerms(collectTerms(inputs));
  if (raw == null) return 50;
  return normalize(raw);
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
  f_commute,
  f_quiet,
  f_station,
  f_proximity,
  f_density,
  f_park,
};
