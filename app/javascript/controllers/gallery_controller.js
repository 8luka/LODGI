import { Controller } from "@hotwired/stimulus"
import GLightbox from "glightbox"

export default class extends Controller {
  connect() {
    this.lightbox = GLightbox({ selector: ".glightbox" })

    this.lightbox.on("slide_changed", ({ current }) => {
      const total = this.lightbox.elements.length
      const index = current.index + 1
      let counter = document.querySelector(".glightbox-counter")

      if (!counter) {
        counter = document.createElement("div")
        counter.className = "glightbox-counter"
        document.querySelector(".goverlay").appendChild(counter)
      }

      counter.textContent = `${index} / ${total}`
    })
  }

  open() {
    this.lightbox.open()
  }

  disconnect() {
    this.lightbox.destroy()
  }
}
