require 'reactive_record/server_data_cache'

module ReactiveRecord

  class ReactiveRecordController < ::ApplicationController

    def fetch
      render :json => ReactiveRecord::ServerDataCache[params[:models], params[:associations], params[:pending_fetches], acting_user]
    end


    def save
      render :json => ReactiveRecord::Base.save_records(params[:models], params[:associations], acting_user, params[:validate], true)
    end

    def destroy
      render :json => ReactiveRecord::Base.destroy_record(params[:model], params[:id], params[:vector], acting_user)
    end

  end

end
