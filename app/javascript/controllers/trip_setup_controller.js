import { Controller } from "@hotwired/stimulus"

// The whole navbar trip-setup form dropdown open/close,
// trip-type tiles that reframe the anchor section, and the multi-category anchor picker
// (one anchor can live in several tabs; search matches across all). Submits a
// POST form to inquiries_path, which saves the inquiry and redirects to /map.
// Connects to data-controller="trip-setup"
export default class extends Controller {
  static targets = [
    "toggle", "panel", "summary",
    "tripTypeTile", "tripTypeField",
    "anchorPrompt", "anchorHelp", "anchorTab", "anchorSearch", "anchorGrid",
    "emptyState", "selectedLabel", "anchorIdField",
    "submitBtn", "checkin", "checkout"
  ]

  static TAGLINES = [
    "Find short-term apartments in Tokyo",
    "Find a furnished place with English support",
    "Find a place to stay close to your office",
    "Find an apartment close to campus"
  ]
  static values = {
    anchors: Array,
    tripType: { type: String, default: "visiting" },
    currentTab: { type: String, default: "neighborhood" },
    selectedId: { type: String, default: "" },
    selectedName: { type: String, default: "" }
  }

  static FRAMING = {
    business: {
      prompt: "Where's your work?",
      help: "Pick the place you'll need to get to most often. We'll score every listing by commute time.",
      tab: "work"
    },
    education: {
      prompt: "Where's your school?",
      help: "Pick your campus or institution. We'll score every listing by commute time.",
      tab: "campus"
    },
    visiting: {
      prompt: "What area appeals to you?",
      help: "Pick a neighborhood or place you want to be near. We'll score every listing by proximity.",
      tab: "neighborhood"
    }
  }

  connect() {
    this._outside = (e) => { if (!e.composedPath().includes(this.element)) this.close() }
    this.markActiveTripTile()
    this.applyFraming()
    this.updateSelectedLabel()
    this.render()
    this._startTaglineCycle()
  }

  disconnect() {
    document.removeEventListener("click", this._outside)
    clearInterval(this._taglineTimer)
  }

  _startTaglineCycle() {
    if (!this.hasSummaryTarget || this.summaryTarget.textContent.trim()) return
    this._taglineIndex = 0
    this.summaryTarget.textContent = this.constructor.TAGLINES[0]
    this._taglineTimer = setInterval(() => this._cycleTagline(), 3000)
  }

  _cycleTagline() {
    if (!this.hasSummaryTarget) return
    const span = this.summaryTarget
    span.classList.add("is-fading")
    setTimeout(() => {
      this._taglineIndex = (this._taglineIndex + 1) % this.constructor.TAGLINES.length
      span.textContent = this.constructor.TAGLINES[this._taglineIndex]
      span.classList.remove("is-fading")
    }, 250)
  }

  // ── Dropdown ──
  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.element.classList.add("is-open")
    this.panelTarget.hidden = false
    requestAnimationFrame(() => this.panelTarget.classList.add("is-open"))
    document.addEventListener("click", this._outside)
  }

  close() {
    this.element.classList.remove("is-open")
    this.panelTarget.classList.remove("is-open")
    this.panelTarget.addEventListener("transitionend", () => {
      this.panelTarget.hidden = true
    }, { once: true })
    document.removeEventListener("click", this._outside)
  }

  // ── Trip type ──
  selectTripType(event) {
    this.tripTypeValue = event.currentTarget.dataset.tripType
    this.tripTypeFieldTarget.value = this.tripTypeValue
    this.currentTabValue = this.constructor.FRAMING[this.tripTypeValue].tab
    this.clearSelection() // framing changed → previous anchor no longer makes sense
    this.anchorSearchTarget.value = ""
    this.markActiveTripTile()
    this.applyFraming()
    this.render()
  }

  markActiveTripTile() {
    this.tripTypeTileTargets.forEach((t) => {
      t.classList.toggle("is-sel", t.dataset.tripType === this.tripTypeValue)
    })
  }

  applyFraming() {
    const f = this.constructor.FRAMING[this.tripTypeValue] || this.constructor.FRAMING.business
    this.anchorPromptTarget.textContent = f.prompt
    this.anchorHelpTarget.textContent = f.help
  }

  // ── Anchor picker ──
  selectTab(event) {
    this.currentTabValue = event.currentTarget.dataset.category
    this.anchorSearchTarget.value = ""
    this.render()
  }

  filter() { this.render() }

  selectAnchor(event) {
    const id = event.currentTarget.dataset.id
    if (id === this.selectedIdValue) {
      this.clearSelection()
    } else {
      this.selectedIdValue = id
      this.anchorIdFieldTarget.value = id
      this.updateSelectedLabel()
    }
    this.render()
  }

  skip() {
    this.clearSelection()
    this.element.querySelector("form").requestSubmit()
  }

  clearSelection() {
    this.selectedIdValue = ""
    this.anchorIdFieldTarget.value = ""
    this.updateSelectedLabel()
  }

  updateSelectedLabel() {
    const anchor = this.anchorsValue.find((a) => a.id === this.selectedIdValue)
    // Fall back to selectedNameValue for anchors not in the curated list (e.g. custom map pins).
    this.selectedLabelTarget.textContent = anchor?.name || this.selectedNameValue || "none"
  }

  render() {
    const q = this.anchorSearchTarget.value.trim().toLowerCase()
    const searching = q.length > 0

    // Search matches across all categories (each anchor is one record);
    // otherwise show every anchor whose categories include the active tab.
    const items = searching
      ? this.anchorsValue.filter((a) => a.name.toLowerCase().includes(q))
      : this.anchorsValue.filter((a) => a.categories.includes(this.currentTabValue))

    this.anchorTabTargets.forEach((tab) => {
      tab.classList.toggle("is-on", !searching && tab.dataset.category === this.currentTabValue)
    })
    this.element.classList.toggle("is-searching", searching)

    if (items.length === 0) {
      this.anchorGridTarget.hidden = true
      this.emptyStateTarget.hidden = false
      return
    }

    this.anchorGridTarget.hidden = false
    this.emptyStateTarget.hidden = true
    this.anchorGridTarget.innerHTML = items.map((a) => `
      <button type="button" class="anchor-chip ${a.id === this.selectedIdValue ? "is-sel" : ""}"
              data-id="${a.id}" data-action="trip-setup#selectAnchor">
        ${a.name}
      </button>
    `).join("")
  }

  // When checkin changes: constrain checkout min and seed its value so the
  // checkout calendar opens on the same month rather than defaulting to today.
  validate(event) {
    if (!event || event.target !== this.checkinTarget) return
    const checkin = this.checkinTarget.value
    if (!checkin) return
    this.checkoutTarget.min = checkin
    if (!this.checkoutTarget.value || this.checkoutTarget.value <= checkin) {
      this.checkoutTarget.value = checkin
    }
  }
}
