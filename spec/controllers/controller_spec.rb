require 'spec_helper'

describe ReactiveRecord::ReactiveRecordController do
  it "will return an empty json array if no fetch parameters are provided" do
    get :fetch, { use_route: :reactive_records }
  end
end