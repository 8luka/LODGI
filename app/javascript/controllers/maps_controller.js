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
    "searchButton",
    "transitToggle",

    "layoutFilter",
    "neighborhoodFilter",

    "priceFilter",
    "priceValue"
  ]

  connect() {
    this.priceValueTarget.textContent ="¥500,000"
    this.allProperties = [...this.propertiesValue]
    // Selected category
    this.selectedCategory = null
    // Store POI markers
    this.poiMarkers = []
    // Store property markers
    this.propertyMarkers = []
    // Initialize viewport state
    this.currentViewport = {}
    this.activeInfoWindow = null
    this.selectedMarkerElement = null
    this.transitVisible = false
    this.transitLayer = new google.maps.TransitLayer()

    this.map = new google.maps.Map(this.mapTarget, {
      mapId: "DEMO_MAP_ID",
    });
    this.bounds = new google.maps.LatLngBounds()

    this.propertiesValue.forEach((property) => {
      const marker = new google.maps.marker.AdvancedMarkerElement({
        map: this.map,
        position: { lat: property.latitude, lng: property.longitude },
        content: this.createMarkerContent(
          "material-symbols-light:home-outline",
          "#c2584a"
        )
      })
      this.bounds.extend({
        lat: property.latitude,
        lng: property.longitude
      })
      marker.addListener("click", () => {
        const content =
        this.createPropertyPopupContent(property)
        this.openInfoWindow(marker, content)
      })
    // Save marker reference
    this.propertyMarkers.push(marker)
    })
    this.map.fitBounds(this.bounds)
    // Listen for map movement finishing
    this.map.addListener("idle", () => {
      this.updateViewportState()
    })
    // Run once on initial load
    this.updateViewportState()
    this.initializeFilters()
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
  initializeFilters() {

    const layouts =
      [...new Set(
        this.allProperties.map(
          property => property.layout
        )
      )]

    const neighborhoods =
      [...new Set(
        this.allProperties.map(
          property => property.neighborhood_name
        )
      )]

    this.layoutFilterTarget.innerHTML =
      `
        <option value="">
          Any
        </option>
      `

    layouts.forEach((layout) => {

      this.layoutFilterTarget.innerHTML += `
        <option value="${layout}">
          ${layout}
        </option>
      `
    })

    this.neighborhoodFilterTarget.innerHTML =
      `
        <option value="">
          Any
        </option>
      `

    neighborhoods.forEach((neighborhood) => {

      this.neighborhoodFilterTarget.innerHTML += `
        <option value="${neighborhood}">
          ${neighborhood}
        </option>
      `
    })
  }
  applyFilters() {

    const selectedLayout =
      this.layoutFilterTarget.value

    const selectedNeighborhood =
      this.neighborhoodFilterTarget.value

    const maxPrice =
      Number(
        this.priceFilterTarget.value
      )

    this.priceValueTarget.textContent =
      `¥${maxPrice.toLocaleString()}`

    const filteredProperties =
      this.allProperties.filter(
        (property) => {

          const matchesLayout =
            !selectedLayout ||
            property.layout === selectedLayout

          const matchesNeighborhood =
            !selectedNeighborhood ||
            property.neighborhood_name === selectedNeighborhood

          const matchesPrice =
            Number(property.price) <= maxPrice

          return (
            matchesLayout &&
            matchesNeighborhood &&
            matchesPrice
          )
        }
      )

    this.renderFilteredProperties(
      filteredProperties
    )
  }

renderFilteredProperties(properties) {

    this.propertyMarkers.forEach(
      (marker) => {
        marker.map = null
      }
    )

    this.propertyMarkers = []

    const bounds =
      new google.maps.LatLngBounds()

    properties.forEach(
      (property) => {

        const marker =
          new google.maps.marker.AdvancedMarkerElement({
            map: this.map,

            position: {
              lat: property.latitude,
              lng: property.longitude
            },

            content:
              this.createMarkerContent(
                "material-symbols-light:home-outline",
                "#c2584a"
              )
          })

        marker.addListener(
          "click",
          () => {

            const content =
              this.createPropertyPopupContent(
                property
              )

            this.openInfoWindow(
              marker,
              content
            )
          }
        )

        this.propertyMarkers.push(
          marker
        )

        bounds.extend({
          lat: property.latitude,
          lng: property.longitude
        })
      }
    )

    if (properties.length > 0) {

      this.map.fitBounds(
        bounds,
        100
      )
    }
  }

  clearFilters() {
    this.layoutFilterTarget.value = ""

    this.neighborhoodFilterTarget.value = ""

    this.priceFilterTarget.value = 500000

    this.applyFilters()
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

  getPoiIcon(category) {
    const icons = {
      restaurant: "material-symbols-light:restaurant",
      cafe: "material-symbols-light:coffee-outline",
      bar: "mdi:glass-cocktail",
      supermarket: "mdi-light:cart",
      convenience_store: "mdi:shopping-outline",
      gym: "mdi:dumbbell",
      train_station: "mdi:train",
      bus_station: "mdi:bus",
      parking: "mdi:parking",
      park: "tabler:tree",
      tourist_attraction: "maki:attraction"
    }

    return icons[category] || "mdi:map-marker"
  }

  createPropertyPopupContent(property) {
    const image =
      property.images?.[0]

    const stations =
      property.stations?.length
        ? property.stations
            .map(station => `🚉 ${station}`)
            .join("<br>")
        : "No stations nearby"

    return `
      <div class="property-popup">

        <img
          src="${image}"
          class="popup-image"
        />

        <div class="popup-content">

          <h3 class="popup-title">
            ${property.name}
          </h3>

          <div class="popup-row">
            ${property.layout}
          </div>

          <div class="popup-row">
            ¥${property.price}
          </div>

          <div class="popup-row">
            ${stations}
          </div>

          <a
            href="/properties/${property.id}"
            class="popup-button"
          >
            View Property
          </a>

        </div>

      </div>
    `
  }

  createPoiPopupContent(place) {

    let image = null

    if (place.photo_reference) {
      image =
        `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${place.photo_reference}&key=${window.googleMapsApiKey}`
    }

    return `
      <div class="poi-popup">

        ${image ? `
          <img
            src="${image}"
            class="popup-image"
          />
        ` : ""}

        <div class="popup-content">

          <h3 class="popup-title">
            ${place.name}
          </h3>

          <div class="popup-row">
            ⭐ ${place.rating || "No rating"}
          </div>

        </div>

      </div>
    `
  }

  openInfoWindow(marker, content) {

    // Close previous popup
    if (this.activeInfoWindow) {
      this.activeInfoWindow.close()
    }

    // Remove previous selected state
    if (this.selectedMarkerElement) {
      this.selectedMarkerElement.classList.remove(
        "selected-marker"
      )
    }

    const infoWindow =
      new google.maps.InfoWindow({
        content
      })

    infoWindow.open({
      anchor: marker,
      map: this.map
    })

    this.activeInfoWindow = infoWindow

    // Add selected state
    const markerElement =
      marker.content.firstElementChild

    markerElement.classList.add(
      "selected-marker"
    )

    this.selectedMarkerElement =
      markerElement

    // Remove selected state when popup closes
    infoWindow.addListener("closeclick", () => {
      markerElement.classList.remove(
        "selected-marker"
      )
    })
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
        radius: 500
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
          title: place.name,
          content: this.createMarkerContent(
          this.getPoiIcon(this.selectedCategory),
          "#556ea3"
        )
        })
        marker.addListener("click", () => {

          const content =
            this.createPoiPopupContent(place)

          this.openInfoWindow(marker, content)
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

  toggleTransit(event) {
    this.transitVisible = event.currentTarget.checked

    if (this.transitVisible) {

      this.transitLayer.setMap(this.map)

    } else {

      this.transitLayer.setMap(null)

    }
  }
}
