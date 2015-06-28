module ActiveRecord
  class Base    
    
    class << self
      
      # this section could be replaced with an interface to something like js-sql-lite
      
      def primary_key
        @primary_key || :id
      end
      
      def primary_key=(val)
        @primary_key = val
      end
      
      def attr_accessible(*args)
      end
      
      def _reactive_record_table
        @table ||= []
      end
      
      def _reactive_record_table_find(attribute, value, dont_initialize_cache = nil)
        _reactive_record_cache unless dont_initialize_cache
        #puts "in reactive_record_table_find #{attribute}, #{value}"
        _reactive_record_table.detect { |record| record[attribute].to_s == value.to_s }#.tap { |v| puts "table_find(#{attribute}, #{value}) = #{v}, table = #{_reactive_record_table}"}
      end
      
      def _reactive_record_update_table(record)
        #puts "rr_update_table #{record}, #{primary_key}"
        if r = _reactive_record_table_find(primary_key, record[primary_key], true)
          r.merge! record
        else
          _reactive_record_table << record
          record
        end
      end
      
      def _reactive_record_cache
        @@reactive_record_cache ||= ReactiveRecord::Cache.new
      end
      
      def _react_param_conversion(param, opt = nil)
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
    
    def primary_key
      self.class.primary_key
    end
    
    def model_name
      # in reality should return ActiveModel::Name object, blah blah
      self.class.name
    end
    
    def initialize(*args)
      if args[0]
        attributes = args[0]
        @vector = [model_name, primary_key, attributes[primary_key]]
        # if we are on the server do a fetch to make sure we get all the associations as well
        attributes.merge! Base._reactive_record_cache.fetch(*@vector) if ReactiveRecord::Cache.on_server?
        @record = self.class._reactive_record_update_table attributes
        @state = :loaded 
      else
        @record = {}
      end
    end
    
    def attributes
      @record
    end
    
    def _reactive_record_initialize_vector(vector)
      @vector = vector
      # Base._reactive_record_cache.fetch(*vector)
      self
    end
    
    def _reactive_record_initialize(attribute, value)
      #puts "_reactive_record_initialize(#{attribute}, #{value})"
      record = self.class._reactive_record_table_find(attribute, value) ||      
        (ReactiveRecord::Cache.on_server? and Base._reactive_record_cache.fetch(*[model_name, attribute, value]))
      if record
        @record = record
        @state = :loaded
      else 
        @record = {attribute => value}
        #@state = :loading
      end
      @vector = [model_name, attribute, value]
      self
    end
    
    def _reactive_record_fetch
      @fetched_at = Time.now
      Base._reactive_record_cache.fetch(*@vector)
    end
    
    def _reactive_record_pending?
      (@fetched_at || Time.now) > Base._reactive_record_cache.last_fetch_at 
    end

    def _reactive_record_check_and_resolve_load_state
      Base._reactive_record_cache
      #puts "#{self}._reactive_record_check_and_resolve_load_state @state = #{@state}, pending = #{_reactive_record_pending?}(#{@fetched_at} > #{Base._reactive_record_cache.last_fetch_at}) @vector = #{@vector}"
      unless @state
        _reactive_record_fetch
        return (@state = :loading)
      end
      return @state if @state == :loaded or @state == :not_found
      if @state == :loading and  _reactive_record_pending?
        ReactiveRecord::WhileLoading.loading!
        return :loading
      end
      #puts "resolving #{@vector}"
      root_model = Object.const_get(@vector[0])._reactive_record_table_find(@vector[1], @vector[2])
      #puts "reactive_record_resolve #{@vector}, #{Object.const_get(@vector[0])._reactive_record_table}"
      return (@state = :not_found) unless root_model
      loaded_model = @vector[3..-1].inject(root_model) do |model, association|
        #puts "resolving: #{model}, #{association}"
        return (@state = :not_found) unless model
        value = model.send(association)
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
      @record.merge!((loaded_model.is_a? Hash) ? loaded_model : loaded_model.attributes)
      @state = :loaded
    end
    
    def self.find_by(opts = {})
      #puts "#{self.name}.find_by(#{opts})"
      attribute = opts.first.first
      value = opts.first.last
      new._reactive_record_initialize(attribute, value)
    end
    
    def self.find(id)
      find_by(primary_key => id)
    end
    
    {belongs_to: nil, has_many: true}.each do |method_name, plural|
      
      self.class.define_method(method_name) do |name, options = {}|
        
        class_name = if options[:class_name]
          options[:class_name]
        elsif plural
          name.camelize.gsub(/s$/,"")
        else
          name.camelize
        end
        
        define_method(name) do 
          #puts "#{self}.#{name} @state: #{@state}, @vector: [#{@vector}], @record[#{name}]: #{@record[name]}"
          _reactive_record_check_and_resolve_load_state
          if @state == :not_found
            puts "NOT FOUND "#{self}.#{name} @state: #{@state}, @vector: [#{@vector}], @record[#{name}]: #{@record[name]}""
            nil
          elsif !@state or @state == :loading or !@record.has_key? name 
            #puts "about to create dummy records #{@vector}"
            obj = Object.const_get(class_name).new._reactive_record_initialize_vector(@vector + [name])
            if plural 
              #puts "fetching associations for [#{@vector}]"
              if @state == :loaded
                _reactive_record_fetch
              end
              [obj]
            else
              obj
            end
          elsif (@record[name].is_a? Array and @record[name].first.is_a? Hash) 
            #puts "@record[name].is_a? Array and @record[name].first.is_a? Hash"
            @record[name] = @record[name].collect { |item| Object.const_get(class_name).find(item.first.last)}
          elsif @record[name].is_a? Hash
            #puts "@record[name].is_a? Hash"
            @record[name] = Object.const_get(class_name).find(@record[name].first.last)
          else
            #puts "already to go"
            @record[name]
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
      #puts "#{self}.#{name}(#{args}) (called #{model_name} instance method missing)"
      if args.count == 1 && name =~ /=$/ && !block
        _reactive_record_check_and_resolve_load_state
        @record[name.gsub(/=$/,"")] = args[0]
      elsif args.count == 0 && !block 
        _reactive_record_check_and_resolve_load_state
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
    
  end
end
