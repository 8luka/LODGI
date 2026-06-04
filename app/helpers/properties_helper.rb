module PropertiesHelper
  # "Your life from here" card. category => display config; insertion order = render order
  # (daily essentials -> food & drink -> lifestyle). Icons / labels / place_label mirror the
  # priorities-panel toggle table (_priorities_panel.html.erb) so the two stay in sync.
  #   :type :proximity -> nearest place name + walk time
  #   :type :density   -> count within DENSITY_RADIUS_M + nearest walk time (falls back to proximity)
  LIFE_CATEGORIES = {
    "convenience_store"  => { icon: "tabler:building-store",  singular: "Convenience store", plural: "convenience stores", place_label: "convenience stores", type: :proximity },
    "supermarket"        => { icon: "tabler:shopping-cart",   singular: "Supermarket",       plural: "supermarkets",       place_label: "supermarkets",       type: :proximity },
    "atm"                => { icon: "tabler:building-bank",    singular: "ATM",               plural: "ATMs",               place_label: "ATMs",               type: :proximity },
    "cafe"               => { icon: "tabler:coffee",          singular: "Café",              plural: "cafés",              place_label: "cafes",              type: :density },
    "restaurant"         => { icon: "tabler:tools-kitchen-2", singular: "Restaurant",        plural: "restaurants",        place_label: "restaurants",        type: :density },
    "bar"                => { icon: "tabler:glass-full",       singular: "Bar",               plural: "bars",               place_label: "bars",               type: :density },
    "park"               => { icon: "tabler:tree",            singular: "Park",              plural: "parks",              place_label: "parks",              type: :proximity },
    "gym"                => { icon: "tabler:barbell",          singular: "Gym",               plural: "gyms",               place_label: "gyms",               type: :proximity },
    "tourist_attraction" => { icon: "tabler:camera",          singular: "Tourist spot",      plural: "tourist spots",      place_label: "tourist spots",      type: :density }
  }.freeze

  # Shown when the visitor has toggled nothing — a sensible daily-life snapshot.
  DEFAULT_LIFE_CATEGORIES = %w[convenience_store supermarket restaurant].freeze
  DENSITY_RADIUS_M = 500

  # place_label (as stored in inquiry.selected_places) -> category.
  PLACE_LABEL_TO_CATEGORY = LIFE_CATEGORIES.each_with_object({}) do |(cat, cfg), h|
    h[cfg[:place_label]] = cat
  end.freeze

  # The active toggle categories (e.g. "supermarket", "restaurant") for the inquiry's selected_places
  # labels. Feeds the fit-summary score so the show page matches the map's score (which scores the
  # same toggles). No default trio here — scoring must mirror exactly what's toggled, like the map.
  def score_toggle_categories(selected_places)
    Array(selected_places).filter_map { |label| PLACE_LABEL_TO_CATEGORY[label] }
  end

  # Ordered [{ icon:, text: }] rows for the property's "your life from here" card. selected_places is
  # the inquiry's toggled labels ("convenience stores", "cafes", ...); empty -> DEFAULT_LIFE_CATEGORIES.
  def life_from_here_rows(property, selected_places)
    categories = Array(selected_places).filter_map { |label| PLACE_LABEL_TO_CATEGORY[label] }
    categories = DEFAULT_LIFE_CATEGORIES if categories.empty?
    # Reorder to the fixed essentials -> food -> lifestyle sequence, de-duped.
    categories = LIFE_CATEGORIES.keys & categories

    by_category = property.places
                          .where.not(distance_meters: nil)
                          .order(:distance_meters)
                          .group_by(&:category)

    categories.filter_map do |category|
      places = by_category[category]
      next if places.blank?

      cfg = LIFE_CATEGORIES[category]
      text = cfg[:type] == :density ? density_text(places, cfg) : proximity_text(places.first, cfg)
      { icon: cfg[:icon], text: text }
    end
  end

  private

  # "7-Eleven · 1 min walk" — nearest place's name (falling back to the category noun) + walk time.
  def proximity_text(place, cfg)
    name = place.name.presence || cfg[:singular]
    "#{name} · #{walk_minutes(place.distance_meters)} min walk"
  end

  # "23 restaurants within 500m · nearest 1 min" — count within radius + nearest walk time. If none
  # fall within the radius, fall back to the nearest one regardless of distance.
  def density_text(places, cfg)
    nearest = places.first
    within = places.count { |p| p.distance_meters <= DENSITY_RADIUS_M }
    return "Nearest #{cfg[:singular].downcase} · #{walk_minutes(nearest.distance_meters)} min walk" if within.zero?

    count_label = within >= 20 ? "20+" : within.to_s
    "#{count_label} #{cfg[:plural]} within #{DENSITY_RADIUS_M}m · nearest #{walk_minutes(nearest.distance_meters)} min"
  end

  # Stored straight-line meters -> walk minutes. 1.3 approximates street routing; floor at 1 min.
  def walk_minutes(meters)
    return 1 if meters < 80

    ((meters * 1.3) / 80.0).round
  end
end
