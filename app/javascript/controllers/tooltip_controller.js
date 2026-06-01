import { Controller } from "@hotwired/stimulus"

// For the hoverable tooltips in the right rail
export default class extends Controller {
  static values = { text: String }

  connect() {
    this.popup = document.createElement("div")
    this.popup.className = "tooltip-popup"
    this.popup.textContent = this.textValue
    document.body.appendChild(this.popup)
  }

  disconnect() {
    this.popup?.remove()
  }

  show() {
    const rect = this.element.getBoundingClientRect()
    const popupWidth = 200
    let left = rect.left + rect.width / 2 - popupWidth / 2
    left = Math.max(8, Math.min(left, window.innerWidth - popupWidth - 8))
    this.popup.style.left = `${left}px`

    if (rect.top < 80) {
      this.popup.style.top = `${rect.bottom + 8}px`
      this.popup.style.transform = ""
    } else {
      this.popup.style.top = `${rect.top - 8}px`
      this.popup.style.transform = "translateY(-100%)"
    }

    this.popup.classList.add("is-visible")
  }

  hide() {
    this.popup.classList.remove("is-visible")
  }
}
