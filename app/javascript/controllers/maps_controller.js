import { Controller } from "@hotwired/stimulus"
import { computeScore, describeScore } from "scoring/score"
import { computeScore as computeScoreV2, describeScore as describeScoreV2 } from "scoring/score_simplified"
import { buildPopupSections } from "scoring/popup_content"
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

    anchor: Object,

    normalizedInputs: {
      type: Object,
      default: {}
    },

    // Switches scoring + filtering to the simplified v2 system (simplified_scoring_spec.md).
    scoringV2: {
      type: Boolean,
      default: false
    }
  }
  static targets = [
    "map",
    "transitToggle",

    "priceFilter",
    "priceValue",

    "availabilityFilter",

    // v2 hard-filter time buckets (radio groups; commute only rendered when an anchor is set)
    "commuteFilter",
    "stationFilter",

    "listings",

    // Pin-an-anchor mode (drop a custom point on the map as the trip anchor)
    "pinButton",
    "pinButtonLabel",
    "pinBar",
    "pinHint",
    "pinConfirm",
    "pinNameForm",
    "pinNameInput",
    "pinNameSave",
  ]

  connect() {
    this.filterTimeout = null
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
    this.activeProperty = null
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
    this.poisRestored = false
    this.map.addListener("idle", () => {
      this.updateViewportState()
      if (!this.poisRestored) {
        this.poisRestored = true
        this.restoreCheckedCategories()
      }
    })

    // Pin-an-anchor: map clicks drop the anchor only while pin mode is active (and not while the
    // name form is open), so normal map interaction is unaffected.
    this.pinMode = false
    this.pinNaming = false
    this.pinTempMarker = null
    this.pinPosition = null
    this.pinCreatePromise = null
    this.map.addListener("click", (e) => {
      if (!this.pinMode || this.pinNaming || !e.latLng) return
      this.placePinMarker(e.latLng.lat(), e.latLng.lng())
    })
    // Hand-off from the trip-setup form: /map?pin=1 opens straight into pin mode.
    if (new URLSearchParams(window.location.search).get("pin") === "1") {
      this.enterPinMode()
    }
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

    // v2 only: commute + walk-to-station time buckets cut listings (they no longer score).
    const commuteMax = this.scoringV2Value ? this.selectedBucketMinutes(this.commuteFilterTargets) : null
    const stationMax = this.scoringV2Value ? this.selectedBucketMinutes(this.stationFilterTargets) : null

    const filteredProperties = this.allProperties.filter((property) => {
      const matchesPrice = Number(property.price) <= maxPrice
      const matchesAvailability = !availableOnly || this.isAvailableForCheckin(property.availability)
      // null bucket ("Any") passes all; a numeric bucket requires a known time within it.
      const matchesCommute = commuteMax == null ||
        (property.travel_time_to_anchor != null && property.travel_time_to_anchor <= commuteMax)
      const matchesStation = stationMax == null ||
        (this.stationMinutes(property) != null && this.stationMinutes(property) <= stationMax)
      return matchesPrice && matchesAvailability && matchesCommute && matchesStation
    })

    this.filteredProperties = filteredProperties
    // Filters changed → re-fit the map to the new set.
    this.render({ fit: true })
  }

  // Re-score the current filtered set and repaint pins + the ranked rail.
  // fit:true (filter change / initial) rebuilds the marker set and re-fits the map.
  // fit:false (slider/toggle re-rank) keeps the markers — only their color changes — so an
  // open popup stays anchored; we recolor pins in place and live-update the open popup instead.
  render({ fit = false } = {}) {
    this.computeScores(this.filteredProperties)
    if (fit) {
      this.renderFilteredProperties(this.filteredProperties, true)
    } else {
      this.recolorPropertyMarkers()
      this.updateActivePopup()
    }
    this.renderRail(this.filteredProperties)
  }

  // Slider/toggle re-rank: update each existing pin's color from the new scores without
  // recreating markers (recreation would destroy the marker an open InfoWindow is anchored to).
  recolorPropertyMarkers() {
    Object.entries(this.propertyMarkersById || {}).forEach(([id, marker]) => {
      const dot = marker.content?.querySelector(".custom-marker")
      if (dot) dot.style.backgroundColor = this.colorForScore(this.scoresById[id])
    })
  }

  // Refresh the open property popup's dynamic slots in place (fit badge + info rows + amenity
  // chips) from the live priorities, reusing the same logic as decoratePopup(). No-op unless a
  // property popup is open. Mutating only these slots leaves the server-rendered shell intact.
  updateActivePopup() {
    if (!this.activeInfoWindow || !this.activeProperty) return
    const root = document.querySelector(".gm-style-iw-d .property-popup")
    if (!root) return

    const { primary, amenities } = buildPopupSections({
      property: this.activeProperty,
      priorities: this.priorities,
      hasAnchor: !!(this.anchorValue?.id),
      anchorName: this.anchorValue?.name,
    })

    const info = root.querySelector("[data-popup-info]")
    if (info) info.innerHTML = primary

    const amenitiesEl = root.querySelector("[data-popup-amenities]")
    if (amenitiesEl) amenitiesEl.innerHTML = amenities

    const fit = root.querySelector("[data-popup-fit]")
    if (fit) {
      const score = this.scoresById[this.activeProperty.id]
      fit.textContent = score == null ? "—" : score
      fit.style.color = this.colorForScore(score)
    }

    // The popup may have grown (rows/chips added) and spilled past the map edges — nudge the
    // map so the whole card is visible again. (Google only auto-pans on open, not on content change.)
    this.ensureActivePopupVisible()
  }

  // Pan the map by the minimum amount needed to bring the open InfoWindow fully back inside the
  // map viewport (with a small padding). No-op when it already fits. The popup is anchored to its
  // marker, so panning moves both together — the card slides into view.
  ensureActivePopupVisible() {
    const iw = document.querySelector(".gm-style-iw-c")
    if (!iw || !this.hasMapTarget) return

    const card = iw.getBoundingClientRect()
    const map = this.mapTarget.getBoundingClientRect()
    const pad = 14

    let dx = 0
    if (card.left < map.left + pad) dx = card.left - (map.left + pad)
    else if (card.right > map.right - pad) dx = card.right - (map.right - pad)

    let dy = 0
    if (card.top < map.top + pad) dy = card.top - (map.top + pad)
    else if (card.bottom > map.bottom - pad) dy = card.bottom - (map.bottom - pad)

    if (dx !== 0 || dy !== 0) this.map.panBy(dx, dy)
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
    // id → marker / property lookups so a card click can focus the matching pin (focusListing).
    this.propertyMarkersById = {}
    this.propertiesById = {}

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
              () => this.openPropertyPopup(property, marker)
            )

        this.propertyMarkers.push(
          marker
        )
        this.propertyMarkersById[property.id] = marker
        this.propertiesById[property.id] = property

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

  // Fetch + open a property's popup on its pin. Shared by pin clicks and card clicks.
  async openPropertyPopup(property, marker) {
    const response = await fetch(`/properties/${property.id}/popup`)
    const html = await response.text()
    this.openInfoWindow(marker, this.decoratePopup(html, property))
    // Mark this as the active property popup so slider/toggle moves live-update it.
    this.activeProperty = property
  }

  // Left-rail card click: instead of navigating to the show page, fly the map to the
  // property's pin (neighborhood zoom) and open its popup. The popup CTA still links through.
  focusListing(event) {
    const card = event.target.closest(".listing-card")
    if (!card) return
    event.preventDefault()
    const id = Number(card.dataset.listingId)
    const marker = this.propertyMarkersById?.[id]
    const property = this.propertiesById?.[id]
    if (!marker || !property) return  // pin filtered out → leave navigation suppressed, do nothing
    this.map.panTo(marker.position)
    this.map.setZoom(15)              // neighborhood-level: close but not too close
    this.openPropertyPopup(property, marker)
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

  // Fill the fetched popup shell's dynamic slots from the live client state: the score-driven
  // info rows ([data-popup-info]) and the fit badge ([data-popup-fit]). The shell itself
  // (image, favorite heart, name, availability, price, CTA) is rendered server-side so the
  // favorite button keeps its current_user state. Returns the populated HTML string.
  decoratePopup(html, property) {
    const doc = new DOMParser().parseFromString(html, "text/html")

    const { primary, amenities } = buildPopupSections({
      property,
      priorities: this.priorities,
      hasAnchor: !!(this.anchorValue?.id),
      anchorName: this.anchorValue?.name,
    })

    const info = doc.querySelector("[data-popup-info]")
    if (info) info.innerHTML = primary

    const amenitiesEl = doc.querySelector("[data-popup-amenities]")
    if (amenitiesEl) amenitiesEl.innerHTML = amenities

    const fit = doc.querySelector("[data-popup-fit]")
    if (fit) {
      const score = this.scoresById[property.id]
      fit.textContent = score == null ? "—" : score
      fit.style.color = this.colorForScore(score)
    }

    const wrapper = doc.querySelector(".property-popup")
    return wrapper ? wrapper.outerHTML : html
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
                  Your Anchor
                </div>
              </div>
            </div>
          `
        )
      }
    )
  }

  // ── Pin-an-anchor mode ──────────────────────────────────────────────────
  // Toggle button → enter/exit. In pin mode a map click drops a draggable anchor marker;
  // Confirm POSTs the point to /inquiry/pin and reloads so the server recomputes scoring.

  togglePinMode() {
    this.pinMode ? this.exitPinMode() : this.enterPinMode()
  }

  enterPinMode() {
    this.pinMode = true
    this.element.classList.add("pin-mode")
    if (this.hasPinBarTarget) this.pinBarTarget.hidden = false
    if (this.hasPinButtonLabelTarget) this.pinButtonLabelTarget.textContent = "Pinning…"
    if (this.hasPinConfirmTarget) this.pinConfirmTarget.disabled = true
    if (this.hasPinHintTarget) this.pinHintTarget.textContent = "Click the map to set your anchor"
  }

  exitPinMode() {
    this.pinMode = false
    this.pinNaming = false
    this.pinCreatePromise = null
    this.element.classList.remove("pin-mode")
    if (this.hasPinBarTarget) this.pinBarTarget.hidden = true
    if (this.hasPinNameFormTarget) this.pinNameFormTarget.hidden = true
    if (this.hasPinButtonLabelTarget) this.pinButtonLabelTarget.textContent = "Custom pin"
    this.clearPinMarker()
  }

  clearPinMarker() {
    if (this.pinTempMarker) {
      this.pinTempMarker.map = null
      this.pinTempMarker = null
    }
    this.pinPosition = null
  }

  placePinMarker(lat, lng) {
    this.clearPinMarker()
    this.pinPosition = { lat, lng }

    const content = this.createMarkerContent("mdi:anchor", "#000000")
    content.querySelector(".custom-marker").classList.add("anchor-marker")

    const marker = new google.maps.marker.AdvancedMarkerElement({
      map: this.map,
      position: { lat, lng },
      content,
      gmpDraggable: true
    })
    // Drag to fine-tune the dropped point.
    marker.addListener("dragend", (e) => {
      if (e.latLng) this.pinPosition = { lat: e.latLng.lat(), lng: e.latLng.lng() }
    })
    this.pinTempMarker = marker

    if (this.hasPinConfirmTarget) this.pinConfirmTarget.disabled = false
    if (this.hasPinHintTarget) this.pinHintTarget.textContent = "Drag to adjust, then set your anchor"
  }

  // Set anchor: fire the create+cache request and immediately open the name form — we do NOT await
  // the request, so the ~2s travel-time caching runs server-side while the user types a name and is
  // done by the time they save. Saving the name (savePinName) awaits this before reloading.
  confirmPin() {
    if (!this.pinPosition) return

    this.pinCreatePromise = fetch("/inquiry/pin", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ lat: this.pinPosition.lat, lng: this.pinPosition.lng })
    }).then((response) => response.ok).catch(() => false)

    // Switch from the confirm bar to the name form. pinNaming freezes map clicks so a stray click
    // behind the form doesn't move the pin.
    this.pinNaming = true
    if (this.hasPinBarTarget) this.pinBarTarget.hidden = true
    if (this.hasPinNameFormTarget) this.pinNameFormTarget.hidden = false
    if (this.hasPinNameInputTarget) {
      this.pinNameInputTarget.focus()
      this.pinNameInputTarget.select()
    }
  }

  // Persist the (optional) name, then reload so the new name + commute scores show everywhere.
  async savePinName(event) {
    event.preventDefault()
    if (this.hasPinNameSaveTarget) this.pinNameSaveTarget.disabled = true

    // Make sure the anchor exists (and its times are cached) before naming / reloading.
    const created = await (this.pinCreatePromise || Promise.resolve(false))
    if (!created) {
      if (this.hasPinNameSaveTarget) this.pinNameSaveTarget.disabled = false
      return
    }

    const name = this.hasPinNameInputTarget ? this.pinNameInputTarget.value : ""
    await fetch("/inquiry/pin/name", {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ name })
    }).catch(() => {})

    // Navigate to the clean /map path so ?pin=1 isn't preserved — if it were,
    // connect() would call enterPinMode() on the reload and the button would
    // stay stuck on "Pinning…" with the pin bar re-opening.
    window.location.href = window.location.pathname
  }

  cancelPin() {
    this.exitPinMode()
  }

  openInfoWindow(marker, content) {

    // Default to "not a property popup"; openPropertyPopup re-sets activeProperty after this.
    // (POI/anchor popups reuse openInfoWindow and must not be live-updated as property popups.)
    this.activeProperty = null

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
      this.activeProperty = null
    })
  }
  debouncedApplyFilters(event) {

    clearTimeout(
      this.filterTimeout
    )

    this.filterTimeout =
      setTimeout(
        () => {
          this.applyFilters(event)
        },
        300
      )
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

  restoreCheckedCategories() {
    document.querySelectorAll('[data-priorities-panel-target="toggleInput"]').forEach((t) => {
      if (t.checked && t.dataset.category) {
        this.fetchCategory(t.dataset.category)
      }
    })
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

  // The active scoring engine: simplified v2 or the original multi-slider one.
  get scoreFn() { return this.scoringV2Value ? computeScoreV2 : computeScore }
  get describeFn() { return this.scoringV2Value ? describeScoreV2 : describeScore }

  // Build the score-engine input object for one property from the current priorities.
  // v2 keeps only the Peace & Quiet slider + toggles (commute/station are filters now).
  scoreArgs(property) {
    const w = this.priorities.weights
    const active = this.priorities.categories || []
    const toggles = {}
    TOGGLE_CATEGORIES.forEach((c) => { toggles[c] = active.includes(c) })
    const normalizedInputs = this.normalizedInputsValue[property.id] || {}

    if (this.scoringV2Value) {
      return { normalizedInputs, peaceQuietSlider: w.quiet || 0, toggles }
    }
    return {
      normalizedInputs,
      hasAnchor: !!(this.anchorValue?.id),
      sliders: { commute: w.commute || 0, peace_quiet: w.quiet || 0, near_station: w.station || 0 },
      toggles,
    }
  }

  computeScores(properties) {
    this.scoresById = {}
    properties.forEach((p) => { this.scoresById[p.id] = this.scoreFn(this.scoreArgs(p)) })
  }

  // Selected minutes from a time-bucket radio group; null for "Any" or an empty group.
  selectedBucketMinutes(targets) {
    const checked = targets.find((t) => t.checked)
    if (!checked) return null
    const m = checked.dataset.minutes
    return m === "any" ? null : Number(m)
  }

  stationMinutes(property) {
    return property.score_inputs?.transit_station?.time_to_station ?? null
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
    const { terms } = this.describeFn(this.scoreArgs(property))
    const line = terms
      .map((t) => `${t.label}: w=${t.weight.toFixed(2)}×s=${t.subscore.toFixed(2)}=${t.contribution.toFixed(2)}`)
      .join(" | ")
    return `<div class="listing-card__debug" style="font-size:10px; color:#666; margin-top:4px; line-height:1.35;">${line || "no active terms → 50"}</div>`
  }
}
