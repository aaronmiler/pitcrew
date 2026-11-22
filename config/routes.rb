Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "home#index"

  # Sign-in. OmniAuth handles POST /auth/github and redirects back to the callback.
  get "sign_in", to: "sessions#new", as: :sign_in
  get "auth/github/callback", to: "sessions#create"
  get "auth/failure", to: "sessions#failure"
  delete "sign_out", to: "sessions#destroy", as: :sign_out

  # `export: true` marks a route for js_from_routes to generate a typed
  # path helper for in frontend/lib/routes/.
  namespace :api, defaults: { export: true, format: :json } do
    resource :session, only: [:show]
    resources :users, only: %i[index create destroy]
    resource :settings, only: %i[show update]
    resources :repositories, only: %i[index show update] do
      post :scan, on: :member
      post :sync, on: :collection
    end
    resources :advisories, only: [:index]
    resources :job_failures, only: [:index]
    resources :resolvers, only: [:index]
    resources :gem_source_credentials, only: %i[index create update destroy]
  end

  if Rails.env.development?
    mount GoodJob::Engine => "/good_job"
  end

  # SPA catch-all: client-side routes (/repos/1, /settings, ...) load the app shell.
  # Last, so it never shadows the routes above.
  get "*path", to: "home#index",
    constraints: ->(req) { !req.xhr? && req.format.html? && !req.path.start_with?("/api/") }
end
