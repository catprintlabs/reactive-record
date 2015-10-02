require 'json'

module ReactiveRecord

  class Base

    include React::IsomorphicHelpers

    before_first_mount do |context|
      if RUBY_ENGINE != 'opal'
        @server_data_cache = ReactiveRecord::ServerDataCache.new(context.controller.acting_user)
      else
        @fetch_scheduled = nil
        @records = Hash.new { |hash, key| hash[key] = [] }
        @class_scopes = Hash.new { |hash, key| hash[key] = {} }
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
      raise "attempt to do a find_by_id of nil.  This will return all records, and is not allowed" if vector[1] == ["find_by_id", nil]
      unless data_loading?
        @pending_fetches << vector
        schedule_fetch
      end
      DummyValue.new
    end

    if RUBY_ENGINE == 'opal'
      class ::Object

        def loaded?
          !loading?
        end

        def loading?
          false
        end

        def present?
          !!self
        end

      end

      class DummyValue < NilClass

        def notify
          unless ReactiveRecord::Base.data_loading?
            ReactiveRecord.loads_pending!           #loads
            ReactiveRecord::WhileLoading.loading!   #loads
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

        def loading?
          true
        end

        def present?
          false
        end

        def coerce(s)
          [self.send("to_#{s.class.name.downcase}"), s]
        end

        def ==(other_value)
          other_value.object_id == self.object_id
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
          notify
          "2001-01-01T00:00:00.000-00:00".to_date
        end

        def acts_as_string?
          true
        end

      end
    end

    def self.schedule_fetch
      #ReactiveRecord.loads_pending!
      #ReactiveRecord::WhileLoading.loading!
      @fetch_scheduled ||= after(0.01) do
        if @pending_fetches.count > 0  # during testing we might reset the context while there are pending fetches
          last_fetch_at = @last_fetch_at
          pending_fetches = @pending_fetches.uniq
          log(["Server Fetching: %o", pending_fetches.to_n])
          start_time = Time.now
          HTTP.post(`window.ReactiveRecordEnginePath`, payload: {pending_fetches: pending_fetches}).then do |response|
            fetch_time = Time.now
            log("       Fetched in:   #{(fetch_time-start_time).to_i}s")
            begin
              ReactiveRecord::Base.load_from_json(response.json)
            rescue Exception => e
              log("Unexpected exception raised while loading json from server: #{e}", :error)
            end
            log("       Processed in: #{(Time.now-fetch_time).to_i}s")
            log(["       Returned: %o", response.json.to_n])
            ReactiveRecord.run_blocks_to_load
            ReactiveRecord::WhileLoading.loaded_at last_fetch_at
            ReactiveRecord::WhileLoading.quiet! if @pending_fetches.empty?
          end.fail do |response|
            log("Fetch failed", :error)
            ReactiveRecord.run_blocks_to_load(response.body)
          end
          @pending_fetches = []
          @last_fetch_at = Time.now
          @fetch_scheduled = nil
        end
      end
    end

    def self.get_type_hash(record)
      {record.class.inheritance_column => record[record.class.inheritance_column]}
    end

    # save records

    if RUBY_ENGINE == 'opal'

      def save(validate, force, &block)

        if data_loading?

          sync!

        elsif force or changed?

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
            unless backing_records[assoc_record.object_id]
              records_to_process << assoc_record
              backing_records[assoc_record.object_id] = assoc_record
            end
            associations << {parent_id: record.object_id, attribute: attribute, child_id: assoc_record.object_id}
          end

          record_index = 0
          while(record_index < records_to_process.count)
            record = records_to_process[record_index]
            output_attributes = {record.model.primary_key => record.id}
            models << {id: record.object_id, model: record.model.model_name, attributes: output_attributes}
            record.attributes.each do |attribute, value|
              if association = record.model.reflect_on_association(attribute)
                if association.collection?
                  value.each { |assoc| add_new_association.call record, attribute, assoc.backing_record }
                elsif value
                  add_new_association.call record, attribute, value.backing_record
                else
                  output_attributes[attribute] = nil
                end
              elsif record.model.reflect_on_aggregation(attribute)
                add_new_association.call record, attribute, value.backing_record
              elsif record.changed?(attribute)
                output_attributes[attribute] = value
              end
            end if record.changed? || (record == self && force)
            record_index += 1
          end

          backing_records.each { |id, record| record.saving! }

          promise = Promise.new

          HTTP.post(`window.ReactiveRecordEnginePath`+"/save", payload: {models: models, associations: associations, validate: validate}).then do |response|
            begin
              response.json[:models] = response.json[:saved_models].collect do |item|
                backing_records[item[0]].ar_instance
              end

              if response.json[:success]
                response.json[:saved_models].each { | item | backing_records[item[0]].sync!(item[2]) }
              else
                log("Reactive Record Save Failed: #{response.json[:message]}", :error)
                response.json[:saved_models].each do | item |
                  log("  Model: #{item[1]}[#{item[0]}]  Attributes: #{item[2]}  Errors: #{item[3]}", :error) if item[3]
                end
              end

              response.json[:saved_models].each { | item | backing_records[item[0]].errors! item[3] }

              yield response.json[:success], response.json[:message], response.json[:models]  if block
              promise.resolve response.json

              backing_records.each { |id, record| record.saved! }

            rescue Exception => e
              puts "Save Failed: #{e}"
            end
          end
          promise
        else
          promise = Promise.new
          yield true, nil if block
          promise.resolve({success: true})
          promise
        end
      end

    else

      def self.save_records(models, associations, acting_user, validate)

        reactive_records = {}
        new_models = []
        saved_models = []

        models.each do |model_to_save|
          attributes = model_to_save[:attributes]
          model = Object.const_get(model_to_save[:model])
          id = attributes.delete(model.primary_key) # if we are saving existing model primary key value will be present
          reactive_records[model_to_save[:id]] = if id
            record = model.find(id)
            keys = record.attributes.keys
            attributes.each do |key, value|
              if keys.include? key
                record[key] = value
              else
                record.send("#{key}=",value)
              end
            end
            record
          else
            record = model.new
            keys = record.attributes.keys
            attributes.each do |key, value|
              if keys.include? key
                record[key] = value
              else
                record.send("#{key}=",value)
              end
            end
            new_models << record
            record
          end
        end

        puts "!!!!!!!!!!!!!!attributes updated"

        ActiveRecord::Base.transaction do

          associations.each do |association|
            parent = reactive_records[association[:parent_id]]
            parent.instance_variable_set("@reactive_record_#{association[:attribute]}_changed", true)
            if parent.class.reflect_on_aggregation(association[:attribute].to_sym)
              puts ">>>>>>AGGREGATE>>>> #{parent.class.name}.send('#{association[:attribute]}=', #{reactive_records[association[:child_id]]})"
              aggregate = reactive_records[association[:child_id]]
              current_attributes = parent.send(association[:attribute]).attributes
              puts "current parent attributes = #{current_attributes}"
              new_attributes = aggregate.attributes
              puts "current child attributes = #{new_attributes}"
              merged_attributes = current_attributes.merge(new_attributes) { |k, current_attr, new_attr| aggregate.send("#{k}_changed?") ? new_attr : current_attr}
              puts "merged attributes = #{merged_attributes}"
              aggregate.assign_attributes(merged_attributes)
              puts "aggregate attributes after merge = #{aggregate.attributes}"
              parent.send("#{association[:attribute]}=", aggregate)
              puts "updated  is frozen? #{aggregate.frozen?}, parent attributes = #{parent.send(association[:attribute]).attributes}"
            elsif parent.class.reflect_on_association(association[:attribute].to_sym).collection?
              puts ">>>>>>>>>> #{parent.class.name}.send('#{association[:attribute]}') << #{reactive_records[association[:child_id]]})"
              #parent.send("#{association[:attribute]}") << reactive_records[association[:child_id]]
              puts "Skipped (should be done by belongs to)"
            else
              puts ">>>>ASSOCIATION>>>> #{parent.class.name}.send('#{association[:attribute]}=', #{reactive_records[association[:child_id]]})"
              parent.send("#{association[:attribute]}=", reactive_records[association[:child_id]])
              puts "updated"
            end
          end if associations

          puts "!!!!!!!!!!!!associations updated"

          has_errors = false

          saved_models = reactive_records.collect do |reactive_record_id, model|
            puts "saving rr_id: #{reactive_record_id} model.object_id: #{model.object_id} frozen? <#{model.frozen?}>"
            if model.frozen?
              puts "validating frozen model #{model.class.name} #{model} (reactive_record_id = #{reactive_record_id})"
              valid = model.valid?
              puts "has_errors before = #{has_errors}, validate= #{validate}, !valid= #{!valid}  (validate and !valid) #{validate and !valid}"
              has_errors ||= (validate and !valid)
              puts "validation complete errors = <#{!valid}>, #{model.errors.messages} has_errors #{has_errors}"
              [reactive_record_id, model.class.name, model.attributes,  (valid ? nil : model.errors.messages)]
            elsif !model.id or model.changed?
              puts "saving #{model.class.name} #{model} (reactive_record_id = #{reactive_record_id})"
              saved = model.check_permission_with_acting_user(acting_user, new_models.include?(model) ? :create_permitted? : :update_permitted?).save(validate: validate)
              has_errors ||= !saved
              messages = model.errors.messages if (validate and !saved) or (!validate and !model.valid?)
              puts "saved complete errors = <#{!saved}>, #{messages} has_errors #{has_errors}"
              [reactive_record_id, model.class.name, model.attributes, messages]
            end
          end.compact

          raise "Could not save all models" if has_errors

        end

        {success: true, saved_models: saved_models }

      rescue Exception => e
        puts "exception #{e}"
        puts e.backtrace.join("\n")

        {success: false, saved_models: saved_models, message: e.message}

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
            promise.resolve response.json
          end
        else
          yield true, nil if block
          promise.resolve({success: true})
        end

        @attributes = {}
        sync!
        @destroyed = true

        promise
      end

    else

      def self.destroy_record(model, id, vector, acting_user)
        model = Object.const_get(model)
        record = if id
          model.find(id)
        else
          ServerDataCache.new(acting_user)[*vector]
        end
        record.check_permission_with_acting_user(acting_user, :destroy_permitted?).destroy
        {success: true, attributes: {}}

      rescue Exception => e
        {success: false, record: record, message: e.message}
      end

    end
  end

end
