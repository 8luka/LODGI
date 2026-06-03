namespace :places do
  desc "Verify v2 place rows and score_inputs for a property (read-only, no API calls). Args: [property_id]"
  task :verify_v2, [:property_id] => :environment do |_t, args|
    scope = args[:property_id].present? ? Property.where(id: args[:property_id]) : Property.all

    all_pass = true

    scope.find_each do |property|
      rows = property.places.order(:distance_meters)
      puts "\n=== Property #{property.id} (#{property.name}) ==="
      puts "  v2 place rows total: #{rows.count}"

      # --- Import ran check ---
      pass_any_rows = rows.any?
      puts "  [#{pass_any_rows ? 'PASS' : 'FAIL'}] import has run (at least 1 place row exists)"
      all_pass &&= pass_any_rows

      # --- Row integrity checks ---
      # property_id: every row returned by property.places already has property_id = property.id
      # (that is what the has_many association scopes on), but we assert it explicitly.
      wrong_property_id = rows.where.not(property_id: property.id).count
      nil_place_id      = rows.where(place_id: nil).count
      nil_distance      = rows.where(distance_meters: nil).count
      nil_name          = rows.where(name: nil).count
      nil_lat           = rows.where(latitude: nil).count
      nil_lng           = rows.where(longitude: nil).count

      pass_property_id = wrong_property_id.zero?
      pass_place_id    = nil_place_id.zero?
      pass_distance    = nil_distance.zero?
      pass_name        = nil_name.zero?
      pass_coords      = nil_lat.zero? && nil_lng.zero?

      puts "  [#{pass_property_id ? 'PASS' : 'FAIL'}] all rows have correct property_id (wrong: #{wrong_property_id})"
      puts "  [#{pass_place_id    ? 'PASS' : 'FAIL'}] all rows have place_id           (nil: #{nil_place_id})"
      puts "  [#{pass_distance    ? 'PASS' : 'FAIL'}] all rows have distance_meters    (nil: #{nil_distance})"
      puts "  [#{pass_name        ? 'PASS' : 'FAIL'}] all rows have name               (nil: #{nil_name})"
      puts "  [#{pass_coords      ? 'PASS' : 'FAIL'}] all rows have lat/lng (nil lat: #{nil_lat}, nil lng: #{nil_lng})"

      all_pass &&= pass_property_id && pass_place_id && pass_distance && pass_name && pass_coords

      # Per-category counts (informational — shows which categories have been fetched)
      puts "  Per-category row counts:"
      CATEGORIES_V2.each_key do |cat|
        puts "    #{cat.ljust(22)} #{rows.where(category: cat).count} rows"
      end

      # --- score_inputs checks ---
      puts "  score_inputs checks:"
      stored = property.score_inputs

      # 1. score_inputs has all expected keys (10 categories + derived peace_quiet_score) —
      #    proves the import wrote it (not just the default {}).
      expected_keys = (CATEGORIES_V2.keys + ["peace_quiet_score"]).sort
      stored_keys   = stored.keys.sort
      pass_keys    = (expected_keys == stored_keys)
      missing_keys = expected_keys - stored_keys
      puts "  [#{pass_keys ? 'PASS' : 'FAIL'}] score_inputs has all #{expected_keys.size} expected keys"
      puts "    missing: #{missing_keys.inspect}" unless pass_keys
      all_pass &&= pass_keys

      # 2. peace_quiet_score is a number in [0, 1]
      pq = stored["peace_quiet_score"]
      pass_pq = pq.is_a?(Numeric) && pq >= 0.0 && pq <= 1.0
      puts "  [#{pass_pq ? 'PASS' : 'FAIL'}] peace_quiet_score in [0,1] (value: #{pq.inspect})"
      all_pass &&= pass_pq

      # 3. Per-category value cross-check
      CATEGORIES_V2.each do |category, config|
        cat_rows = rows.where(category: category).order(:distance_meters)

        if config[:score] == :station
          all_pass &&= check_station(category, cat_rows, stored)
        else
          all_pass &&= check_distance_category(category, config[:score], cat_rows, stored)
        end
      end
    end

    puts "\n#{'=' * 50}"
    if all_pass
      puts "ALL PASS"
    else
      puts "FAILURES detected — see above."
      exit 1
    end
  end

  def check_station(category, cat_rows, stored)
    pass = cat_rows.any?
    cat = stored[category] || {}
    time_val = cat["time_to_station"]
    name_val = cat["station_name"]
    time_info =
      if time_val
        ", time_to_station: #{time_val} min"
      else
        ", time_to_station: nil (set ROUTES_API to populate)"
      end
    puts "    [#{pass ? 'PASS' : 'FAIL'}] #{category} — #{cat_rows.count} row(s) found, " \
         "station_name: #{name_val.inspect}#{time_info}"
    pass
  end

  def check_distance_category(category, score_type, cat_rows, stored)
    expected =
      case score_type
      when :proximity
        { "nearest_m" => cat_rows.first&.distance_meters }
      when :density
        { "tenth_m" => (cat_rows[9] || cat_rows.last)&.distance_meters }
      when :park_hybrid
        { "nearest_m" => cat_rows.first&.distance_meters,
          "fifth_m" => (cat_rows[4] || cat_rows.last)&.distance_meters }
      end

    stored_cat = stored[category] || {}
    pass = (expected == stored_cat)
    puts "    [#{pass ? 'PASS' : 'FAIL'}] #{category}"
    puts "      expected: #{expected.inspect}" unless pass
    puts "      stored:   #{stored_cat.inspect}" unless pass
    pass
  end
end
