import { Controller } from "@hotwired/stimulus"

const PRIORITY_LABELS = ["Doesn't matter", "Nice to have", "Important", "Top priority"]

// Right rail: importance-weight sliders + category toggles
// Sliders use a 0–3 scale the scoring engine + live re-rank will listen to.
// Toggles also drive the maps POI flow via maps#toggleCategory on each input.
// Connects to data-controller="priorities-panel"
export default class extends Controller {
  static targets = ["sliderInput", "sliderVal", "toggleInput"]
  static values = {
    anchored: { type: Boolean, default: false },
    updateUrl: String,
    selectedPlaces: { type: Array, default: [] },
    placesUrl: String
  }

  connect() {
    this.sliderInputTargets.forEach((s) => this.syncLabel(s))
    this.toggleInputTargets.forEach((t) => {
      if (t.dataset.placeLabel && this.selectedPlacesValue.includes(t.dataset.placeLabel)) {
        t.checked = true
      }
    })
    this.setAnchored({ detail: { anchored: this.anchoredValue } })
  }

  onSlider(event) {
    const slider = event.currentTarget
    this.syncLabel(slider)
    this.persist(slider.dataset.key, slider.value)
    this.emitChange()
  }

  onToggle() {
    this.persistPlaces()
    this.emitChange()
  }

  // Update a slider's text label ("Important", etc.) from its current 0–3 value.
  syncLabel(slider) {
    const val = slider.closest(".prio-slider")?.querySelector(".prio-slider__val")
    if (val) val.textContent = PRIORITY_LABELS[slider.value] ?? slider.value
  }

  // PATCH the full current set of checked place labels onto the session inquiry.
  persistPlaces() {
    if (!this.hasPlacesUrlValue) return
    const labels = this.toggleInputTargets
      .filter((t) => t.checked && t.dataset.placeLabel)
      .map((t) => t.dataset.placeLabel)
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.placesUrlValue, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ selected_places: labels })
    })
  }

  // PATCH a single slider move onto the session inquiry. key maps to "#{key}_weight".
  persist(key, value) {
    if (!this.hasUpdateUrlValue) return
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.updateUrlValue, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ key, value })
    })
  }

  reset() {
    this.sliderInputTargets.forEach((s) => {
      const def = s.getAttribute("value") || "1"
      s.value = def
      this.syncLabel(s)
    })
    this.toggleInputTargets.forEach((t) => {
      if (t.checked) {
        t.checked = false
        t.dispatchEvent(new Event("change", { bubbles: true }))
      }
    })
    this.emitChange()
  }

  setAnchored(event) {
    this.anchoredValue = !!event.detail?.anchored
  }

  emitChange() {
    const weights = {}
    this.sliderInputTargets.forEach((s) => { weights[s.dataset.key] = Number(s.value) })
    const categories = this.toggleInputTargets.filter((t) => t.checked).map((t) => t.dataset.category)
    this.dispatch("changed", { prefix: "priorities", detail: { weights, categories } })
  }
}
