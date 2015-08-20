require 'json'

module ReactiveRecord

  class Base
    
    include React::IsomorphicHelpers
        
    before_first_mount do
      if RUBY_ENGINE != 'opal'
        @server_data_cache = ReactiveRecord::ServerDataCache.new
      else
        @records = Hash.new { |hash, key| hash[key] = [] }
        if on_opal_client? 
          @pending_fetches = []
          @last_fetch_at = Time.now
          unless `typeof window.ReactiveRecordInitialData === 'undefined'`
            log(["Reactive record prerendered data being loaded: %o", `window.ReactiveRecordInitialData`])
            JSON.from_object(`window.ReactiveRecordInitialData`).each do |hash|
              load_from_json hash
            end
          end
        end
      end
    end
    
    def records
      self.class.instance_variable_get(:@records)
    end
    
    # Prerendering db access (returns nil if on client):
    # at end of prerendering dumps all accessed records in the footer
    
    isomorphic_method(:fetch_from_db) do |f, vector|
      # vector must end with either "*all", or be a simple attribute
      f.send_to_server [vector.shift.name, *vector] if  RUBY_ENGINE == 'opal'
      f.when_on_server { @server_data_cache[*vector] }
    end
    
    isomorphic_method(:find_in_db) do |f, klass, attribute, value|
      f.send_to_server klass.name, attribute, value if  RUBY_ENGINE == 'opal'
      f.when_on_server { @server_data_cache[klass, ["find_by_#{attribute}", value], :id] }
    end
    
    prerender_footer do
      if @server_data_cache
        json = @server_data_cache.as_json.to_json  # can this just be to_json?
        @server_data_cache.clear_requests
      else
        json = {}.to_json
      end
      path = ::Rails.application.routes.routes.detect do |route| 
        # not sure why the second check is needed.  It happens in the test app
        route.app == ReactiveRecord::Engine or (route.app.respond_to?(:app) and route.app.app == ReactiveRecord::Engine)
      end.path.spec
      "<script type='text/javascript'>\n"+
        "window.ReactiveRecordEnginePath = '#{path}';\n"+
        "if (typeof window.ReactiveRecordInitialData === 'undefined') { window.ReactiveRecordInitialData = [] }\n" +
        "window.ReactiveRecordInitialData.push(#{json})\n"+
      "</script>\n"
    end if RUBY_ENGINE != 'opal'
    
    # Client side db access (never called during prerendering):
    
    # Always returns an object of class DummyValue which will act like most standard AR field types
    # Whenever a dummy value is accessed it notify React that there are loads pending so appropriate rerenders
    # will occur when the value is eventually loaded.
    
    # queue up fetches, and at the end of each rendering cycle fetch the records
    # notify that loads are pending

    def self.load_from_db(*vector)
      return nil unless on_opal_client? # this can happen when we are on the server and a nil value is returned for an attribute
      # only called from the client side
      # pushes the value of vector onto the a list of vectors that will be loaded from the server when the next
      # rendering cycle completes.  
      # takes care of informing react that there are things to load, and schedules the loader to run
      # Note there is no equivilent to find_in_db, because each vector implicitly does a find.
      unless data_loading?
        @pending_fetches << vector
        schedule_fetch
      end
      DummyValue.new
    end
    
    class DummyValue < NilClass
      
      def notify
        unless ReactiveRecord::Base.data_loading?
          ReactiveRecord.loads_pending!
          ReactiveRecord::WhileLoading.loading!
        end
      end
      
      def initialize()
        notify
      end
      
      def method_missing(method, *args, &block)
        if 0.respond_to? method
          notify
          0.send(method, *args, &block)
        elsif "".respond_to? method
          notify
          "".send(method, *args, &block)
        else
          super
        end
      end
      
      def coerce(s)
        [self.send("to_#{s.class.name.downcase}"), s]
      end
      
      def ==(other_value)
        other_value.is_a? DummyValue
      end
      
      def to_s 
        notify
        ""
      end
      
      def to_f
        notify
        0.0
      end
      
      def to_i
        notify
        0
      end
      
      def to_numeric
        notify
        0
      end
      
      def to_date
        "2001-01-01T00:00:00.000-00:00".to_date
      end
      
      def acts_as_string?
        true
      end
      
    end
    

    def self.schedule_fetch
      @fetch_scheduled ||= after(0.001) do
        last_fetch_at = @last_fetch_at
        pending_fetches = @pending_fetches.uniq
        log(["Server Fetching: %o", pending_fetches.to_n])
        HTTP.post(`window.ReactiveRecordEnginePath`, payload: {pending_fetches: pending_fetches}).then do |response|
          begin
            ReactiveRecord::Base.load_from_json(response.json)
          rescue Exception => e
            log("Exception raised while loading json from server: #{e}", :error)
          end
          log(["       Returned: %o", response.json.to_n])
          ReactiveRecord.run_blocks_to_load
          ReactiveRecord::WhileLoading.loaded_at last_fetch_at
        end if @pending_fetches.count > 0
        @pending_fetches = []
        @last_fetch_at = Time.now
        @fetch_scheduled = nil
      end
    end
    
    def self.get_type_hash(record)
      {record.class.inheritance_column => record[record.class.inheritance_column]}
    end
    
    # save records
    
    if RUBY_ENGINE == 'opal'
      
      def save(&block) 

        if data_loading?

          sync!

        elsif changed?
          
          # we want to pass not just the model data to save, but also enough information so that on return from the server
          # we can update the models on the client

          # input
          records_to_process = [self]  # list of records to process, will grow as we chase associations
          # outputs
          models = [] # the actual data to save {id: record.object_id, model: record.model.model_name, attributes: changed_attributes}
          associations = [] # {parent_id: record.object_id, attribute: attribute, child_id: assoc_record.object_id}  
          # used to keep track of records that have been processed for effeciency     
          backing_records = {self.object_id => self} # for quick lookup of records that have been or will be processed [record.object_id] => record  

          add_new_association = lambda do |record, attribute, assoc_record|
            if assoc_record.changed?
              unless backing_records[assoc_record.object_id]
                records_to_process << assoc_record
                backing_records[assoc_record.object_id] = assoc_record
              end
              associations << {parent_id: record.object_id, attribute: attribute, child_id: assoc_record.object_id}
            end
          end

          record_index = 0
          while(record_index < records_to_process.count)
            record = records_to_process[record_index]
            output_attributes = {record.model.primary_key => record.id}
            models << {id: record.object_id, model: record.model.model_name, attributes: output_attributes}
            record.attributes.each do |attribute, value|
              if association = record.model.reflect_on_association(attribute)
                if association.collection? 
                  value.each { |assoc| add_new_association.call record, attribute, assoc.instance_variable_get(:@backing_record) }
                else
                  add_new_association.call record, attribute, value.instance_variable_get(:@backing_record)
                end
              elsif record.model.reflect_on_aggregation(attribute)
                add_new_association.call record, attribute, value.instance_variable_get(:@backing_record)
              elsif record.changed?(attribute)
                output_attributes[attribute] = value
              end
            end
            record_index += 1
          end
          
          backing_records.each { |id, record| record.saving! }
          
          promise = Promise.new

          HTTP.post(`window.ReactiveRecordEnginePath`+"/save", payload: {models: models, associations: associations}).then do |response|
            
            response.json[:saved_models].each do |item|
              internal_id, klass, attributes = item
              backing_records[internal_id].sync!(attributes)
            end
            yield response.json[:success], response.json[:message] if block
            promise.resolve response.json[:success], response.json[:message]
          end
          promise
        end
      end
      
    else
      
      def self.save_records(models, associations)
        
        reactive_records = {}

        models.each do |model_to_save|
          attributes = model_to_save[:attributes]
          model = Object.const_get(model_to_save[:model])
          id = attributes[model.primary_key] # if we are saving existing model primary key value will be present
          reactive_records[model_to_save[:id]] = if id
            record = model.find(id)
            keys = record.attributes.keys
            attributes.each do |key, value|
              record[key] = value if keys.include? key
            end
            record
          else
            record = model.new
            keys = record.attributes.keys
            attributes.each do |key, value|
              record[key] = value if keys.include? key
            end
            record
          end
        end
        
        associations.each do |association|
          begin
            if reactive_records[association[:parent_id]].class.reflect_on_aggregation(association[:attribute].to_sym)
              reactive_records[association[:parent_id]].send("#{association[:attribute]}=", reactive_records[association[:child_id]])
            elsif reactive_records[association[:parent_id]].class.reflect_on_association(association[:attribute].to_sym).collection?
              reactive_records[association[:parent_id]].send("#{association[:attribute]}") << reactive_records[association[:child_id]]
            else
              reactive_records[association[:parent_id]].send("#{association[:attribute]}=", reactive_records[association[:child_id]])
            end
          end
        end if associations 

        saved_models = reactive_records.collect do |reactive_record_id, model|
          unless model.frozen? 
            saved = model.save
            [reactive_record_id, model.class.name, model.attributes, saved]
          end
        end.compact
      
        {success: true, saved_models: saved_models || []}
      
      rescue Exception => e
        
        {success: false, saved_models: saved_models || [], message: e.message}
        
      end
      
    end
    
    # destroy records
    
    if RUBY_ENGINE == 'opal'
      
      def destroy(&block)

        return if @destroyed

        model.reflect_on_all_associations.each do |association|
          if association.collection?
            attributes[association.attribute].replace([]) if attributes[association.attribute]
          else
            @ar_instance.send("#{association.attribute}=", nil)
          end
        end

        promise = Promise.new

        if id or vector
          HTTP.post(`window.ReactiveRecordEnginePath`+"/destroy", payload: {model: ar_instance.model_name, id: id, vector: vector}).then do |response|
            yield response.json[:success], response.json[:message] if block
            promise.resolve response.json[:success], response.json[:message]
          end
        else
          yield true, nil if block
          promise.resolve true, nil
        end
        
        @attributes = {}
        sync!
        @destroyed = true
        
        promise
      end
      
    else
      
      def self.destroy_record(model, id, vector)
        model = Object.const_get(model)
        record = if id 
          model.find(id)
        else
          ServerDataCache.new[*vector]
        end
        record.destroy
        {success: true, attributes: {}}
      rescue Exception => e
        {success: false, record: record, message: e.message}
      end
      
    end
  end

end