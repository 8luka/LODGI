import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "map",
    "hiddenNeighborhood",
    "showButton"
  ]

  connect() {
    if (typeof google === "undefined" || !this.hasMapTarget) return
    new google.maps.Map(this.mapTarget, {
      center: { lat: 35.6595, lng: 139.7090 }, // Shibuya shifted left in frame
      zoom: 14,
      mapId: "DEMO_MAP_ID",
      disableDefaultUI: true,
      gestureHandling: "none",
      keyboardShortcuts: false,
    })
  }
  showAllNeighborhoods() {

    const hidden =
      this.hiddenNeighborhoodTargets.some(
        neighborhood =>
          neighborhood.classList.contains(
            "hidden-neighborhood"
          )
      )

    if (hidden) {

      this.hiddenNeighborhoodTargets.forEach(
        neighborhood =>
          neighborhood.classList.remove(
            "hidden-neighborhood"
          )
      )

      this.showButtonTarget.innerHTML = `
        Show fewer neighborhoods
        <i class="fa-solid fa-chevron-up"></i>
      `

    } else {

      this.hiddenNeighborhoodTargets.forEach(
        neighborhood =>
          neighborhood.classList.add(
            "hidden-neighborhood"
          )
      )

      this.showButtonTarget.innerHTML = `
        Show all neighborhoods
        <i class="fa-solid fa-chevron-down"></i>
      `

      document
        .getElementById("neighborhoods")
        .scrollIntoView({
          behavior: "smooth"
        })
    }
  }
}
