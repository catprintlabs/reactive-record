Rails.application.routes.draw do
  
  root :to => "home#index"
  match 'test', :to => "test#index"
  mount ReactiveRecord::Engine => "/rr"
  
end
