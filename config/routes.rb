Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  get "/favicon", to: "catch_all#favicon"
  get "*path", to: "catch_all#index", defaults: { format: 'json' }
  post "*path", to: "catch_all#index", defaults: { format: 'json' }
end
