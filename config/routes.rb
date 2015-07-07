ReactiveRecord::Engine.routes.draw do
  root :to => "reactive_record#fetch", via: :post
  match 'save', to: 'reactive_record#save', via: :post
end
