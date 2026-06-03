import { Controller } from "@hotwired/stimulus"
import { computeScore, describeScore } from "scoring/score"
// import { Loader } from "@googlemaps/js-api-loader"
// Connects to data-controller="maps"

// Fit-score → pin/chip color. Buckets are tunable (spec §7): green → amber → gray.
const SCORE_COLORS = [
  { min: 70, color: "#2e7d32" }, // strong fit  → green
  { min: 40, color: "#f5a623" }, // medium fit  → amber
  { min: 0,  color: "#9e9e9e" }, // weak / no-data → gray
]
const TOGGLE_CATEGORIES = [
  "convenience_store", "supermarket", "atm", "cafe", "restaurant",
  "bar", "park", "gym", "tourist_attraction",
]

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

    "priceFilter",
    "priceValue",

    "availabilityFilter",

    "listings",
  ]

  connect() {
    this.allProperties = [...this.propertiesValue]
    // Fit-score state: current priorities (read from the rail DOM), per-property scores,
    // and the last filtered set. Live re-rank reads priorities:changed (see rescore()).
    this.scoresById = {}
    this.priorities = this.readPriorities()
    this.filteredProperties = this.allProperties
    this.debug = new URLSearchParams(window.location.search).get("debug") === "1"
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
  applyFilters(event) {
    // Whichever price slider fired is authoritative; sync all others to it.
    const priceSource = this.priceFilterTargets.find(t => t === event?.target) || this.priceFilterTargets[0]
    const maxPrice = Number(priceSource.value)
    this.priceFilterTargets.forEach(t => t.value = maxPrice)
    this.priceValueTargets.forEach(t => t.textContent = `¥${maxPrice.toLocaleString()}`)

    const availSource = this.availabilityFilterTargets.find(t => t === event?.target) || this.availabilityFilterTargets[0]
    const availableOnly = availSource.checked
    this.availabilityFilterTargets.forEach(t => t.checked = availableOnly)

    const filteredProperties = this.allProperties.filter((property) => {
      const matchesPrice = Number(property.price) <= maxPrice
      const matchesAvailability = !availableOnly || this.isAvailableForCheckin(property.availability)
      return matchesPrice && matchesAvailability
    })

    this.filteredProperties = filteredProperties
    // Filters changed → re-fit the map to the new set.
    this.render({ fit: true })
  }

  // Re-score the current filtered set and repaint pins + the ranked rail.
  // fit:true re-fits the map (filter change); fit:false leaves the viewport (slider/toggle change).
  render({ fit = false } = {}) {
    this.computeScores(this.filteredProperties)
    this.renderFilteredProperties(this.filteredProperties, fit)
    this.renderRail(this.filteredProperties)
  }

  // Live re-rank entry point: the priorities panel emits priorities:changed on every
  // slider/toggle move. Re-score in place without re-fitting the map.
  rescore(event) {
    this.priorities = event?.detail?.weights
      ? { weights: event.detail.weights, categories: event.detail.categories || [] }
      : this.readPriorities()
    this.render({ fit: false })
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

  renderFilteredProperties(properties, fit = true) {

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
                this.colorForScore(this.scoresById[property.id])
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
    if (fit && properties.length > 0) {

      this.map.fitBounds(
        bounds,
        100
      )
    }
  }

  clearFilters() {
    this.priceFilterTargets.forEach(t => t.value = t.max)
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

    const image = this.placePhotoUrl(place.photos?.[0])

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
  // Build an <img> URL from a stored photo reference, handling both pipelines:
  //  • v2 (Places API New) refs look like "places/<id>/photos/<id>" → New media endpoint + MAPS_JS_API key
  //  • v1 (legacy) refs are opaque strings → classic Place Photo URL + PLACES_API key
  // Returns null when there's no photo (popup then renders without an image).
  placePhotoUrl(ref) {
    if (!ref) return null
    if (ref.startsWith("places/")) {
      return `https://places.googleapis.com/v1/${ref}/media?maxHeightPx=400&key=${window.googleMapsApiKey}`
    }
    return `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${ref}&key=${window.googleMapsPlacesKey}`
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

  // ── Fit scoring (live re-rank) ───────────────────────────────────────────────────

  // Read current slider weights + active toggle categories from the rail DOM. Used for the
  // initial paint on connect; live updates thereafter arrive via the priorities:changed event.
  readPriorities() {
    const weights = { commute: 0, quiet: 0, station: 0 }
    document.querySelectorAll('[data-priorities-panel-target="sliderInput"]').forEach((s) => {
      if (s.dataset.key in weights) weights[s.dataset.key] = Number(s.value)
    })
    const categories = [...document.querySelectorAll('[data-priorities-panel-target="toggleInput"]')]
      .filter((t) => t.checked)
      .map((t) => t.dataset.category)
    return { weights, categories }
  }

  // Build the computeScore() input object for one property from the current priorities.
  // Maps the rail's slider keys (commute/quiet/station) to the formula's names.
  scoreArgs(property) {
    const w = this.priorities.weights
    const active = this.priorities.categories || []
    const toggles = {}
    TOGGLE_CATEGORIES.forEach((c) => { toggles[c] = active.includes(c) })
    return {
      scoreInputs: property.score_inputs || {},
      travelTimeToAnchor: property.travel_time_to_anchor ?? null,
      sliders: { commute: w.commute || 0, peace_quiet: w.quiet || 0, near_station: w.station || 0 },
      toggles,
    }
  }

  computeScores(properties) {
    this.scoresById = {}
    properties.forEach((p) => { this.scoresById[p.id] = computeScore(this.scoreArgs(p)) })
  }

  colorForScore(score) {
    if (score == null) return "#9e9e9e"
    return (SCORE_COLORS.find((b) => score >= b.min) || SCORE_COLORS[SCORE_COLORS.length - 1]).color
  }

  // Rebuild the left rail: filtered properties sorted by fit score (desc), top 20, live fit chips.
  renderRail(properties) {
    if (!this.hasListingsTarget) return
    const ranked = [...properties].sort(
      (a, b) => (this.scoresById[b.id] ?? -1) - (this.scoresById[a.id] ?? -1)
    )
    this.listingsTarget.innerHTML = ranked.slice(0, 20).map((p, i) => this.listingCardHtml(p, i)).join("")
  }

  listingCardHtml(property, index) {
    const score = this.scoresById[property.id]
    const metric = property.stations?.[0] || property.neighborhood_name || ""
    const price = Number(property.price).toLocaleString()
    const fit = score == null ? "—" : score
    return `
      <a href="/properties/${property.id}" class="listing-card" data-listing-id="${property.id}">
        <span class="listing-card__rank ${index < 3 ? "is-top" : ""}">${index + 1}</span>
        <div class="listing-card__thumb" style="background-image: url('${property.images?.[0] || ""}');"></div>
        <div class="listing-card__body">
          <div class="listing-card__name">${property.name}</div>
          <div class="listing-card__metric">
            <iconify-icon icon="tabler:train"></iconify-icon> ${metric}
          </div>
          <div class="listing-card__foot">
            <span class="listing-card__price">¥${price}</span>
            <span class="fit-chip" style="background:${this.colorForScore(score)}; color:#fff;">Fit ${fit}</span>
          </div>
          ${this.debug ? this.debugBreakdownHtml(property) : ""}
        </div>
      </a>
    `
  }

  // §7.4 debug breakdown: each active term's weight × subscore = contribution. Only with ?debug=1.
  debugBreakdownHtml(property) {
    const { terms } = describeScore(this.scoreArgs(property))
    const line = terms
      .map((t) => `${t.label}: w=${t.weight.toFixed(2)}×s=${t.subscore.toFixed(2)}=${t.contribution.toFixed(2)}`)
      .join(" | ")
    return `<div class="listing-card__debug" style="font-size:10px; color:#666; margin-top:4px; line-height:1.35;">${line || "no active terms → 50"}</div>`
  }
}
