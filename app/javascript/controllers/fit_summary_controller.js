import { Controller } from "@hotwired/stimulus"
import { computeScore } from "scoring/score"
import { quietLabel } from "scoring/popup_content"

// Property show-page "fit summary" banner. Mirrors the map popup's primary rows (fit score +
// commute-to-anchor + nearest station + quiet character) for the property on the page, based on
// the CURRENT inquiry's saved weights/anchor (rendered once on connect — the show page is static).
// Reuses the same computeScore engine + quiet helpers as the map, so the score matches.
// NOTE: targets the active v1 scoring engine (MapsController::SCORING_V2 = false).

// Fit-score → color, same buckets as the map (maps_controller.js SCORE_COLORS).
const SCORE_COLORS = [
  { min: 70, color: "#2e7d32" },
  { min: 40, color: "#f5a623" },
  { min: 0,  color: "#9e9e9e" },
]

export default class extends Controller {
  static values = {
    normalizedInputs: { type: Object, default: {} },
    weights: { type: Object, default: {} },          // { commute, quiet, station } (0–3)
    hasAnchor: { type: Boolean, default: false },
    anchorName: { type: String, default: "" },
    scoreInputs: { type: Object, default: {} },
    travelTime: { type: Number, default: -1 },        // minutes to anchor; -1 = unknown/none
  }

  connect() {
    this.render()
  }

  render() {
    const w = this.weightsValue
    const si = this.scoreInputsValue
    const rows = []

    // Commute to anchor — only with an anchor + commute weight + a known travel time.
    if (this.hasAnchorValue && w.commute > 0 && this.travelTimeValue >= 0) {
      rows.push(this.rowHtml("tabler:briefcase", "teal",
        `${this.travelTimeValue} min`, `to ${this.anchorNameValue || "anchor"}`))
    }

    // Nearest station.
    const station = si.transit_station || {}
    if (w.station > 0 && station.station_name) {
      const mins = station.time_to_station
      const value = mins != null ? `${mins} min walk` : station.station_name
      const label = mins != null ? station.station_name : ""
      rows.push(this.rowHtml("tabler:train", "teal", value, label))
    }

    // Quiet character (no sub-label).
    if (w.quiet > 0) {
      const label = quietLabel(si.peace_quiet_score)
      if (label) rows.push(this.rowHtml("tabler:moon", "amber", label, ""))
    }

    this.element.innerHTML = rows.length === 0 ? this.emptyHtml() : this.cardHtml(rows)
  }

  // The user touched nothing yet → invite them to set up their trip via the navbar search.
  emptyHtml() {
    return `
      <div class="fit-summary__empty">
        <span class="fit-summary__empty-text">Tell us about your trip and we'll show how well this place fits.</span>
        <button type="button" class="fit-summary__cta" data-action="click->fit-summary#openSearch">
          Set up trip <iconify-icon icon="tabler:arrow-right"></iconify-icon>
        </button>
      </div>`
  }

  cardHtml(rows) {
    const score = computeScore({
      normalizedInputs: this.normalizedInputsValue,
      hasAnchor: this.hasAnchorValue,
      sliders: {
        commute: this.weightsValue.commute || 0,
        peace_quiet: this.weightsValue.quiet || 0,
        near_station: this.weightsValue.station || 0,
      },
      toggles: {},
    })

    return `
      <div class="fit-summary__card">
        <div class="fit-summary__score">
          <span class="fit-summary__num" style="color:${this.colorFor(score)};">${score}</span>
          <span class="fit-summary__fit">FIT</span>
        </div>
        <div class="fit-summary__metrics">${rows.join("")}</div>
      </div>
      <div class="fit-summary__foot">
        Based on your trip ·
        <a href="#" data-action="click->fit-summary#openSearch">Change search</a>
      </div>`
  }

  rowHtml(icon, accent, value, label) {
    return `
      <div class="fit-metric is-${accent}">
        <iconify-icon icon="${icon}"></iconify-icon>
        <div class="fit-metric__text">
          <div class="fit-metric__value">${this.esc(value)}</div>
          ${label ? `<div class="fit-metric__label">${this.esc(label)}</div>` : ""}
        </div>
      </div>`
  }

  // Escape dynamic strings (anchor/station names can be user-set) before injecting as HTML.
  esc(s) {
    return String(s).replace(/[&<>"']/g, (c) => (
      { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
    ))
  }

  colorFor(score) {
    return (SCORE_COLORS.find((b) => score >= b.min) || SCORE_COLORS[SCORE_COLORS.length - 1]).color
  }

  // Open the navbar trip-setup search (the same control the summary's data is based on).
  // stopPropagation: trip-setup adds a document click-listener on open that closes the panel on
  // any outside click — without this, our own click bubbles to it and closes it immediately.
  openSearch(event) {
    event?.preventDefault()
    event?.stopPropagation()
    document.querySelector('[data-trip-setup-target="toggle"]')?.click()
  }
}
