import { Controller } from "@hotwired/stimulus"

// Generic collapse/expand for the left (shortlist) and right (priorities) rails.
// Toggles an .is-collapsed class (width animated in CSS) and flips the chevron.
// Connects to data-controller="rail"
export default class extends Controller {
  static targets = ["chevron"]
  static values = {
    side: String,
    collapsed: { type: Boolean, default: false }
  }

  toggle() {
    this.collapsedValue = !this.collapsedValue
  }

  collapsedValueChanged() {
    this.element.classList.toggle("is-collapsed", this.collapsedValue)
    if (!this.hasChevronTarget) return

    const left = this.sideValue === "left"

    const icon = left
      ? (this.collapsedValue ? "tabler:chevron-right" : "tabler:chevron-left")
      : (this.collapsedValue ? "tabler:chevron-left" : "tabler:chevron-right")
    this.chevronTarget.setAttribute("icon", icon)
  }
}
