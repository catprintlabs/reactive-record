ReactiveRecord::Engine.routes.draw do
  root :to => "reactive_record#fetch", via: :post
  #match 'fetch', to: 'reactive_record#fetch', via: :post
  #resources :fetches
end
