# Split the page: workspace stays on `/map`, the sections below it move to `/` (home)

## Context

In the previous step the whole page was moved onto `/map`: the **map workspace**
(listings rail · map · priorities panel, `height: 100vh`) followed by three
trailing sections — **neighborhoods**, **about**, and the **footer**. As a
result `/map` scrolls past the workspace, and the home page (`/`) is blank.

The user now wants those trailing sections back on the **home page**, in the
same order, so that:
- `/map` is **only the workspace** — exactly one viewport, **not scrollable**
  (the `.workspace` rule is already `height: 100vh` with a navbar offset, so
  removing the trailing sections is sufficient — no CSS change needed).
- `/` shows the neighborhoods grid → about → footer.

## Changes

### 1. Move the trailing sections out of the map view
File: [app/views/maps/map.html.erb](app/views/maps/map.html.erb)

Keep only the `content_for :head` block and the `<section class="workspace" id="search">…</section>`
(the three-zone workspace). **Delete** everything after the closing `</section>`:
the `#neighborhoods` section, the `.about #about` section, and the `<footer>`.

### 2. Put those sections on the home page
File: [app/views/pages/home.html.erb](app/views/pages/home.html.erb) (currently empty)

Paste the removed markup verbatim, in the same order: `#neighborhoods` section
→ `.about` section → `<footer>`. The neighborhoods section iterates
`@neighborhoods` and links via `neighborhood_path`; about/footer are static.

### 3. Load `@neighborhoods` in the home action
File: [app/controllers/pages_controller.rb](app/controllers/pages_controller.rb)

The home action is currently empty. Add `@neighborhoods = Neighborhood.all`
(matching how `MapsController#map` loads it) so the neighborhoods grid renders.
No other ivars are needed — about and footer are static.

## Notes / out of scope
- The navbar "Explore neighborhoods" link points to the in-page anchor
  `#neighborhoods` ([_navbar.html.erb:23](app/views/shared/_navbar.html.erb#L23)).
  That section now lives on `/`, so the anchor resolves on the home page (and,
  as before, won't scroll from other pages). Not changing this unless asked.
- Server redirects from the prior step (`map_path`) are unaffected.

## Verification
1. `/map` → renders only the workspace (listings rail, map, priorities panel);
   confirm there is **no** neighborhoods/about/footer below it and the page does
   not scroll. Verify with a Playwright `browser_snapshot`.
2. `/` → renders the neighborhoods grid, about section, and footer, in that
   order, with neighborhood cards populated. Verify with a `browser_snapshot`.
3. Confirm 0 console errors on both pages.
