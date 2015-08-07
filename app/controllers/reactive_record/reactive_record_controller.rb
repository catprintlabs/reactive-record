require 'reactive_record/server_data_cache'

module ReactiveRecord

  class ReactiveRecordController < ApplicationController
    
    def fetch
      render :json => ReactiveRecord::ServerDataCache[params[:pending_fetches]]
    end
        

    def save
      render :json => ReactiveRecord::Base.save_records(params[:models], params[:associations])
    end
      
    def destroy
      render :json => ReactiveRecord::Base.destroy_record(params[:model], params[:id], params[:vector])
    end

  end

end
