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

    # VECTORS... are an important concept.  They are the substitute for a primary key before a record is loaded.
    # Vectors have the form [ModelClass, method_call, method_call, method_call...]

    # Each method call is either a simple method name or an array in the form [method_name, param, param ...]
    # Example [User, [find, 123], todos, active, [due, "1/1/2016"], title]
    # Roughly corresponds to this query: User.find(123).todos.active.due("1/1/2016").select(:title)

    attr_accessor :ar_instance
    attr_accessor :vector
    attr_accessor :model
    attr_accessor :changed_attributes
    attr_accessor :aggregate_owner
    attr_accessor :aggregate_attribute
    attr_accessor :destroyed

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

    def self.load_data(&block)
      current_data_loading, @data_loading = [@data_loading, true]
      yield
    ensure
      @data_loading = current_data_loading
    end

    def self.load_from_json(json, target = nil)
      load_data { ServerDataCache.load_from_json(json, target) }
    end

    def self.class_scopes(model)
      @class_scopes[model.base_class]
    end

    def self.find(model, attribute, value)
      # will return the unique record with this attribute-value pair
      # value cannot be an association or aggregation

      model = model.base_class
      # already have a record with this attribute-value pair?
      record = @records[model].detect { |record| record.attributes[attribute] == value}
      unless record
        # if not, and then the record may be loaded, but not have this attribute set yet,
        # so find the id of of record with the attribute-value pair, and see if that is loaded.
        # find_in_db returns nil if we are not prerendering which will force us to create a new record
        # because there is no way of knowing the id.
        if attribute != model.primary_key and id = find_in_db(model, attribute, value)
          record = @records[model].detect { |record| record.id == id}
        end
        # if we don't have a record then create one
        (record = new(model)).vector = [model, ["find_by_#{attribute}", value]] unless record
        # and set the value
        record.sync_attribute(attribute, value)
        # and set the primary if we have one
        record.sync_attribute(model.primary_key, id) if id
      end

      # finally initialize and return the ar_instance
      record.ar_instance ||= infer_type_from_hash(model, record.attributes).new(record)
    end

    def self.new_from_vector(model, aggregate_owner, *vector)
      # this is the equivilent of find but for associations and aggregations
      # because we are not fetching a specific attribute yet, there is NO communication with the
      # server.  That only happens during find.
      model = model.base_class

      # do we already have a record with this vector?  If so return it, otherwise make a new one.

      record = @records[model].detect { |record| record.vector == vector }
      unless record
        record = new model
        record.vector = vector
      end

      record.ar_instance ||= infer_type_from_hash(model, record.attributes).new(record)

      if aggregate_owner
        record.aggregate_owner = aggregate_owner
        record.aggregate_attribute = vector.last
        aggregate_owner.attributes[vector.last] = record.ar_instance
      end

      record.ar_instance

    end

    def initialize(model, hash = {}, ar_instance = nil)
      @model = model
      @ar_instance = ar_instance
      @synced_attributes = {}
      @attributes = {}
      @changed_attributes = []
      records[model] << self
    end

    def find(*args)
      self.class.find(*args)
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
      # value can be nil if we are loading an aggregate otherwise check if it already exists
      if !(value and existing_record = records[@model].detect { |record| record.attributes[primary_key] == value})
        attributes[primary_key] = value
      else
        @ar_instance.instance_variable_set(:@backing_record, existing_record)
        existing_record.attributes.merge!(attributes) { |key, v1, v2| v1 }
      end
    end

    def attributes
      @last_access_at = Time.now
      @attributes
    end

    def reactive_get!(attribute)
      unless @destroyed
        if @attributes.has_key? attribute
          attributes[attribute].notify if @attributes[attribute].is_a? DummyValue
        else
          apply_method(attribute)
        end
        React::State.get_state(self, attribute) unless data_loading?
        attributes[attribute]
      end
    end

    def reactive_set!(attribute, value)
      unless @destroyed or (!(attributes[attribute].is_a? DummyValue) and attributes.has_key?(attribute) and attributes[attribute] == value)
        if association = @model.reflect_on_association(attribute)
          if association.collection?
            collection = Collection.new(association.klass, @ar_instance, association)
            collection.replace(value || [])
            value = collection
          else
            inverse_of = association.inverse_of
            inverse_association = association.klass.reflect_on_association(inverse_of)
            if inverse_association.collection?
              if !value
                attributes[attribute].attributes[inverse_of].delete(@ar_instance) if attributes[attribute]
              elsif value.attributes[inverse_of]
                value.attributes[inverse_of] << @ar_instance
              else
                value.attributes[inverse_of] = Collection.new(@model, value, inverse_association)
                value.attributes[inverse_of].replace [@ar_instance]
              end
            elsif value
              attributes[attribute].attributes[inverse_of] = nil if attributes[attribute]
              value.attributes[inverse_of] = @ar_instance
              React::State.set_state(value.backing_record, inverse_of, @ar_instance) unless data_loading?
            elsif attributes[attribute]
              attributes[attribute].attributes[inverse_of] = nil
            end
          end
        elsif aggregation = @model.reflect_on_aggregation(attribute)

          unless attributes[attribute]
            raise "unitialized aggregate attribute - should never happen"
          end

          aggregate_record = attributes[attribute].backing_record

          if value
            value_attributes = value.backing_record.attributes
            aggregation.mapped_attributes.each { |mapped_attribute| aggregate_record.update_attribute(mapped_attribute, value_attributes[mapped_attribute])}
          else
            aggregation.mapped_attributes.each { |mapped_attribute| aggregate_record.update_attribute(mapped_attribute, nil) }
          end

          return attributes[attribute]

        end
        update_attribute(attribute, value)
      end
      value
    end

    def update_attribute(attribute, *args)
      value = args[0]
      changed = if args.count == 0
        if association = @model.reflect_on_association(attribute) and association.collection?
          attributes[attribute] != @synced_attributes[attribute]
        else
          !attributes[attribute].backing_record.changed_attributes.empty?
        end
      elsif association = @model.reflect_on_association(attribute) and association.collection?
        value != @synced_attributes[attribute]
      else
        !@synced_attributes.has_key?(attribute) or @synced_attributes[attribute] != value
      end
      empty_before = changed_attributes.empty?
      if !changed
        changed_attributes.delete(attribute)
      elsif !changed_attributes.include?(attribute)
        changed_attributes << attribute
      end
      attributes[attribute] = value if args.count != 0
      React::State.set_state(self, attribute, value) unless data_loading?
      if empty_before != changed_attributes.empty?
        React::State.set_state(self, "!CHANGED!", !changed_attributes.empty?) unless data_loading?
        aggregate_owner.update_attribute(aggregate_attribute) if aggregate_owner
      end
    end

    def changed?(*args)
      if args.count == 0
        React::State.get_state(self, "!CHANGED!")
        !changed_attributes.empty?
      else
        React::State.get_state(self, args[0])
        changed_attributes.include? args[0]
      end
    end

    def errors
      @errors ||= ActiveModel::Error.new
    end

    def sync!(hash = {})  # does NOT notify (see saved! for notification)
      @attributes.merge! hash
      @synced_attributes = @attributes.dup
      @synced_attributes.each do |key, value|
        if value.is_a? Collection
          @synced_attributes[key] = value.dup_for_sync
        elsif aggregation = model.reflect_on_aggregation(key)
          value.backing_record.sync!
        elsif !model.reflect_on_association(key)
          @synced_attributes[key] = JSON.parse(value.to_json)
        end
      end
      @changed_attributes = []
      @saving = false
      @errors = nil
      # set the vector - this only happens when a new record is saved
      @vector = [@model, ["find_by_#{@model.primary_key}", id]] if (!vector or vector.empty?) and id and id != ""
      self
    end

    def sync_attribute(attribute, value)
      @synced_attributes[attribute] = attributes[attribute] = value
      @synced_attributes[attribute] = value.dup if value.is_a? ReactiveRecord::Collection
      @changed_attributes.delete(attribute)
      value
    end

    def revert
      @attributes.each do |attribute, value|
        @ar_instance.send("#{attribute}=", @synced_attributes[attribute])
      end
      @attributes.delete_if { |attribute, value| !@synced_attributes.has_key?(attribute) }
      @changed_attributes = []
      @errors = nil
    end

    def saving!
      React::State.set_state(self, self, :saving) unless data_loading?
      @saving = true
    end

    def errors!(errors)
      @saving = false
      @errors = errors and ActiveModel::Error.new(errors)
    end

    def saved!  # sets saving to false AND notifies
      @saving = false
      if !@errors or @errors.empty?
        React::State.set_state(self, self, :saved)
      elsif !data_loading?
        React::State.set_state(self, self, :error)
      end
      self
    end

    def saving?
      React::State.get_state(self, self)
      @saving
    end

    def new?
      !id and !vector
    end

    def find_association(association, id)
      inverse_of = association.inverse_of
      instance = if id
        find(association.klass, association.klass.primary_key, id)
      else
        new_from_vector(association.klass, nil, *vector, association.attribute)
      end
      instance_backing_record_attributes = instance.backing_record.attributes
      inverse_association = association.klass.reflect_on_association(inverse_of)
      if inverse_association.collection?
        instance_backing_record_attributes[inverse_of] = if id and id != ""
          Collection.new(@model, instance, inverse_association, association.klass, ["find", id], inverse_of)
        else
          Collection.new(@model, instance, inverse_association, *vector, association.attribute, inverse_of)
        end unless instance_backing_record_attributes[inverse_of]
        instance_backing_record_attributes[inverse_of].replace [@ar_instance]
      else
        instance_backing_record_attributes[inverse_of] = @ar_instance
      end if inverse_of and !instance_backing_record_attributes.has_key?(inverse_of)
      instance
    end

    def apply_method(method)
      # Fills in the value returned by sending "method" to the corresponding server side db instance
      if !new?
        sync_attribute(
          method,
          if association = @model.reflect_on_association(method)
            if association.collection?
              Collection.new(association.klass, @ar_instance, association, *vector, method)
            else
              find_association(association, (id and id != "" and self.class.fetch_from_db([@model, [:find, id], method, @model.primary_key])))
            end
          elsif aggregation = @model.reflect_on_aggregation(method)
            new_from_vector(aggregation.klass, self, *vector, method)
          elsif id and id != ""
            self.class.fetch_from_db([@model, [:find, id], method]) || self.class.load_from_db(*vector, method)
          else  # its a attribute in an aggregate or we are on the client and don't know the id
            self.class.fetch_from_db([*vector, method]) || self.class.load_from_db(*vector, method)
          end
        )
      elsif association = @model.reflect_on_association(method) and association.collection?
        @attributes[method] = Collection.new(association.klass, @ar_instance, association)
      elsif aggregation = @model.reflect_on_aggregation(method)
        @attributes[method] = aggregation.klass.new.tap do |aggregate|
          backing_record = aggregate.backing_record
          backing_record.aggregate_owner = self
          backing_record.aggregate_attribute = method
        end
      end
    end

    def self.infer_type_from_hash(klass, hash)
      klass = klass.base_class
      return klass unless hash
      type = hash[klass.inheritance_column]
      begin
        return Object.const_get(type)
      rescue Exception => e
        message = "Could not subclass #{@model_klass.model_name} as #{type}.  Perhaps #{type} class has not been required. Exception: #{e}"
        `console.error(#{message})`
      end if type
      klass
    end

  end
end
