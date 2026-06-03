// app/javascript/scoring/popup_content.js
//
// Builds the dynamic body of the property map popup (the rows below the title + the
// fit-driven amenity lines). Pure functions — no DOM access, no async, no side effects.
// maps_controller.js fetches the server ERB shell, then injects buildPopupInfoHtml(...)
// into its [data-popup-info] container so the popup always reflects the LIVE slider /
// toggle / anchor state (which only exists client-side).
//
// Two row groups, mirroring the scoring engine (scoring/score.js):
//  • "primary" slider rows — commute-to-anchor, nearest station, quiet character. Each shows
//    only while its slider weight > 0 (commute also needs an anchor), so a row disappears
//    exactly when its term drops out of the score.
//  • "amenity" toggle rows — the nearest of each active category, walk-minutes, first 3 only.

// ──────────────────────────────────────────────────────────────────────────────────────
// EDITABLE — tune or delete me. Thresholds + copy live here so they're cheap to change.
// ──────────────────────────────────────────────────────────────────────────────────────

const WALK_M_PER_MIN = 80; // ~4.8 km/h. metres ÷ this → walking minutes.

// peace_quiet_score is 0 = lively … 1 = calm. Cutoffs tuned to the seeded spread (0.036–0.43,
// roughly even thirds). Ordered high → low; first band whose `min` is met wins. To drop the
// quiet row entirely, empty this array (quietLabel then returns null and the row is skipped).
const QUIET_BANDS = [
  { min: 0.18,  label: "Quiet residential street" },
  { min: 0.115, label: "Lively area · quiet street" },
  { min: 0,     label: "Lively area" },
];

// Per-category icon + label for the amenity rows. Icons match the priorities panel toggles.
const POI_ROWS = {
  convenience_store: { icon: "tabler:building-store",   label: "Convenience store" },
  supermarket:       { icon: "tabler:shopping-cart",    label: "Supermarket" },
  atm:               { icon: "tabler:building-bank",    label: "ATM" },
  cafe:              { icon: "tabler:coffee",           label: "Café" },
  restaurant:        { icon: "tabler:tools-kitchen-2",  label: "Restaurant" },
  bar:               { icon: "tabler:glass-full",       label: "Bar" },
  park:              { icon: "tabler:tree",             label: "Park" },
  gym:               { icon: "tabler:barbell",          label: "Gym" },
  tourist_attraction:{ icon: "tabler:camera",           label: "Tourist spot" },
};

const MAX_AMENITY_ROWS = 4; // keep the card from getting busy

// ──────────────────────────────────────────────────────────────────────────────────────
// Pure helpers
// ──────────────────────────────────────────────────────────────────────────────────────

// metres → "N min walk" (min 1). Returns null when distance is missing.
function walkMinutes(metres) {
  if (metres == null) return null;
  return Math.max(1, Math.round(metres / WALK_M_PER_MIN));
}

// peace_quiet_score (0..1) → label, or null when unknown / bands disabled.
function quietLabel(score) {
  if (score == null) return null;
  const band = QUIET_BANDS.find((b) => score >= b.min);
  return band ? band.label : null;
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
  ));
}

// One primary (slider-driven) row. `accent` tints the icon (teal for commute/station, amber
// for the quiet character row), matching the mockup.
function primaryRow(icon, text, accent) {
  return `
    <div class="popup-info-row is-primary is-${accent}">
      <iconify-icon icon="${icon}"></iconify-icon>
      <span>${escapeHtml(text)}</span>
    </div>`;
}

// One amenity chip for the "Nearby places you're tracking" panel (horizontal layout).
function amenityChip(icon, text) {
  return `
    <span class="popup-amenity">
      <iconify-icon icon="${icon}"></iconify-icon>
      <span>${escapeHtml(text)}</span>
    </span>`;
}

// Build both popup sections for one property from the live priorities + anchor state:
//   { primary, amenities } — HTML strings for the [data-popup-info] block and the
//   [data-popup-amenities] panel respectively (amenities is "" when no toggle is active).
//   property    — the client payload object (score_inputs, travel_time_to_anchor, nearest_poi_m)
//   priorities  — { weights: { commute, quiet, station }, categories: [active toggle keys] }
//   hasAnchor   — whether an anchor is currently set
function buildPopupSections({ property, priorities, hasAnchor, anchorName }) {
  const weights = priorities?.weights || {};
  const categories = priorities?.categories || [];
  const si = property.score_inputs || {};

  // ── Primary (slider-driven) rows — each shows only while its slider weight > 0 ──────
  const rows = [];
  const anchorTime = property.travel_time_to_anchor;
  if (hasAnchor && weights.commute > 0 && anchorTime != null) {
    const dest = anchorName ? ` to ${anchorName}` : " to anchor";
    rows.push(primaryRow("tabler:briefcase", `${anchorTime} min${dest}`, "teal"));
  }

  const station = si.transit_station || {};
  if (weights.station > 0 && station.station_name) {
    const mins = station.time_to_station;
    const tail = mins != null ? ` · ${mins} min walk` : "";
    rows.push(primaryRow("tabler:train", `${station.station_name}${tail}`, "teal"));
  }

  if (weights.quiet > 0) {
    const label = quietLabel(si.peace_quiet_score);
    if (label) rows.push(primaryRow("tabler:moon", label, "amber"));
  }

  // ── Amenity panel (toggle-driven) — first 3 active categories with known distance ───
  const nearest = property.nearest_poi_m || {};
  const chips = [];
  for (const cat of categories) {
    if (chips.length >= MAX_AMENITY_ROWS) break;
    const cfg = POI_ROWS[cat];
    const mins = walkMinutes(nearest[cat]);
    if (!cfg || mins == null) continue;
    chips.push(amenityChip(cfg.icon, `${cfg.label} · ${mins} min`));
  }

  const amenities = chips.length === 0 ? "" : `
    <div class="popup-amenities__label">Nearby places you're tracking</div>
    <div class="popup-amenities__items">${chips.join("")}</div>`;

  return { primary: rows.join(""), amenities };
}

export { buildPopupSections, walkMinutes, quietLabel };
