import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "endDate"]

  connect() {
    // Set minimum date to today
    const today = new Date().toISOString().split("T")[0]
    this.startDateTarget.min = today
    this.endDateTarget.min = today

    // To disable specific dates, see onChange below
    // this.disabledDates = ["2026-07-10", "2026-07-11"]
    this.disabledDates = []
  }

  onChange(event) {
    const input = event.target

    // Reject disabled dates
    if (this.disabledDates.includes(input.value)) {
      input.value = ""
      return
    }

    if (input === this.startDateTarget) {
      // End date can't be before start date
      this.endDateTarget.min = input.value
      if (this.endDateTarget.value && this.endDateTarget.value <= input.value) {
        this.endDateTarget.value = ""
      }
    }
  }
}
