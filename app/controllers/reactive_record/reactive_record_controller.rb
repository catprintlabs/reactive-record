require 'reactive_record/server_data_cache'

module ReactiveRecord

  class ReactiveRecordController < ::ApplicationController

    def fetch
      render :json => ReactiveRecord::ServerDataCache[
        (params[:models] || []).map(&:with_indifferent_access),
        (params[:associations] || []).map(&:with_indifferent_access),
        params[:pending_fetches],
        acting_user
      ]
    rescue Exception => e
      render json: {error: e.message, backtrace: e.backtrace}, status: 500
    end

    def save
      render :json => ReactiveRecord::Base.save_records(
        (params[:models] || []).map(&:with_indifferent_access),
        (params[:associations] || []).map(&:with_indifferent_access),
        acting_user,
        params[:validate],
        true
      )
    rescue Exception => e
      render json: {error: e.message, backtrace: e.backtrace}, status: 500
    end

    def destroy
      render :json => ReactiveRecord::Base.destroy_record(
        params[:model],
        params[:id],
        params[:vector],
        acting_user
      )
    rescue Exception => e
      render json: {error: e.message, backtrace: e.backtrace}, status: 500
    end

  end

end
