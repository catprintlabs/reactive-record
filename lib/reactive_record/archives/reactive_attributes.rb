module ActiveRecord
  
  module ReactiveAttributes
    
    def _reactive_record_fetch(attribute)
      @fetched_at = Time.now
      puts "in reactive record fetch"
      React::PrerenderDataInterface.fetch(*(@vector+attribute))
    end

    def _reactive_record_pending?
      (@fetched_at || Time.now) > React::PrerenderDataInterface.last_fetch_at
    end

    def _reactive_record_check_and_resolve_load_state
      React::PrerenderDataInterface.load!
      #puts "_reactive_rcord_check_and_resolve_load_state" #{}"#puts "#{self}._reactive_record_check_and_resolve_load_state" # @state = #{@state}, pending = #{_reactive_record_pending?}(#{@fetched_at} > #{React::PrerenderDataInterface.last_fetch_at}) @vector = #{@vector}"
      return unless @vector # happens if a new active record model is created by the application
      unless @state
        _reactive_record_fetch
        return (@state = :loading)
      end
      return @state if @state == :loaded or @state == :not_found or @state == :new_record
      if @state == :loading and  _reactive_record_pending?
        #puts fetch miss!
        React::WhileLoading.loading!
        return :loading
      end
      #puts "resolving #{@vector}"
      root_model = Object.const_get(@vector[0])._reactive_record_table_find(@vector[1], @vector[2])
      #puts "reactive_record_resolve #{@vector}, #{Object.const_get(@vector[0])._reactive_record_table}"
      #  i think this is redundant with the return inside:  return (@state = :not_found) unless root_model
      loaded_model = @vector[3..-1].inject(root_model) do |model, association|
        #puts "resolving: #{model}, #{association}"
        return (@state = :not_found) unless model
        value = model[association] 
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
      #puts "merging #{@backing_record} with loaded_model: (#{loaded_model})"
      #@backing_record.merge!((loaded_model.is_a? Hash) ? loaded_model : loaded_model.attributes) if loaded_model
      @backing_record = loaded_model.attributes # maybe??? should work right???  not even sure what this means?  Foo.find(123).bar[1].zap.fred ???
      @state = :loaded
    end

    class DummyAggregate

      def method_missing(*args, &block)
        DummyAggregate.new
      end

      def to_s
        ""
      end

    end

    {belongs_to: :singular, has_many: :plural, has_one: :singular, composed_of: :aggregate}.each do |method_name, assoc_type|

      self.class.define_method(method_name) do |name, options = {}|

        klass_name = options[:class_name] || (assoc_type == :plural && name.camelize.gsub(/s$/,"")) || name.camelize
        foreign_key = options[:foreign_key] || "#{name}_id"
        association = Associations::AssociationReflection.new(
          attribute: name,
          klass_name: klass_name, 
          macro: method_name.to_sym, 
          foreign_key: foreign_key
        ) unless assoc_type == :aggregate
        
        define_method(name) do 
          klass = Object.const_get klass_name
          _reactive_record_check_and_resolve_load_state
          @backing_record.reactive_get!(name) # let react know we are looking otherwise we are not using the value yet
          
          state = @backing_record.state
          
          # if @state==:not_found should never happen, means there has been some kind of internal error
          if state == :not_found
            message = "REACTIVE_RECORD NOT FOUND: #{self}.#{name}, @vector: [#{@vector}], @backing_record[#{name}]: #{@backing_record[name]}"
            `console.error(#{message})`
            nil
            
          # else the association needs to be loaded.  This is a rather complicated check see comments
          elsif !state or state == :loading or                            # this is the simple case: has not completed loading
                (!@backing_record.hash.has_key?(name) and                 # even if loaded the association might not be loaded yet
                  (!@backing_record.hash.has_key?(foreign_key) or @backing_record[foreign_key])) # but it association could really be nil, so check the foreign key
                # summary a) are we new or loading?
                #         b) if loaded make sure we have the association loaded
                #         c) if the association is not there, it could be because the association is empty, so check the foreign key value
                # part (c) is needed because an empty association will NEVER be included, so we test the foreign key value if record does not have
                # association key
            _reactive_record_fetch if [:aggregate, :plural].include? assoc_type and @state == :loaded
            if assoc_type == :aggregate
              DummyAggregate.new
            elsif assoc_type == :plural
              Association(klass._reactive_record_store.new_model_instance(@backing_record.vector + [name]), @backing_record, association)
            else
              klass._reactive_record_store.new_model_instance(@backing_record.vector + [name])
            end
            
          # else its an association that is ready to go
          elsif !@backing_record[name] or # happens when a belongs_to relationship is nil
                @backing_record[name].is_a? ReactiveRecords::Record or @backing_record[name].is_a? Association
               #( and (@backing_record[name].count == 0 or @backing_record[name].first.class.ancestors.include? klass)) not needed right?
            @backing_record[name]
            
          # else its an aggregate so we need to build it from the attributes
          elsif assoc_type == :aggregate
            @backing_record[name] = klass.send(options[:constructor] || :new, *options[:mapping].collect { |mapping|  @backing_record[name][mapping.last] })
          
          # its a has_many relationship loaded from the server so it will be in the form [{id: nnn}, {id: mmm}, ...]
          elsif @backing_record[name].is_a? Array and (@backing_record[name].count == 0 or @backing_record[name].first.is_a? Hash)
            @backing_record[name] = Association[*@backing_record[name].collect { |item| klass.find(item.first.last)}].associate(self, association)
          # its a belongs_to or has_one relationship loaded from the server so it will be in the form {id: nnn}
          elsif @backing_record[name].is_a? Hash
            #puts "@backing_record[name].is_a? Hash"
            @backing_record[name] = klass.find(@backing_record[name].first.last)
          else
            raise "ReactiveRecord internal error - #{association_type} association data for #{name} not of correct type: #{@backing_record[name]}"
          end
        end

      end
    end

    def method_missing(name, *args, &block)
      #puts "#{self}.#{name}(#{args})" # (called #{model_name} instance method missing)"
      if name =~ /_changed\?$/
        _reactive_record_check_and_resolve_load_state
        @backing_record.changed?(name.gsub(/_changed\?$/,""))
      elsif args.count == 1 && name =~ /=$/ && !block
        _reactive_record_check_and_resolve_load_state
        attribute_name = name.gsub(/=$/,"")
        @backing_record.reactive_set!(attribute_name, args[0])
        args[0]
      elsif args.count == 0 && !block
        _reactive_record_check_and_resolve_load_state
        @backing_record.reactive_get!(name)
      else
        super
      end
    end
    