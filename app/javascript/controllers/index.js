// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)


import NeighborhoodMapController from "./neighborhood_map_controller"

application.register(
  "neighborhood-map",
  NeighborhoodMapController
)
