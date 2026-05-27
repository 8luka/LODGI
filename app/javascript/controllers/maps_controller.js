import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="maps"
export default class extends Controller {
  static values = {
    properties: Array
  }

  connect() {
    console.log(google)
    const center = { lat: 35.6764, lng: 139.6500 };
    const map = new google.maps.Map(this.element, {
      center,
      zoom: 12,
      mapId: "DEMO_MAP_ID",
    });
    this.propertiesValue.forEach((property) => {
      const marker = new google.maps.marker.AdvancedMarkerElement({
        map,
        position: { lat: property.latitude, lng: property.longitude }
      })
    })
  }
}
