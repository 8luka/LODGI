import { Controller } from "@hotwired/stimulus"

const PRIORITY_LABELS = ["Doesn't matter", "Nice to have", "Important", "Top priority"]

// Right rail: importance-weight sliders + category toggles
// Sliders use a 0–3 scale the scoring engine + live re-rank will listen to.
// Toggles also drive the maps POI flow via maps#toggleCategory on each input.
// Connects to data-controller="priorities-panel"
export default class extends Controller {
  static targets = ["sliderInput", "sliderVal", "toggleInput"]
  static values = { anchored: { type: Boolean, default: false } }

  connect() { this.setAnchored({ detail: { anchored: this.anchoredValue } }) }

  onSlider(event) {
    const slider = event.currentTarget
    const val = slider.closest(".prio-slider")?.querySelector(".prio-slider__val")
    if (val) val.textContent = PRIORITY_LABELS[slider.value] ?? slider.value
    this.emitChange()
  }

  onToggle() { this.emitChange() }

  reset() {
    this.sliderInputTargets.forEach((s) => {
      const def = s.getAttribute("value") || "1"
      s.value = def
      const val = s.closest(".prio-slider")?.querySelector(".prio-slider__val")
      if (val) val.textContent = PRIORITY_LABELS[Number(def)] ?? def
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
