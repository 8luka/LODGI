import { Controller } from "@hotwired/stimulus"
import { describeScore } from "scoring/score"
import { buildCompareRows, LIFE_ORDER, DEFAULT_LIFE_CATEGORIES } from "scoring/compare_content"
import { isAvailableForCheckin } from "scoring/availability"

// Fit-score → color, same buckets as the map (maps_controller.js SCORE_COLORS).
const SCORE_COLORS = [
  { min: 70, color: "#2e7d32" },
  { min: 40, color: "#f5a623" },
  { min: 0,  color: "#9e9e9e" },
]

// Favorites comparison workspace. Reuses the map's scoring engine + the shared priorities panel to
// live-score every saved listing: each card mirrors the map popup (fit + commute/station/lively)
// and the show page's "your life from here" (nearby POIs). Sliders/toggles re-rank the cards and
// reflow rows between the scored area and the expandable; the price/availability hard filters
// show/hide cards. Connects to data-controller="favorites".
export default class extends Controller {
  static values = {
    properties: Array,
    anchor: Object,
    normalizedInputs: { type: Object, default: {} },
    checkin: { type: String, default: "" },
  }
  static targets = ["grid", "card", "priceFilter", "priceValue", "availabilityFilter", "count"]

  connect() {
    this.filterTimeout = null
    this.extraOpen = false // expandable state is shared across all cards (toggled together)
    this.scoresById = {}
    this.propertiesById = {}
    this.propertiesValue.forEach((p) => { this.propertiesById[p.id] = p })
    this.priorities = this.readPriorities()
    // Default the availability box to checked when the trip has dates (mirrors maps_controller).
    this.availabilityFilterTargets.forEach((t) => { t.checked = Boolean(this.checkinValue) })
    this.render()
    this.applyFilters()
  }

  // Live re-rank: the priorities panel emits priorities:changed on every slider/toggle move.
  // We re-score + reflow rows, then re-apply the hard filters so the visible set + order stay right.
  rescore(event) {
    this.priorities = event?.detail?.weights
      ? { weights: event.detail.weights, categories: event.detail.categories || [] }
      : this.readPriorities()
    this.render()
    this.applyFilters()
  }

  // Read current slider weights + active toggle categories from the panel DOM (same selectors as
  // maps_controller). Initial paint only — live updates thereafter arrive via priorities:changed.
  readPriorities() {
    const weights = { commute: 0, quiet: 0, station: 0 }
    document.querySelectorAll('[data-priorities-panel-target="sliderInput"]').forEach((s) => {
      if (s.dataset.key in weights) weights[s.dataset.key] = Number(s.value)
    })
    const categories = [...document.querySelectorAll('[data-priorities-panel-target="toggleInput"]')]
      .filter((t) => t.checked)
      .map((t) => t.dataset.category)
    return { weights, categories }
  }

  // Score-engine input for one property from the live priorities (v1 engine; SCORING_V2 is off).
  scoreArgs(property) {
    const w = this.priorities.weights
    const active = this.priorities.categories || []
    const toggles = {}
    LIFE_ORDER.forEach((c) => { toggles[c] = active.includes(c) })
    return {
      normalizedInputs: this.normalizedInputsValue[property.id] || {},
      hasAnchor: !!(this.anchorValue?.id),
      sliders: { commute: w.commute || 0, peace_quiet: w.quiet || 0, near_station: w.station || 0 },
      toggles,
    }
  }

  // Re-score + repaint every card's dynamic regions, then re-sort by fit.
  render() {
    const w = this.priorities.weights
    const cats = this.priorities.categories || []
    // No toggles → surface the default daily-life trio (like the show page); the rest expand.
    const shownCategories = cats.length ? cats : DEFAULT_LIFE_CATEGORIES
    const hasAnchor = !!(this.anchorValue?.id)
    const anchorName = this.anchorValue?.name

    this.cardTargets.forEach((card) => {
      const property = this.propertiesById[Number(card.dataset.propertyId)]
      if (!property) return

      const { score, terms } = describeScore(this.scoreArgs(property))
      const hasTerms = terms.length > 0
      // -1 sinks the "no priorities yet" (neutral) cards to the bottom of the ranking.
      this.scoresById[property.id] = hasTerms ? score : -1

      this.paintCard(card, property, { w, shownCategories, hasAnchor, anchorName, hasTerms, score })
    })

    this.sortCards()
  }

  paintCard(card, property, { w, shownCategories, hasAnchor, anchorName, hasTerms, score }) {
    const { sliderRows, lifeRows } = buildCompareRows({
      property, weights: w, shownCategories, hasAnchor, anchorName,
    })

    // Fit badge — real number + color when something is scored; "—" + a prompt otherwise.
    const fitEl = card.querySelector("[data-fav-fit]")
    if (fitEl) {
      fitEl.textContent = hasTerms ? score : "—"
      fitEl.style.color = hasTerms ? this.colorFor(score) : SCORE_COLORS[SCORE_COLORS.length - 1].color
    }
    const msgEl = card.querySelector("[data-fav-message]")
    if (msgEl) msgEl.hidden = hasTerms

    // Scored area: surfaced slider rows (commute always; station/lively when their slider is up).
    const scoredEl = card.querySelector("[data-fav-scored]")
    if (scoredEl) {
      scoredEl.innerHTML = sliderRows.filter((r) => r.selected).map((r) => this.metricRow(r)).join("")
    }

    // "Your life from here": the surfaced toggle categories (or the default trio).
    const lifeShown = lifeRows.filter((r) => r.selected)
    const lifeEl = card.querySelector("[data-fav-life]")
    if (lifeEl) lifeEl.innerHTML = lifeShown.map((r) => this.lifeRow(r)).join("")
    const lifeWrap = card.querySelector("[data-fav-life-wrap]")
    if (lifeWrap) lifeWrap.hidden = lifeShown.length === 0

    // Expandable: everything not surfaced above (un-scored sliders + un-toggled categories).
    const extra = [
      ...sliderRows.filter((r) => !r.selected).map((r) => this.metricRow(r)),
      ...lifeRows.filter((r) => !r.selected).map((r) => this.lifeRow(r)),
    ]
    const extraEl = card.querySelector("[data-fav-extra]")
    if (extraEl) extraEl.innerHTML = extra.join("")
    const extraWrap = card.querySelector("[data-fav-extra-wrap]")
    if (extraWrap) extraWrap.hidden = extra.length === 0
    this.syncExtra(card) // keep this card's open/closed in step with the shared state
  }

  // Scored slider row (commute / station / lively). Accent tints the icon (teal / amber).
  metricRow(r) {
    return `
      <div class="compare-row is-${r.accent}">
        <iconify-icon icon="${r.icon}"></iconify-icon>
        <span>${this.esc(r.text)}</span>
      </div>`
  }

  // "Your life from here" row (nearby POIs), same icon + text shape, muted icon.
  lifeRow(r) {
    return `
      <div class="compare-row">
        <iconify-icon icon="${r.icon}"></iconify-icon>
        <span>${this.esc(r.text)}</span>
      </div>`
  }

  // Expand / collapse the extra section on EVERY card together, so the user can compare the full
  // breakdown side by side. The shared state survives re-renders (paintCard re-applies it).
  toggleExtra() {
    this.extraOpen = !this.extraOpen
    this.cardTargets.forEach((card) => this.syncExtra(card))
  }

  // Apply the shared expand state to one card's extra body + toggle button.
  syncExtra(card) {
    const body = card.querySelector("[data-fav-extra]")
    const btn = card.querySelector(".compare-more__toggle")
    if (!body || !btn) return
    body.hidden = !this.extraOpen
    btn.setAttribute("aria-expanded", String(this.extraOpen))
    btn.classList.toggle("is-open", this.extraOpen)
    const label = btn.querySelector("[data-fav-more-label]")
    if (label) label.textContent = this.extraOpen ? "Show less" : "Show more"
  }

  // Price + availability hard filters: hide cards that don't match, then refresh the count.
  applyFilters(event) {
    const priceSource = this.priceFilterTargets.find((t) => t === event?.target) || this.priceFilterTargets[0]
    const maxPrice = priceSource ? Number(priceSource.value) : Infinity
    this.priceFilterTargets.forEach((t) => { t.value = maxPrice })
    this.priceValueTargets.forEach((t) => { t.textContent = `¥${maxPrice.toLocaleString()}` })

    const availSource = this.availabilityFilterTargets.find((t) => t === event?.target) || this.availabilityFilterTargets[0]
    const availableOnly = availSource ? availSource.checked : false
    this.availabilityFilterTargets.forEach((t) => { t.checked = availableOnly })

    this.cardTargets.forEach((card) => {
      const property = this.propertiesById[Number(card.dataset.propertyId)]
      if (!property) return
      const matchesPrice = Number(property.price) <= maxPrice
      const matchesAvail = !availableOnly || isAvailableForCheckin(property.availability, this.checkinValue)
      const show = matchesPrice && matchesAvail
      card.hidden = !show
    })
    this.updateCount()
  }

  debouncedApplyFilters(event) {
    clearTimeout(this.filterTimeout)
    this.filterTimeout = setTimeout(() => this.applyFilters(event), 200)
  }

  // Reorder the card nodes in the grid by fit score (desc); hidden cards just sink in place.
  sortCards() {
    if (!this.hasGridTarget) return
    const cards = [...this.cardTargets].sort((a, b) => (
      (this.scoresById[Number(b.dataset.propertyId)] ?? -1) - (this.scoresById[Number(a.dataset.propertyId)] ?? -1)
    ))
    cards.forEach((card) => this.gridTarget.appendChild(card))
  }

  // Always the true number of saved homes (filters hide cards but don't change what you've saved).
  updateCount() {
    if (!this.hasCountTarget) return
    const total = this.cardTargets.length
    this.countTarget.textContent = `${total} saved home${total === 1 ? "" : "s"} in Tokyo`
  }

  colorFor(score) {
    return (SCORE_COLORS.find((b) => score >= b.min) || SCORE_COLORS[SCORE_COLORS.length - 1]).color
  }

  // Escape dynamic strings (anchor / station / place names can be user-set) before injecting.
  esc(s) {
    return String(s).replace(/[&<>"']/g, (c) => (
      { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
    ))
  }
}
