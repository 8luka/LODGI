import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["short", "long", "button"]

  toggle() {
    const isExpanded = this.longTarget.style.display !== "none"

    this.shortTarget.style.display = isExpanded ? "block" : "none"
    this.longTarget.style.display = isExpanded ? "none" : "block"
    this.buttonTarget.textContent = isExpanded ? "Show more ›" : "Show less ›"
  }
}
