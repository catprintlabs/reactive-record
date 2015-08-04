module ReactiveRecord
  class Base
  
    # Its all about lazy loading. This prevents us from grabbing enormous association collections, or large attributes
    # unless they are explicitly requested.
  
    # During prerendering we get each attribute as its requested and fill it in both on the javascript side, as well as
    # remember that the attribute needs to be part of the download to client. 
  
    # On the client we fill in the record data with empty values (nil, or one element collections) but only as the attribute
    # is requested.  Each request queues up a request to get the real data from the server.
  
    # The ReactiveRecord class serves two purposes.  First it is the unique data corresponding to the last known state of a 
    # database record.  This means All records matching a specific database record are unique.  This is unlike AR but is 
    # important both for the lazy loading and also so that when values change react can be informed of the change.
  
    # Secondly it serves as name space for all the ReactiveRecord specific methods, so every AR Instance has a ReactiveRecord
  
    # Because there is no point in generating a new ar_instance everytime a search is made we cache the first ar_instance created.
    # Its possible however during loading to create a new ar_instances that will in the end point to the same record.
  
    # VECTORS... are in important concept.  They are the substitute for a primary key before a record is loaded.
    # Vectors have the form [ModelClass, method_call, method_call, method_call...]
  
    # Each method call is either a simple method name or an array in the form [method_name, param, param ...]
    # Example [User, [find, 123], todos, active, [due, "1/1/2016"], title]
    # Roughly corresponds to this query: User.find(123).todos.active.due("1/1/2016").select(:title)
  
    attr_accessor :ar_instance
    attr_accessor :vector
    
    # While data is being loaded from the server certain internal behaviors need to change
    # for example records all record changes are synced as they happen.
    # This is implemented this way so that the ServerDataCache class can use pure active
    # record methods in its implementation
    
    def self.data_loading?
      @data_loading
    end
    
    def data_loading?
      self.class.data_loading?
    end
    
    def self.load_from_json(json, target = nil)
      puts "loading from json"
      @data_loading = true
      ServerDataCache.load_from_json(json, target)
      @data_loading = false
      puts "loaded #{@records}"
    end
  
    def self.find(model, attribute, value)  
    
      # will return the unique record with this attribute-value pair
      # value cannot be an association or aggregation
        
      model = model.base_class
      # already have a record with this attribute-value pair?
      record = @records[model].detect { |record| record.attributes[attribute] == value}
      # if not, and then the record may be loaded, but not have this attribute set yet,
      # so find the id of of record with the attribute-value pair, and see if that is loaded.
      # find_in_db returns nil if we are not prerendering which will force us to create a new record
      # because there is no way of knowing the id.
      if !record and attribute != model.primary_key and id = find_in_db(model, attribute, value)
        record = @records[model].detect { |record| record.id == id} 
      end
      # if we don't have a record then create one
      (record = new(model)).vector = [model, ["find_by_#{attribute}", value]] unless record
      # and set the value
      record.sync_attribute(attribute, value)
      # and set the primary if we have one
      record.sync_attribute(model.primary_key, id) if id
    
      # finally initialize and return the ar_instance
      record.ar_instance ||= infer_type_from_hash(model, record.attributes).new(record)
    end
  
    def self.new_from_vector(model, aggregate_parent, *vector)
    
      # this is the equivilent of find but for associations and aggregations
      # because we are not fetching a specific attribute yet, there is NO communication with the 
      # server.  That only happens during find.
    
      model = model.base_class
    
      # do we already have a record with this vector?  If so return it, otherwise make a new one.
    
      record = @records[model].detect { |record| record.vector == vector}
      (record = new(model)).vector = vector unless record
      record.ar_instance ||= infer_type_from_hash(model, record.attributes).new(record)
    
    end
    
    def initialize(model, hash = {}, ar_instance = nil)
      @model = model
      @attributes = hash
      @synced_attributes = {}
      @ar_instance = ar_instance
      records[model] << self
    end
  
    def find(*args)
      self.find(*args)
    end
  
    def new_from_vector(*args)
      self.class.new_from_vector(*args)
    end
  
    def primary_key
      @model.primary_key
    end
  
    def id
      attributes[primary_key]
    end
  
    def id=(value)
      # we need to keep the id unique
      existing_record = records[@model].detect { |record| record.attributes[primary_key] == value}
      if existing_record
        @ar_instance.instance_eval { @backing_record = existing_record }
        existing_record.attributes.merge!(attributes) { |key, v1, v2| v1 }
      else
        attributes[primary_key] = value
      end
    end
  
    def attributes
      @last_access_at = Time.now
      @attributes
    end
  
    def reactive_get!(attribute)
      apply_method(attribute) unless @attributes.has_key? attribute 
      React::State.get_state(self, attribute) unless data_loading?
      attributes[attribute]
    end
  
    def reactive_set!(attribute, value)
      attributes[attribute] = value
      React::State.set_state(self, attribute, value) unless data_loading?
      value
    end
  
    def get_state!
      React::State.get_state(self, self) unless data_loading?
      @state
    end
  
    def changed?(*args)
      args.count == 0 ? React::State.get_state(self, self) : React::State.get_state(@attributes, args[0])
      @attributes != @synced_attributes and (args.count == 0 or @attributes[args[0]] != @synced_attributes[args[0]])
    end
  
    def sync!(hash = {})
      @attributes.merge! hash
      @synced_attributes = @attributes
      self
    end
  
    def sync_attribute(attribute, value)
      #puts "syncing attribute"
      @synced_attributes[attribute] = attributes[attribute] = value
    end
  
    def find_association(association, id)
      inverse_of = association.inverse_of
      instance = if id
        find(association.klass, association.klass.primary_key, id)
      else
        new_from_vector(association.klass, nil, *vector, association.attribute)
      end
      instance.instance_eval { @backing_record.attributes[inverse_of] = self.ar_instance} if inverse_of
      instance
    end
        
    def apply_method(method)
    
      # Fills in the value returned by sending "method" to the corresponding server side db instance
      return unless id or vector  # record is "new" so just return, we really want to somehow get default values?  Possible?
      sync_attribute(
        method, 
        if association = @model.reflect_on_association(method)
          if association.collection? 
            Collection.new(association.klass, @ar_instance, association, *vector, method)
          else
            find_association(association, (id and self.class.fetch_from_db([@model, [:find, id], method, @model.primary_key])))
          end
        elsif aggregation = @model.reflect_on_aggregation(method)
          new_from_vector(aggregation.klass, self, *vector, method)
        elsif id  
          puts "fetching from db #{[@model, [:find, id], method]}"
          self.class.fetch_from_db([@model, [:find, id], method]) || self.class.load_from_db(*vector, method)
        else  # its a attribute in an aggregate or we are on the client and don't know the id
          puts "**************aggregate fetch"
          self.class.fetch_from_db([*vector, method]) || self.class.load_from_db(*vector, method)
        end
      )
    end
  
    def save(&block) 
      
      if data_loading?
        
        sync!
        
      elsif changed?
      
        records_to_process = [self]
        models = []
        associations = []
        backing_records = {}
      
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
          output_attributes = {}
          models << {id: record.object_id, model: record.model.model_name, attributes: output_attributes}
          record.attributes.each do |attribute, value|
            if association = record.model.reflect_on_association(attribute)
              if association.collection? 
                value.each { |assoc| add_new_association.call record, attribute, assoc.instance_eval { @backing_record } }
              else
                add_new_association.call record, record, attribute, value.instance_eval { @backing_record }
              end
            else
              output_attributes[attribute] = value
            end
          end
          records_to_process_index += 1
        end
      
        backing_records.each { |id, record| record.saving! }
      
        HTTP.post(`window.ReactiveRecordEnginePath`+"/save", payload: {models: models, associations: associations}).then do |response|
          response.json[:saved_models].each do |item|
            internal_id, klass, attributes = item
            backing_records[internal_id].sync!(attributes)
          end
          yield response.json[:success], response.json[:message] if block
        end
      end
    end
  
    def destroy(&block)
    
      return if @destroyed
    
      model.reflect_on_associations.each do |association|
        if association.collection? 
          attributes[association.attribute].delete(ar_instance)
        elsif owner = attributes[association.attribute] and inverse_of = association.inverse_of
          owner.attributes[inverse_of.attribute] = nil
        end
      end
    
      if id
        HTTP.post(`window.ReactiveRecordEnginePath`+"/destroy", payload: {model: model_name, id: @backing_record[primary_key]}).then do |response|
          @backing_record.delete
          yield response.json[:success], response.json[:message] if block
        end
      else
        yield true, nil
      end
    
      @destroyed = true
    
    end
  
    def self.infer_type_from_hash(klass, hash)
      klass = klass.base_class  
      return klass unless hash
      type = hash[klass.inheritance_column]
      begin
        return Object.const_get(type)
      rescue Exeception => e
        message = "Could not subclass #{@model_klass.model_name} as #{type}.  Perhaps #{type} class has not been required. Exception: #{e}"
        `console.error(#{message})`
      end if type
      klass
    end
  
  end
end