import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["map"]

  connect() {
    if (typeof google === "undefined" || !this.hasMapTarget) return
    new google.maps.Map(this.mapTarget, {
      center: { lat: 35.6895, lng: 139.7000 },
      zoom: 13,
      mapId: "DEMO_MAP_ID",
      disableDefaultUI: true,
      gestureHandling: "none",
      keyboardShortcuts: false,
    })
  }
}
