class AnchorTravelTimesJob < ApplicationJob
  queue_as :default

  # anchor is a Place or Neighborhood record (serialized over GlobalID).
  def perform(anchor)
    AnchorTravelTimesService.call(anchor)
  end
end
