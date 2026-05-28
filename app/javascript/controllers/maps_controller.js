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
    this.map = new google.maps.Map(this.mapTarget, {
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

    // Clear old POI markers
    this.clearPoiMarkers()

    fetch("/places/search", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token":
          document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        category: this.selectedCategory,
        center_lat: this.currentViewport.centerLat,
        center_lng: this.currentViewport.centerLng,
        radius: 2000
      })
    })
    .then((response) => {
      return response.json()
    })
    .then((data) => {
      console.log(data);
      const places = data;
      console.log("Places:")
      // console.log(places)
      this.renderPoiMarkers(places)
    })



  }

  renderPoiMarkers(places) {
    places.forEach((place) => {

      const marker = new google.maps.marker.AdvancedMarkerElement({
          map: this.map,
          position: {
            lat: place.latitude,
            lng: place.longitude
          },
          title: place.name
        })

      this.poiMarkers.push(marker)
    })
  }

  clearPoiMarkers() {
    this.poiMarkers.forEach((marker) => {
      marker.map = null
    })

    this.poiMarkers = []
  }
}
