import { Controller } from "@hotwired/stimulus"
// import { Loader } from "@googlemaps/js-api-loader"
// Connects to data-controller="maps"
export default class extends Controller {
  static values = {
    properties: Array,

    checkin: {
      type: String,
      default: ""
    },

    anchor: Object
  }
  static targets = [
    "map",
    "transitToggle",

    "layoutFilter",
    "neighborhoodFilter",
    // neighborhood filter is not used currently but may be in the future

    "priceFilter",
    "priceValue",

    "availabilityFilter",

    "transitControl",
  ]

  connect() {
    this.priceValueTargets.forEach(t => t.textContent = "¥500,000")
    this.allProperties = [...this.propertiesValue]
    // POI markers, keyed by category so each right-rail toggle is independent
    this.poiMarkersByCategory = {}
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
      mapTypeControl: false,
      fullscreenControl: false,
      cameraControl: false

    });
    // Re-fit + viewport tracking after the filtered render settles.
    this.map.addListener("idle", () => {
      this.updateViewportState()
    })
    this.initializeFilters()

    // This checks if a user defined a check-in date and will end with only rendering the available for it
    this.availabilityFilterTargets.forEach(t => t.checked = Boolean(this.checkinValue))
    this.applyFilters()
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

    // The neighborhood select is currently commented out in the view, so guard
    // its target before populating it.
    if (this.hasNeighborhoodFilterTarget) {
      const neighborhoods =
        [...new Set(
          this.allProperties.map(
            property => property.neighborhood_name
          )
        )]

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
  }
  applyFilters(event) {

    const selectedLayout = this.layoutFilterTarget.value

    const selectedNeighborhood = this.hasNeighborhoodFilterTarget ? this.neighborhoodFilterTarget.value : ""

    // Whichever price slider fired is authoritative; sync all others to it.
    const priceSource = this.priceFilterTargets.find(t => t === event?.target) || this.priceFilterTargets[0]
    const maxPrice = Number(priceSource.value)
    this.priceFilterTargets.forEach(t => t.value = maxPrice)
    this.priceValueTargets.forEach(t => t.textContent = `¥${maxPrice.toLocaleString()}`)

    // Same for availability checkbox.
    const availSource = this.availabilityFilterTargets.find(t => t === event?.target) || this.availabilityFilterTargets[0]
    const availableOnly = availSource.checked
    this.availabilityFilterTargets.forEach(t => t.checked = availableOnly)

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

          const matchesAvailability =
            !availableOnly ||
            this.isAvailableForCheckin(property.availability)

          return (
            matchesLayout &&
            matchesNeighborhood &&
            matchesPrice &&
            matchesAvailability
          )
        }
      )

    this.renderFilteredProperties(
      filteredProperties
    )
  }

  isAvailableForCheckin(availability) {
    if (availability === "now") return true
    const checkin = this.checkinValue
    if (!checkin) return false  // manual check with no dates → only "now" passes

    // checkin is "YYYY-MM-DD" — build a local date to avoid UTC-vs-local skew.
    const [y, m, d] = checkin.split("-").map(Number)
    const checkinDate = new Date(y, m - 1, d)

    const clean = availability.replace(/(\d+)(st|nd|rd|th)/i, "$1") // "15th" → "15"
    const avDate = new Date(`${clean} ${y}`)                        // local midnight
    if (isNaN(avDate.getTime())) return false

    return avDate <= checkinDate  // available by the time the user arrives
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
              async () => {
                const response = await fetch(`/properties/${property.id}/popup`)
                const html = await response.text()
                this.openInfoWindow(marker, html)
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
      this.renderAnchorMarker(
        bounds
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

    if (this.hasNeighborhoodFilterTarget) {
      this.neighborhoodFilterTarget.value = ""
    }

    this.priceFilterTargets.forEach(t => t.value = 500000)

    this.availabilityFilterTargets.forEach(t => t.checked = false)

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
      pharmacy: "mdi:medical-bag",
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
    // Green when the listing is actually usable for the trip (consistent with the
    // "only show available" filter); otherwise show the move-in date as-is.
    const isNow =
      property.availability?.toLowerCase() === "now"

    const availableForTrip =
      this.isAvailableForCheckin(property.availability)

    const availabilityClass =
      availableForTrip
        ? "availability-pill available-pill"
        : "availability-pill unavailable-pill"

    const availabilityText =
      isNow
        ? "Available now"
        : `Available ${property.availability}`
    return `
      <div class="property-popup">

        <img
          src="${image}"
          class="popup-image"
        />

        <div class="popup-content">

          <div class="${availabilityClass}">
            ${availabilityText}
          </div>

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

    if (place.photos?.[0]) {
      image =
        `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${place.photos[0]}&key=${window.googleMapsPlacesKey}`
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
  renderAnchorMarker(bounds) {

    if (!this.anchorValue?.latitude) {
      return
    }
    const content =
      this.createMarkerContent(
        "mdi:anchor",
        "#000000"
      )

    content
      .querySelector(".custom-marker")
      .classList
      .add("anchor-marker")
    const marker =
      new google.maps.marker.AdvancedMarkerElement({

        map: this.map,

        position: {
          lat: this.anchorValue.latitude,
          lng: this.anchorValue.longitude
        },

        content: content

      })

    bounds.extend({
      lat: this.anchorValue.latitude,
      lng: this.anchorValue.longitude
    })

    marker.addListener(
      "click",
      () => {

        this.openInfoWindow(
          marker,
          `
            <div class="poi-popup">
              <div class="popup-content">
                <h3 class="popup-title">
                  ${this.anchorValue.name}
                </h3>

                <div class="popup-row">
                  Trip Destination
                </div>
              </div>
            </div>
          `
        )
      }
    )
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
      "selected-marker",
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

  // Right-rail category toggle: on = fetch + show that category's pins, off = remove them.
  toggleCategory(event) {
    const category = event.currentTarget.dataset.category
    if (event.currentTarget.checked) {
      this.fetchCategory(category)
    } else {
      this.clearCategory(category)
    }
  }

  fetchCategory(category) {
    fetch("/places/search", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token":
          document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        category: category,
        north: this.currentViewport.north,
        south: this.currentViewport.south,
        east: this.currentViewport.east,
        west: this.currentViewport.west
      })
    })
      .then((response) => response.json())
      .then((places) => this.renderCategoryMarkers(category, places))
  }

  renderCategoryMarkers(category, places) {
    // Replace any existing markers for this category
    this.clearCategory(category)
    const markers = places.map((place) => {
      const marker = new google.maps.marker.AdvancedMarkerElement({
        map: this.map,
        position: { lat: place.latitude, lng: place.longitude },
        title: place.name,
        content: this.createMarkerContent(this.getPoiIcon(category), "#556ea3")
      })
      marker.addListener("click", () => {
        this.openInfoWindow(marker, this.createPoiPopupContent(place))
      })
      return marker
    })
    this.poiMarkersByCategory[category] = markers
  }

  clearCategory(category) {
    const markers = this.poiMarkersByCategory[category] || []
    markers.forEach((marker) => { marker.map = null })
    this.poiMarkersByCategory[category] = []
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
