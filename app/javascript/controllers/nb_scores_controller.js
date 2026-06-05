import { Controller } from "@hotwired/stimulus"
import { describeScore } from "scoring/score"
import { LIFE_ORDER } from "scoring/compare_content"

// Fit-score → color, same buckets as the map (maps_controller.js SCORE_COLORS).
const SCORE_COLORS = [
  { min: 70, color: "#2e7d32" },
  { min: 40, color: "#f5a623" },
  { min: 0,  color: "#9e9e9e" },
]

// Shows each neighborhood listing's fit score, computed from the visitor's saved priorities. The
// neighborhood page has no priorities panel, so this renders once on connect (no live re-rank).
// A badge stays hidden unless its score has at least one active term (a slider raised or a toggle
// on) — matching the rest of the app: no priorities set → no score shown.
// Connects to data-controller="nb-scores".
export default class extends Controller {
  static values = {
    normalizedInputs: { type: Object, default: {} },
    hasAnchor: { type: Boolean, default: false },
    weights: { type: Object, default: {} },   // { commute, quiet, station } (0–3)
    categories: { type: Array, default: [] },  // active toggle categories
  }
  static targets = ["score"]

  connect() {
    const w = this.weightsValue
    const toggles = {}
    LIFE_ORDER.forEach((c) => { toggles[c] = this.categoriesValue.includes(c) })

    this.scoreTargets.forEach((el) => {
      const { score, terms } = describeScore({
        normalizedInputs: this.normalizedInputsValue[el.dataset.propertyId] || {},
        hasAnchor: this.hasAnchorValue,
        sliders: { commute: w.commute || 0, peace_quiet: w.quiet || 0, near_station: w.station || 0 },
        toggles,
      })
      if (terms.length === 0) return // user set nothing → leave the badge hidden

      el.textContent = `Fit ${score}`
      el.style.background = this.colorFor(score)
      el.style.color = "#fff"
      el.hidden = false
    })
  }

  colorFor(score) {
    return (SCORE_COLORS.find((b) => score >= b.min) || SCORE_COLORS[SCORE_COLORS.length - 1]).color
  }
}
