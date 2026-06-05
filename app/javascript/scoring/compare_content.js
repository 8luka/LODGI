// app/javascript/scoring/compare_content.js
//
// Builds the two row groups of a favorites comparison card from the live priorities + anchor.
// Pure functions — no DOM access, no async, no side effects. The favorites controller renders the
// returned rows into the card's scored area vs its expandable.
//
// Row CONTENT is static per property (commute minutes, station name, quiet band, the precomputed
// "your life from here" text). Only `selected` (placement: scored area vs expandable) and the fit
// score change as the sliders/toggles move — so this just tags each row, it never recomputes text.

import { quietLabel } from "scoring/popup_content"

// Fixed essentials -> food -> lifestyle order; mirrors PropertiesHelper::LIFE_CATEGORIES and the
// priorities-panel toggle groups. Also serves as the toggle-category list for scoring.
const LIFE_ORDER = [
  "convenience_store", "supermarket", "atm",
  "cafe", "restaurant", "bar",
  "park", "gym", "tourist_attraction",
]

// Surfaced in "Your life from here" when the visitor has toggled nothing — mirrors
// PropertiesHelper::DEFAULT_LIFE_CATEGORIES (a sensible daily-life snapshot).
const DEFAULT_LIFE_CATEGORIES = ["convenience_store", "supermarket", "restaurant"]

// → { sliderRows, lifeRows }. Each row: { ...display fields, selected } where selected means
// "show in the scored area" (everything else drops into the expandable).
//   property        — favorites payload row { score_inputs, travel_time_to_anchor, life_rows }
//   weights         — { commute, quiet, station } (0–3) from the live sliders
//   shownCategories — toggle categories to surface up top (caller resolves the no-toggles default)
//   hasAnchor / anchorName — the current trip anchor
function buildCompareRows({ property, weights = {}, shownCategories = [], hasAnchor, anchorName }) {
  const si = property.score_inputs || {}
  const sliderRows = []

  // Commute — surfaced whenever an anchor is set and a travel time is cached, independent of the
  // commute slider (product decision). It therefore never lands in the expandable.
  const t = property.travel_time_to_anchor
  if (hasAnchor && t != null) {
    sliderRows.push({
      key: "commute", selected: true, icon: "tabler:briefcase", accent: "teal",
      text: `${t} min${anchorName ? ` to ${anchorName}` : " to anchor"}`,
    })
  }

  // Nearest station — scored only while the "Near a station" slider is up.
  const station = si.transit_station || {}
  if (station.station_name) {
    const m = station.time_to_station
    sliderRows.push({
      key: "station", selected: (weights.station || 0) > 0, icon: "tabler:train", accent: "teal",
      text: `${station.station_name}${m != null ? ` · ${m} min walk` : ""}`,
    })
  }

  // Lively / quiet character — scored only while the "Peace & quiet" slider is up.
  const ql = quietLabel(si.peace_quiet_score)
  if (ql) {
    sliderRows.push({
      key: "quiet", selected: (weights.quiet || 0) > 0, icon: "tabler:moon", accent: "amber", text: ql,
    })
  }

  // "Your life from here" rows — precomputed server-side (icon + text); selected = surfaced now.
  const life = property.life_rows || {}
  const lifeRows = LIFE_ORDER.filter((c) => life[c]).map((category) => ({
    category,
    selected: shownCategories.includes(category),
    icon: life[category].icon,
    text: life[category].text,
  }))

  return { sliderRows, lifeRows }
}

export { buildCompareRows, LIFE_ORDER, DEFAULT_LIFE_CATEGORIES }
