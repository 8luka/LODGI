// app/javascript/controllers/property_map_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const lat = parseFloat(this.element.dataset.lat)
    const lng = parseFloat(this.element.dataset.lng)

    const map = new google.maps.Map(this.element, {
      mapId: "DEMO_MAP_ID",
      center: { lat, lng },
      zoom: 15,
      mapTypeControl: false,
      fullscreenControl: false,
      cameraControl: false
    })

    const marker = new google.maps.marker.AdvancedMarkerElement({
    map,
    position: { lat, lng },
    content: this.createMarkerContent(
      "material-symbols-light:home-outline",
      "#c2584a"
        )
    })
  }
  createMarkerContent(icon, color) {
  const container = document.createElement("div")

  container.innerHTML = `
    <div
      class="custom-marker"
      style="background-color: ${color};"
    >
      <iconify-icon
        icon="${icon}"
        style="
          color: white;
          font-size: 20px;
        "
      ></iconify-icon>
    </div>
  `

  return container
}
}
