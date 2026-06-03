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

      if (
        !this.endDateTarget.value ||
        this.endDateTarget.value <= input.value
      ) {

        this.endDateTarget.value =
          input.value
      }
    }

    this.updateInquiryDates()
  }

  updateInquiryDates() {

    fetch("/inquiry/dates", {
    method: "PATCH",

    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token":
        document.querySelector(
          'meta[name="csrf-token"]'
        ).content
    },

    body: JSON.stringify({
      check_in: this.startDateTarget.value,
      check_out: this.endDateTarget.value
    })
  })
  .then(() => {
    window.location.reload()
  })
  }
}
