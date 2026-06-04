import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    properties: Array
  }

  connect() {
    if (!this.hasPropertiesValue || this.propertiesValue.length === 0) return

    const map = new google.maps.Map(this.element, {
      zoom: 14,
      center: {
        lat: Number(this.propertiesValue[0].latitude),
        lng: Number(this.propertiesValue[0].longitude)
      }
    })

    const bounds = new google.maps.LatLngBounds()

    this.propertiesValue.forEach((property) => {
      const position = {
        lat: Number(property.latitude),
        lng: Number(property.longitude)
      }

      new google.maps.Marker({
        position,
        map,
        title: property.name
      })

      bounds.extend(position)
    })

    map.fitBounds(bounds)
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
          style="color: white; font-size: 20px;"
        ></iconify-icon>
      </div>
    `

    return container
  }
}
