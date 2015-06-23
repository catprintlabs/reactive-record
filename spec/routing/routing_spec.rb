require "spec_helper"

describe ReactiveRecord::ReactiveRecordController do 
  routes { ReactiveRecord::Engine.routes }
  it "routes / to the reactive record controller" do
    expect(:get => "/").to route_to(:controller => "reactive_record/reactive_record", :action => "fetch")
  end
end