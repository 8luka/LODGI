import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="maps"
export default class extends Controller {
  connect() {
  const center =  { lat: 35.6764, lng: 139.6500 };
  const map = new google.maps.Map(this.element, {
    center,
    zoom: 12,
    mapId: "DEMO_MAP_ID",
  });
  }
}
