import { Controller } from "@hotwired/stimulus"
// import { Loader } from "@googlemaps/js-api-loader"
// Connects to data-controller="maps"
export default class extends Controller {
  static values = {
    properties: Array
  }
  static targets = [
    "map",
    "categoryButton",
    "searchButton"
  ]

  connect() {

    // Selected category
    this.selectedCategory = null
    // Store POI markers
    this.poiMarkers = []
    // Store property markers
    this.propertyMarkers = []
    // Initialize viewport state
    this.currentViewport = {}
    const center = { lat: 35.675739, lng: 139.754037 };
    this.map = new google.maps.Map(this.element, {
      center,
      zoom: 12,
      mapId: "DEMO_MAP_ID",
    });


    this.propertiesValue.forEach((property) => {
      const marker = new google.maps.marker.AdvancedMarkerElement({
        map: this.map,
        position: { lat: property.latitude, lng: property.longitude }
      })
    // Save marker reference
    this.propertyMarkers.push(marker)
    })

    // Listen for map movement finishing
    this.map.addListener("idle", () => {
      this.updateViewportState()
    })
    // Run once on initial load
    this.updateViewportState()
  }
  updateViewportState() {
    const bounds = this.map.getBounds()

    // Safety check
    if (!bounds) return

    const northEast = bounds.getNorthEast()
    const southWest = bounds.getSouthWest()
    const center = this.map.getCenter()

    this.currentViewport = {
      north: northEast.lat(),
      east: northEast.lng(),
      south: southWest.lat(),
      west: southWest.lng(),
      centerLat: center.lat(),
      centerLng: center.lng(),
      zoom: this.map.getZoom()
    }

    console.log("Current viewport:")
    console.log(this.currentViewport)
  }

selectCategory(event) {
    // Remove active class from all buttons
    this.categoryButtonTargets.forEach((button) => {
      button.classList.remove("active-category")
    })

    // Activate clicked button
    event.currentTarget.classList.add("active-category")

    // Store selected category
    this.selectedCategory =
      event.currentTarget.dataset.category

    console.log("Selected category:")
    console.log(this.selectedCategory)
  }

  searchArea() {
    if (!this.selectedCategory) {
      alert("Please select a category first.")
      return
    }

    console.log("SEARCH AREA CLICKED")

    console.log("Selected category:")
    console.log(this.selectedCategory)

    console.log("Current viewport:")
    console.log(this.currentViewport)
  }

}
