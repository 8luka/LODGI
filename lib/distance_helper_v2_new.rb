# Distance helpers for the v2 amenity pipeline.
# Kept separate from anything that might already exist (the _v2_new suffix).
module DistanceHelperV2New
  module_function

  # Computes great-circle distance between two lat/lng points in meters.
  # Returns Integer (rounded).
  def haversine_meters(lat1, lng1, lat2, lng2)
    rad_per_deg = Math::PI / 180
    earth_radius_m = 6_371_000

    dlat = (lat2 - lat1) * rad_per_deg
    dlng = (lng2 - lng1) * rad_per_deg

    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) *
        Math.sin(dlng / 2)**2

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    (earth_radius_m * c).round
  end
end
