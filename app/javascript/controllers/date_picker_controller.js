import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "endDate"]

  connect() {
    const today = new Date().toISOString().split("T")[0]
    this.startDateTarget.min = today
    this.endDateTarget.min = this.startDateTarget.value || today
    this.disabledDates = []
  }

  onChange(event) {
    const input = event.target

    if (this.disabledDates.includes(input.value)) {
      input.value = ""
      return
    }

    if (input === this.startDateTarget) {
      this.endDateTarget.min = input.value
      if (!this.endDateTarget.value || this.endDateTarget.value <= input.value) {
        this.endDateTarget.value = input.value
      }
    }
  }
}
