module ActiveRecord
  class Base


    class << self

      # this section could be replaced with an interface to something like js-sql-lite

      def base_class

        unless self < Base
          raise ActiveRecordError, "#{name} doesn't belong in a hierarchy descending from ActiveRecord"
        end

        if superclass == Base || superclass.abstract_class?
          self
        else
          superclass.base_class
        end

      end

      def abstract_class?
        defined?(@abstract_class) && @abstract_class == true
      end

      def primary_key
        base_class.instance_eval { @primary_key || :id }
      end

      def primary_key=(val)
       base_class.instance_eval { @primary_key = val }
      end

      def attr_accessible(*args)
        base_class.instance_eval { }
      end

      def _reactive_record_table
        base_class.instance_eval { @table ||= [] }
      end

      def _reactive_record_table_find(attribute, value, dont_initialize_cache = nil)
        base_class.instance_eval do
          unless @load_started
            # protects this from recursive loading since _reactive_record_table_find is called from PrerenderDataInterface#initialize
            @load_started = true
            React::PrerenderDataInterface.load!
          end
          #puts "in reactive_record_table_find #{attribute}, #{value}"
          _reactive_record_table.detect { |record| record[attribute].to_s == value.to_s }#.tap { |v| puts "table_find(#{attribute}, #{value}) = #{v}, table = #{_reactive_record_table}"}
        end
      end

      def _reactive_record_update_table(record)
        base_class.instance_eval do
          #puts "rr_update_table  #{record}, #{primary_key}"
          if r = _reactive_record_table_find(primary_key, record[primary_key], true)
            r.merge! record
          else
            _reactive_record_table << record
            record
          end
        end
      end

      def _react_param_conversion(param, opt = nil)
        base_class.instance_eval do
          param_is_native = !param.respond_to?(:is_a?) rescue true
          param = JSON.from_object param if param_is_native
          if param.is_a? self
            param
          elsif param.is_a? Hash
            if opt == :validate_only
              true
            else
              new(param)
            end
          else
            nil
          end
        end
      end

      def inheritance_column
        base_class.instance_eval {@inheritance_column || "type"}
      end

      def inheritance_column=(name)
        base_class.instance_eval {@inheritance_column = name}
      end

      def model_name
        # in reality should return ActiveModel::Name object, blah blah
        name
      end

    end

    def primary_key
      self.class.primary_key
    end

    def model_name
      # in reality should return ActiveModel::Name object, blah blah
      self.class.model_name
    end

    def initialize(*args)
      if args[0]
        attributes = args[0]
        self.class._reactive_record_associations.each do | attribute, klass_name |
          if attributes[attribute]
            klass = Object.const_get klass_name
            attributes[attribute] = if attributes[attribute].is_a? Array
              attributes[attribute].collect { |r| klass.new(r) }
            else
              klass.new(attributes[attribute])
            end
          end
        end
        @vector = [model_name, primary_key, attributes[primary_key]]
        # if we are on the server do a fetch to make sure we get all the associations as well
        attributes.merge! React::PrerenderDataInterface.fetch(*@vector) if React::PrerenderDataInterface.on_opal_server?
        @record = self.class._reactive_record_update_table attributes
        @state = :loaded
      else
        @record = {}
      end
    end

    def attributes
      @record
    end

    def save(&block)
      if @state == :loaded
        @save_state = :saving
        React::State.set_state(self, :save_state, @save_state)
        HTTP.post(`window.ReactiveRecordEnginePath`+"/save", payload: {model: model_name, attributes: attributes}).then do |response|
          self.class._reactive_record_update_table(response.json[:attributes])  if response.json[:success]
          @save_state = nil
          yield response.json[:success], response.json[:message] if block
          React::State.set_state(self, :save_state, @save_state)
        end
      end
    end

    def destroy(&block)
      @save_state = :destroying
      React::State.set_state(self, :save_state, @save_state)
      HTTP.post(`window.ReactiveRecordEnginePath`+"/destroy", payload: {model: model_name, attributes: attributes}).then do |response|
        self.class._reactive_record_table.delete(attributes) if response.json[:success]
        @save_state = nil
        yield response.json[:success], response.json[:message] if block
        React::State.set_state(self, :save_state, @save_state)
      end
    end

    def _reactive_record_initialize_vector(vector)
      @vector = vector
      self
    end

    def _reactive_record_initialize(record, attribute, value, state = nil)
      @record = record
      @vector = [model_name, attribute, value]
      @state = state
      self
    end

    def _reactive_record_fetch
      @fetched_at = Time.now
      puts "in reactive record fetch"
      React::PrerenderDataInterface.fetch(*@vector)
    end

    def _reactive_record_pending?
      (@fetched_at || Time.now) > React::PrerenderDataInterface.last_fetch_at
    end

    def _reactive_record_check_and_resolve_load_state
      React::PrerenderDataInterface.load!
      #puts "_reactive_rcord_check_and_resolve_load_state" #{}"#puts "#{self}._reactive_record_check_and_resolve_load_state" # @state = #{@state}, pending = #{_reactive_record_pending?}(#{@fetched_at} > #{React::PrerenderDataInterface.last_fetch_at}) @vector = #{@vector}"
      return unless @vector # happens if a new active record model is created by the application
      unless @state
        puts "calling from check and resolve load state"
        _reactive_record_fetch
        return (@state = :loading)
      end
      return @state if @state == :loaded or @state == :not_found
      if @state == :loading and  _reactive_record_pending?
        #puts fetch miss!
        React::WhileLoading.loading!
        return :loading
      end
      #puts "resolving #{@vector}"
      root_model = Object.const_get(@vector[0])._reactive_record_table_find(@vector[1], @vector[2])
      #puts "reactive_record_resolve #{@vector}, #{Object.const_get(@vector[0])._reactive_record_table}"
      return (@state = :not_found) unless root_model
      loaded_model = @vector[3..-1].inject(root_model) do |model, association|
        #puts "resolving: #{model}, #{association}"
        return (@state = :not_found) unless model
        value = model[association] # how did this ever possibly work ->>>>> value = model.send(association)
        if value.is_a? Array
          if value.count > 0
            value.first
          else
            return (@state = :not_found)
          end
        else
          value
        end
      end
      #puts "merging #{@record} with loaded_model: (#{loaded_model})"
      @record.merge!((loaded_model.is_a? Hash) ? loaded_model : loaded_model.attributes) if loaded_model
      @state = :loaded
    end

    def self.find_by(opts = {})
      #puts "#{self.name}.find_by(#{opts})"
      attribute = opts.first.first
      value = opts.first.last
      record = _reactive_record_table_find(attribute, value) ||
        (React::PrerenderDataInterface.on_opal_server? and React::PrerenderDataInterface.fetch(*[model_name, attribute, value]))
      if record
        type = record[inheritance_column]
        begin
          klass = Object.const_get(type)
        rescue Exeception => e
          message = "Could not subclass #{self.name} as #{type}.  Perhaps #{type} class has not been required. Exception: #{e}"
          `console.error(#{message})`
        end if type
        (klass || self).new._reactive_record_initialize(record, attribute, value, :loaded)
      else
        new._reactive_record_initialize({attribute => value}, attribute, value)
      end
    end

    def self.find(id)
      find_by(primary_key => id)
    end

    def self.table_name=(name)
    end

    def self.abstract_class=(val)
      @abstract_class = val
    end

    def self.scope(*args, &block)
    end

    def self.before_validation(*args, &block)
    end

    def self.with_options(*args, &block)
    end

    def self.validates_presence_of(*args, &block)
    end

    def self.validates_format_of(*args, &block)
    end

    def self.accepts_nested_attributes_for(*args, &block)
    end

    def self.after_create(*args, &block)
    end

    def self.before_save(*args, &block)
    end

    def self.before_destroy(*args, &block)
    end

    def self.where(*args, &block)
    end

    def self.validate(*args, &block)
    end

    def self.attr_protected(*args, &block)
    end

    def self.validates_numericality_of(*args, &block)
    end

    def self.default_scope(*args, &block)
    end

    def self.serialize(*args, &block)
    end

    def self.has_attached_file(*args, &block)
    end

    class DummyAggregate

      def method_missing(*args, &block)
        DummyAggregate.new
      end

      def to_s
        ""
      end

    end

    def self._reactive_record_associations
      base_class.instance_eval { @associations ||= {} }
    end

    {belongs_to: :singular, has_many: :plural, has_one: :singular, composed_of: :aggregate}.each do |method_name, assoc_type|

      self.class.define_method(method_name) do |name, options = {}|

        klass_name = options[:class_name] || (assoc_type == :plural && name.camelize.gsub(/s$/,"")) || name.camelize
        _reactive_record_associations[name] = klass_name unless assoc_type == :aggregate
        define_method(name) do
          klass = Object.const_get klass_name
          #puts "#{self}.#{name} @state: #{@state}, @vector: [#{@vector}], @record[#{name}]: #{@record[name]}"
          _reactive_record_check_and_resolve_load_state
          React::State.get_state(self, :save_state) if @state == :loaded
          if @state == :not_found
            message = "REACTIVE_RECORD NOT FOUND: #{self}.#{name}, @vector: [#{@vector}], @record[#{name}]: #{@record[name]}"
            `console.error(#{message})`
            nil
          elsif !@state or @state == :loading or (!@record.has_key?(name) and !(@record.has_key?("#{name}_id") and @record["#{name}_id"]))
            #puts "about to create dummy records #{@vector}"
            _reactive_record_fetch.tap { puts "calling from reactive record associations" } if [:aggregate, :plural].include? assoc_type and @state == :loaded
            if assoc_type == :aggregate
              DummyAggregate.new
            elsif assoc_type == :plural
              [klass.new._reactive_record_initialize_vector(@vector + [name])]
            else
              klass.new._reactive_record_initialize_vector(@vector + [name])
            end
          elsif !@record[name] or @record[name].class.ancestors.include? klass or
               (@record[name].is_a? Array and (@record[name].count == 0 or @record[name].first.class.ancestors.include? klass))
            @record[name]
          elsif assoc_type == :aggregate
            @record[name] = klass.send(options[:constructor] || :new, *options[:mapping].collect { |mapping|  @record[name][mapping.last] })
          elsif (@record[name].is_a? Array and @record[name].first.is_a? Hash)
            #puts "@record[name].is_a? Array and @record[name].first.is_a? Hash"
            @record[name] = @record[name].collect { |item| klass.find(item.first.last)}
          elsif @record[name].is_a? Hash
            #puts "@record[name].is_a? Hash"
            @record[name] = klass.find(@record[name].first.last)
          else
            raise "ReactiveRecord internal error - #{association_type} association data for #{name} not of correct type: #{@record[name]}"
          end
        end

      end
    end

    def self.method_missing(name, *args, &block)
      #puts "#{self.name}.#{name}(#{args}) (called class method missing)"
      if args.count == 1 && name =~ /^find_by_/ && !block
        find_by(name.gsub(/^find_by_/, "") => args[0])
      else
        super
      end
    end

    def method_missing(name, *args, &block)
      #puts "#{self}.#{name}(#{args})" # (called #{model_name} instance method missing)"
      if name =~ /_changed\?$/
        _reactive_record_check_and_resolve_load_state
        if @state == :loaded
          React::State.get_state(self, :save_state)
          attribute_name = name.gsub(/_changed\?$/,"")
          saved_model = self.class.find(@record[primary_key])
          @record[attribute_name] != saved_model.attributes[attribute_name]
        end
      elsif args.count == 1 && name =~ /=$/ && !block
        _reactive_record_check_and_resolve_load_state
        @record[name.gsub(/=$/,"")] = args[0]
        @save_state = :dirty
        React::State.set_state(self, :save_state, @save_state) if @state == :loaded
        args[0]
      elsif args.count == 0 && !block
        _reactive_record_check_and_resolve_load_state
        React::State.get_state(self, :save_state) if @state == :loaded
        if @record.has_key? name
          @record[name]
        else
          "" # this is where we should throw a message to the rendering engine, type depending on @state perhaps
        end
      else
        super
      end
    end

    def loaded?
      _reactive_record_check_and_resolve_load_state == :loaded
    end

    def loading?
      _reactive_record_check_and_resolve_load_state != :loading
    end

    def not_found?
      _reactive_record_check_and_resolve_load_state == :not_found
    end

    def changed?
      @save_state
    end

    def saving?
      @save_state == :saving
    end



  end
end
