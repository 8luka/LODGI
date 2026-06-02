# Amenity Fetching Pipeline v2 — Implementation Spec

Part of the Tokyo short-stay project. This document specifies a **new version** of the amenity-fetching pipeline. It runs alongside the existing v1 pipeline; **none of the v1 files are modified or deleted**.

## 0. Files involved

### Existing files — DO NOT MODIFY OR DELETE

- `lib/tasks/import_places.rake` — v1 task that calls the Google Places API.
- `lib/tasks/generate_places_seed.rake` — v1 task that turns API data into seeds.
- `db/seeds/google_places_seeds.rb` — v1 seed file, a flat hash of all places.

These continue to exist and continue to work as they do today. The v2 pipeline is additive.

### New files to create

- `lib/tasks/import_places_v2.rake` — v2 task that calls the API per category with the new per-category specs.
- `lib/tasks/generate_places_seed_v2.rake` — v2 task that turns v2 API data into the v2 seed file and computes per-property `score_inputs`.
- `db/seeds/google_places_seeds_v2.rb` — v2 seed file, structured by property.
- Two database migrations (see §1).

If you create any additional helper files during the build (e.g., a haversine helper, a shared module), give them the suffix `_v2_new` (e.g., `lib/distance_helper_v2_new.rb`) to keep them distinct from anything that might already exist.

## 1. Database migrations

Two migrations need to run before the v2 pipeline is usable. **The v2 import task must not run until these migrations are in place.**

### Migration 1: Add columns to `places`

```ruby
class AddPropertyAndDistanceToPlaces < ActiveRecord::Migration[7.x]
  def change
    add_reference :places, :property, foreign_key: true, null: true
    add_column :places, :distance_meters, :integer, null: true
    add_index :places, [:property_id, :category]
  end
end
```

Notes:
- `property_id` is nullable. Existing v1 rows have no associated property and stay that way — they're not in the way of anything.
- `distance_meters` is nullable for the same reason.
- The composite index on `(property_id, category)` makes per-property-per-category queries (the only ones the app does) fast.

### Migration 2: Add `score_inputs` to `properties`

```ruby
class AddScoreInputsToProperties < ActiveRecord::Migration[7.x]
  def change
    add_column :properties, :score_inputs, :jsonb, default: {}, null: false
  end
end
```

Notes:
- `jsonb`, not `json` — faster, indexable, supports operators if ever needed.
- Default `{}` so existing properties don't blow up on access.
- `null: false` keeps the column always-present, even before the v2 fetch runs.

## 2. Per-category fetch specifications

For each property, the v2 import task makes nine API calls, one per category. The specifications below are the source of truth.

| Google `places.category` value | API `maxResultCount` | Score input(s) computed |
|---|---|---|
| `convenience_store` | 5 | `nearest_m` |
| `supermarket` | 5 | `nearest_m` |
| `atm` | 5 | `nearest_m` |
| `cafe` | 10 | `tenth_m` |
| `restaurant` | 10 | `tenth_m` |
| `bar` | 10 | `tenth_m` |
| `park` | 5 | `nearest_m`, `fifth_m` |
| `gym` | 5 | `nearest_m` |
| `tourist_attraction` | 10 | `tenth_m` |

**Category strings must match exactly** — the `places.category` value, the keys in `score_inputs`, and the API `includedTypes` value are all the same string. No mapping layer.

**Every call uses these common parameters:**
- `rankPreference: "DISTANCE"` — results come back sorted nearest-first.
- `locationRestriction.circle.center`: the property's `{ latitude, longitude }`.
- `locationRestriction.circle.radius`: not specified (or set very generous, e.g. 2000m). Let `rankPreference: DISTANCE` and `maxResultCount` constrain the result set rather than a tight radius — sparse-area listings should still get whatever's available.
- **Field mask** (in the `X-Goog-FieldMask` header): `places.id,places.displayName,places.location,places.rating`. Keep this minimal to stay in the Essentials billing tier.

## 3. The Google Places API call (v2 endpoint)

The v2 pipeline uses the Places API (New) `searchNearby` endpoint:

```
POST https://places.googleapis.com/v1/places:searchNearby
Headers:
  Content-Type: application/json
  X-Goog-Api-Key: <ENV['GOOGLE_PLACES_API_KEY']>
  X-Goog-FieldMask: places.id,places.displayName,places.location,places.rating

Body (example — restaurants near a property):
{
  "includedTypes": ["restaurant"],
  "maxResultCount": 10,
  "rankPreference": "DISTANCE",
  "locationRestriction": {
    "circle": {
      "center": { "latitude": 35.6938, "longitude": 139.7036 },
      "radius": 2000.0
    }
  }
}
```

Response shape (relevant fields only):

```json
{
  "places": [
    {
      "id": "ChIJ...",
      "displayName": { "text": "Restaurant Name", "languageCode": "en" },
      "location": { "latitude": 35.6940, "longitude": 139.7034 },
      "rating": 4.2
    },
    ...
  ]
}
```

If the response has no `places` array (no results), treat it as an empty array.

## 4. `import_places_v2.rake`

This task is the API-calling layer. It iterates properties × categories, fetches places, and persists results.

### What it does

```
For each Property in Property.all:
  For each category in CATEGORIES (the 9 from §2):
    1. Build the request body for that category × that property.
    2. POST to the Places API (New) searchNearby endpoint.
    3. Parse response; extract places (id, name, lat, lng, rating).
    4. For each returned place, compute distance from the property
       (haversine, in meters, rounded to integer).
    5. Persist N Place records (where N = response count), each with:
         - property_id = current property's id
         - category    = current category string
         - place_id    = Google place id
         - name        = displayName.text
         - latitude    = location.latitude
         - longitude   = location.longitude
         - rating      = rating (nil if absent)
         - distance_meters = computed distance (rounded)
    6. After all 9 categories complete for this property, compute
       and persist the property's score_inputs (see §6).
```

**Duplicates are allowed.** If the task runs twice, the same place may end up associated with the same property multiple times. This is acceptable — the task is not idempotent and that's by design (per project decision). Re-running creates new rows alongside old ones; the user accepts this when invoking the task.

### Transaction scope

Wrap the per-property loop (all 9 category calls + the score_inputs write) in a single transaction:

```ruby
ActiveRecord::Base.transaction do
  CATEGORIES.each do |category, config|
    # fetch + persist
  end
  property.update!(score_inputs: build_score_inputs(property))
end
```

So a partial failure on one property doesn't leave that property half-populated. Other properties' transactions are independent — one bad property doesn't sink the run.

### Logging

Log per-property progress: "Property 12 (Kagurazaka Studio): 9 categories, 78 places fetched." Log errors loudly enough to spot at end of run. Don't abort the whole task on one property's failure — log and continue.

### Rate limiting

Pause ~100-200ms between API calls. For a ~60-property run that's roughly 540 calls × 200ms = ~2 minutes of total wall time. Acceptable.

### Environment

Requires `ENV['GOOGLE_PLACES_API_KEY']` to be set. Fail fast with a clear error if missing.

## 5. Haversine distance helper

Hand-rolled is fine — it's ~10 lines and avoids a gem dependency:

```ruby
# Computes great-circle distance between two lat/lng points in meters.
# Returns Integer (rounded).
def haversine_meters(lat1, lng1, lat2, lng2)
  rad_per_deg = Math::PI / 180
  earth_radius_m = 6_371_000

  dlat = (lat2 - lat1) * rad_per_deg
  dlng = (lng2 - lng1) * rad_per_deg

  a = Math.sin(dlat / 2) ** 2 +
      Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) *
      Math.sin(dlng / 2) ** 2

  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  (earth_radius_m * c).round
end
```

Place this in a helper module — suggested location: `lib/distance_helper_v2_new.rb`, module `DistanceHelperV2New`. Include or extend from the rake tasks that need it.

## 6. Building `score_inputs`

After all 9 categories for a property are fetched and persisted, compute the property's `score_inputs` and update the row.

### The shape

```ruby
{
  convenience_store:  { nearest_m: <int> },
  supermarket:        { nearest_m: <int> },
  atm:                { nearest_m: <int> },
  cafe:               { tenth_m: <int> },
  restaurant:         { tenth_m: <int> },
  bar:                { tenth_m: <int> },
  park:               { nearest_m: <int>, fifth_m: <int> },
  gym:                { nearest_m: <int> },
  tourist_attraction: { tenth_m: <int> }
}
```

Keys match `places.category` strings exactly.

### Computation rules

For each category for the property:

1. Pull the freshly inserted Place rows: `property.places.where(category: cat).order(:distance_meters)`.
   - Note: order by `distance_meters`, not by insertion order. The API returns sorted, but ordering by the stored distance is the canonical source of truth.

2. Apply the per-category rule:
   - **Proximity categories** (`convenience_store`, `supermarket`, `atm`, `gym`): take the 1st row's `distance_meters` as `nearest_m`.
   - **Density categories** (`cafe`, `restaurant`, `bar`, `tourist_attraction`): take the 10th row's `distance_meters` as `tenth_m`. **Fallback:** if fewer than 10 rows exist, use the distance of the *last* row. If zero rows exist, set the value to `nil`.
   - **Parks**: take the 1st row's `distance_meters` as `nearest_m`, and the 5th row's `distance_meters` as `fifth_m`. **Fallback for `fifth_m`:** if fewer than 5 rows, use the distance of the last row. If zero rows, both `nearest_m` and `fifth_m` are `nil`.

3. Build the nested hash, persist via `property.update!(score_inputs: hash)`.

### Idempotency of the score_inputs build

When recomputing for a property that already has score_inputs from a prior run, **`update!` overwrites the whole column**. That's the right behavior — score_inputs reflects the current set of place rows, and a re-run means a re-computation. (Note that duplicate Place rows from a prior run *do* affect this — see §7 below.)

## 7. Handling re-runs: a warning

Because the task is non-idempotent on the `places` table, **re-running `import_places_v2` doubles the Place rows for affected properties**, which means `score_inputs` will be computed off a *larger* sorted result set than intended (e.g., the "10th nearest" might be drawn from 20 rows after a second run).

**This is acceptable per project decision**, but the spec should document it loudly. Add to the rake task's description:

> WARNING: This task creates new place rows on each run. Running it twice for the same property doubles its place rows. score_inputs will be computed from all current rows, which may give incorrect (over-saturated) density signals after a re-run. To get clean data, delete the property's places before re-running.

A clean re-run incantation worth documenting in comments:

```ruby
# To re-import for a single property cleanly:
# property.places.destroy_all
# rake places:import_v2[property_id]
```

(Whether to support a `property_id` argument to the task is a judgment call — useful but optional for v1.)

## 8. `generate_places_seed_v2.rake`

This task does **not** call the API. It reads from the database (after `import_places_v2` has run) and produces the seed file at `db/seeds/google_places_seeds_v2.rb`.

### What it does

```
1. Open db/seeds/google_places_seeds_v2.rb for writing.
2. Iterate Property.all in id order.
3. For each property, dump a section structured like:

   PROPERTY_PLACES_V2 = {
     <property_id_1> => {
       score_inputs: { ... the score_inputs hash for this property ... },
       places: [
         { category: "convenience_store", place_id: "...", name: "...",
           latitude: ..., longitude: ..., rating: ..., distance_meters: ... },
         { category: "convenience_store", ... },
         ...
         { category: "tourist_attraction", ... }
       ]
     },
     <property_id_2> => { ... },
     ...
   }

4. Write the file. Pretty-print so it's diffable in version control.
```

The structure groups by `property_id` (per your spec: each place's `property_id` is the id of the property from which it was looked up).

### The new seed file: `google_places_seeds_v2.rb`

When loaded (e.g., during a future `db:seed`), it should:

```ruby
PROPERTY_PLACES_V2.each do |property_id, payload|
  property = Property.find_by(id: property_id)
  next unless property  # skip if property no longer exists

  payload[:places].each do |place_attrs|
    Place.create!(place_attrs.merge(property_id: property_id))
  end

  property.update!(score_inputs: payload[:score_inputs])
end
```

So loading the seed creates Place rows AND restores each property's `score_inputs` in one pass.

**Do not run this seed file as part of this build.** The user will run it manually when they choose to.

### Idempotency of seeding

Same warning applies: loading the seed twice creates duplicate Place rows. The seed file should include a comment at the top warning about this, with the suggested clean-load pattern:

```ruby
# WARNING: Running this seed creates new Place rows. To re-seed cleanly:
# Place.where.not(property_id: nil).destroy_all
# load 'db/seeds/google_places_seeds_v2.rb'
```

## 9. Constants and configuration

To keep specs and rake tasks aligned, define the per-category config in one place — suggested location: a `CATEGORIES` constant at the top of `import_places_v2.rake` (or a shared `lib/categories_v2_new.rb` module if both rake tasks need it):

```ruby
CATEGORIES_V2 = {
  "convenience_store"  => { max: 5,  score: :proximity },
  "supermarket"        => { max: 5,  score: :proximity },
  "atm"                => { max: 5,  score: :proximity },
  "cafe"               => { max: 10, score: :density },
  "restaurant"         => { max: 10, score: :density },
  "bar"                => { max: 10, score: :density },
  "park"               => { max: 5,  score: :park_hybrid },  # uses 1st + 5th
  "gym"                => { max: 5,  score: :proximity },
  "tourist_attraction" => { max: 10, score: :density }
}
```

The `score` field tells `generate_places_seed_v2.rake` (and any score-computation helper) which extraction rule to use.

## 10. Test plan (hand-tested, no formal unit tests required)

1. Run migrations. Verify `places.property_id`, `places.distance_meters`, and `properties.score_inputs` exist.
2. Confirm existing v1 rows in `places` survive the migration with `property_id = NULL` and `distance_meters = NULL`. Existing v1 code continues to work.
3. Run `rake places:import_v2` on a database with ~3 hand-picked properties (or `Property.limit(3)`). Verify:
   - Each property gets ~9 categories' worth of new place rows (counts vary by what's available; expect 30-50 rows per property).
   - Each new row has the right `property_id`, `category`, `distance_meters`.
   - Each property's `score_inputs` is populated with all 9 category keys.
   - Density categories that returned <10 results have `tenth_m` = distance of last result.
   - If a category returned 0 results, that category's score_inputs values are `nil`.
4. Run `rake places:generate_seed_v2`. Verify `db/seeds/google_places_seeds_v2.rb` is generated, contains all expected properties, and is structurally valid Ruby (`ruby -c db/seeds/google_places_seeds_v2.rb` should pass).
5. **Do not load the generated seed file during this build** — confirm it exists, not that it works.

## 11. Explicit non-goals

- **Do not modify or delete** `import_places.rake`, `generate_places_seed.rake`, or `google_places_seeds.rb`.
- **Do not run the API** as part of generating any code or running tests during this build — the rake tasks are for the user to invoke manually.
- **Do not run the v2 seed file** during this build.
- **No deduplication** of place rows. Duplicates across runs are accepted.
- **No live API calls** at runtime — the API is only ever called by `import_places_v2.rake`.
- **No score formula implementation** — that is a separate spec to come later. This pipeline only builds and stores `score_inputs`; consuming them is out of scope here.

## 12. Open questions worth confirming before coding

- Whether the `import_places_v2` task takes an optional `property_id` argument to fetch for one property at a time. Recommended yes (useful for testing and re-runs), but not strictly required.
- Whether to add a `created_via: "v2"` column or similar to `places` to distinguish v1 vs v2 rows. Per project decision, NOT required — user accepts that v1 and v2 rows coexist undifferentiated. Mentioning it here only to confirm it's deliberately out of scope.
- The exact Rails version in use, in case migration syntax (`ActiveRecord::Migration[7.x]`) needs adjusting. Default to whatever the existing migrations in the project use.
