Rails.application.routes.draw do
  
  root :to => "home#index"
  mount ReactiveRecord::Engine => "/rr"
  
end
