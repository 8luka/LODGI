class PagesController < ApplicationController
  def home
    @neighborhoods = Neighborhood.all
    @properties_count = Property.count
    @vendors = Property.select(:vendor, :vendor_image).where(
      vendor: [
        "Sumyca",
        "Hmlet Japan",
        "Mynavi STAY",
        "Blueground Japan",
        "Unito Co., Ltd.",
        "SUMII Apartments"
      ]
    ).group(:vendor, :vendor_image)
  end
end
