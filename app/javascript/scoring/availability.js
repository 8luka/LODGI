// app/javascript/scoring/availability.js
//
// Shared "is this listing available by the user's check-in date?" test, used by the map's hard
// filter (maps_controller) and the favorites comparison filter (favorites_controller). Pure
// function — no DOM access, no side effects.
//
//   availability — the listing's availability string ("now", or a date like "June 15" / "15th").
//   checkin      — the trip check-in as "YYYY-MM-DD", or "" / null when the user gave no dates.
//
// "now" is always available; with no check-in date only "now" passes; otherwise the listing must
// free up on or before the check-in date.
function isAvailableForCheckin(availability, checkin) {
  if (availability === "now") return true
  if (!checkin) return false // manual check with no dates → only "now" passes

  // checkin is "YYYY-MM-DD" — build a local date to avoid UTC-vs-local skew.
  const [y, m, d] = checkin.split("-").map(Number)
  const checkinDate = new Date(y, m - 1, d)

  const clean = availability.replace(/(\d+)(st|nd|rd|th)/i, "$1") // "15th" → "15"
  const avDate = new Date(`${clean} ${y}`)                        // local midnight
  if (isNaN(avDate.getTime())) return false

  return avDate <= checkinDate // available by the time the user arrives
}

export { isAvailableForCheckin }
