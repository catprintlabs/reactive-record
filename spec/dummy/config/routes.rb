require 'reactive_record'
Rails.application.routes.draw do
  
  root :to => "home#index"
  #mount ReactiveRecord::Engine => "reactive_record"
  match 'reactive_record', to: 'reactive_record/reactive_record#fetch', via: :post
  
end
