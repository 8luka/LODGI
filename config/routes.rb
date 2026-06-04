Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  root to: 'pages#home'
  post "/places/search", to: "places#search"
  get "/map", to: "maps#map", as: :map
  resources :inquiries, only: [ :create ]
  get '/inquiry/clear', to: 'inquiries#clear', as: :clear_inquiry
  patch '/inquiry/weights', to: 'inquiries#update_weights', as: :inquiry_weights
  patch '/inquiry/selected_places', to: 'inquiries#update_selected_places', as: :inquiry_selected_places
  patch '/inquiry/dates', to: 'inquiries#update_dates', as: :inquiry_dates
  post '/inquiry/pin', to: 'inquiries#set_pinned_anchor', as: :inquiry_pin
  patch '/inquiry/pin/name', to: 'inquiries#rename_anchor', as: :inquiry_pin_name
  resources :properties, only: [ :index, :show ] do
     member do
      post 'toggle_favorite'
      get 'popup'
    end
    collection do
       get 'favorites'
    end
    resources :inquiries, only: [ :create ]
  end

  resources :neighborhoods, only: [ :index, :show ]

  post "set_currency", to: "application#set_currency"

  get "favorites", to: "properties#favorites", as: :favorites

end
