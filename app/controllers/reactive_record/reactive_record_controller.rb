require 'reactive_record/server_data_cache'

module ReactiveRecord

  class ReactiveRecordController < ApplicationController
    
    def fetch
      render :json => ReactiveRecord::ServerDataCache[params[:pending_fetches]]
    end
        

    def save
      
      reactive_records = {}

      params[:models].each do |model_to_save|
        attributes = model_to_save[:attributes]
        model = Object.const_get(model_to_save[:model])
        id = attributes[model.primary_key]
        reactive_records[model_to_save[:id]] = if id
          record = model.find(id)
          keys = record.attributes.keys
          attributes.each do |key, value|
            record[key] = value if keys.include? key
          end
          record
        else
          model.new(attributes)
        end
      end
    
      params[:associations].each do |association|
        reactive_records[association[:parent_id]].send("#{association[:attribute]}=", reactive_records[association[:child_id]])
      end  
    
      saved_models = []
      
      reactive_records.each do |reactive_record_id, model|
        model.save
        saved_models << [reactive_record_id, model.class.name, model.attributes]
      end
      
      render :json => {success: true, saved_models: saved_models}
      
    rescue Exception => e
      render :json => {success: false, saved_models: saved_models, message: e.message}
    end
      

    def destroy
      id = params[:id]
      model = Object.const_get(params[:model])
      begin
        record = model.find(id)
        record.destroy
        render :json => {success: true, attributes: {}}
      rescue Exception => e
        render :json => {success: false, record: record, message: e.message}
      end
    end

  end

end
