# a vector is a series of associations beginning with a model identifier
# for example Foo.find_by_bar("baz").some_has_many[2].some_belongs_to.an_attribute
# the model containing an_attribute would have the following vector [Foo, :bar, "baz", :some_has_many, :some_belongs_to]

# Foo.find_by_bar("baz") will return a Foo model whose state will either be :loaded, or nil
# has_many associations return an Association (subclass of Array) whose state will either be :loaded or nil
# belongs_to class: XXX return a XXX model whose state will either be :loaded or nil

# All models and associations report state changes via React::State so if a react component has the following
# Foo.find_by_bar("baz").some_has_many.each { ... } 
# then it will observe the model returned by Foo.find_by_bar("baz") and the association Foo.find_by_bar("baz").some_has_many

# given that in active_record Foo.find_by_bar("baz") == Foo.find_by_bar("baz") does this mean that
# state changes to Foo.find_by_bar("baz") update all observers of Foo.find_by_bar("baz")?  In active_record
# the two finds return different objects, and even after a save to one of the objects the other will not follow the change
# until you do a reload

# real example:
# required_param :user

# def before_update
#   @new_address = user.addresses.detect { |address| address.new_record? }  # observes user.addresses, and @new_address (via address.new_record?)
# end
#    ...
# def render
#    ...
#       user! << Address.new
#    ...
#       DisplayAddress address: @new_address if @new_address
# end

# # In DisplayAddress

#       address.city = ... # state change to address BUT WE DON'T want to rerender to owner just display address
#       address.save  # state change to address WE DO want to rerender
#
# conclusion 
#  1) stick with active_record approach, otherwise it could get very difficult to control things.
#  2) new_record? needs to have its own react state separate from the actual record data, 
#  3) we might want to have each attribute have its own state as well

# loading is a special case.  The loading state is NOT tracked in the actual objects.  Loading is done in one batch, either everything is 
# loaded, or else we are waiting for loads.  
   

module ActiveRecord
  
  class Association < Array
    
    def associate(parent, parent_association)
      @parent = parent
      klass = Object.const_get(parent_association[:klass_name]).base_class
      @child_association = klass._reactive_record_associations.detect do | attribute, association |
        Object.const_get(association[:klass_name]).base_class == klass and 
        association[:macro] == :belongs_to and 
        association[:foreign_key] == parent_association[:foreign_key]
      end
      self
    end
    
    def loading!
      @state = :loading
      self
    end
    
    def loading?
      @state == :loading
    end

    def loaded?
      !loading
    end
      
    
    def <<(item)
      item[@child_association[:attribute]] = @parent
      item[@child_association[:foreign_key]] = @parent.attributes[@parent.primary_key]
      super(item)
    end
    
  end
      
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

      def _reactive_record_table_delete(record_to_delete) 
        # need to fix this up so you can delete unsaved records
        # this needs to iterate over actual instances
        model_class_being_deleted = self
        base_class.instance_eval do
          _reactive_record_associations.each do | attribute, association | 
            if association[:macro] == :belongs_to
              Object.const_get(association[:klass_name]).base_class.instance_eval do
                _reactive_record_table.each do |record|
                  reference_found = false
                  _reactive_record_associations.each do | attribute, association | 
                    if Object.const_get(association[:klass_name]).base_class == model_class_being_deleted
                      assoc = record[attribute]
                      if association[:macro] == :has_one
                        (reference_found = true) and (record[attribute] = nil) if assoc.attributes == record_to_delete
                      elsif association[:macro] == :has_many
                        reference_found ||= assoc.reject! { |item| item.attributes == record_to_delete }
                      end
                    end
                  end
                  ----> fix this React::State.set_state(record, :save_state, record) if reference_found
                end
              end
            end
          end
          _reactive_record_table.reject! { |record| record[primary_key].to_s == id.to_s }
        end
      end
      
      def _reactive_record_table_find(attribute, value, dont_initialize_cache = nil)
        base_class.instance_eval do
          unless @load_started
            # protects this from recursive loading since _reactive_record_table_find is called from PrerenderDataInterface#initialize
            @load_started = true
            React::PrerenderDataInterface.load!
          end
          #puts "in reactive_record_table_find #{attribute}, #{value}"
          _reactive_record_table.detect { |record| record[attribute].to_s == value.to_s }
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
    
    def new_record?
      React::State.get_state(self, :new_record)
      !attributes[primary_key]
    end

    def model_name
      # in reality should return ActiveModel::Name object, blah blah
      self.class.model_name
    end

    def initialize(*args)
      if args[0]
        attributes = args[0]
        self.class._reactive_record_associations.each do | attribute, association | 
          if attributes[attribute]
            klass = Object.const_get association[:klass_name]
            attributes[attribute] = if attributes[attribute].is_a? Array
              Association[*attributes[attribute].collect { |r| klass.new(r) }].associate(self, association)
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
    
    # internal initializers
    #
    # _reactive_record_initialize is used during find_by 

    def _reactive_record_initialize(record, attribute, value, state = nil)
      @record = Hash[*record.to_a.flatten(1)]
      @vector = [model_name, attribute, value]
      @state = state
      self
    end
    
    def _reactive_record_initialize_vector(vector)
      @vector = vector
      self
    end

    def attributes
      @record
    end

    def save(&block)
      if @state == :loaded
        
        was_new_record = new_record?
        models = [{id: internal_id, model: model_name, attributes: attributes}]
        associations = []

        add_new_association = lambda do |model, assoc|
          if assoc and assoc.new_record? 
            unless models.detect { |model| model[:id] == assoc.internal_id }
              models << {id: assoc.internal_id, model: assoc.model_name, attributes: assoc.attributes}
            end
            associations << {parent_id: model.internal_id, attribute: attribute, child_id: assoc.internal_id}
          end
        end
        
        model_index = 0
        while(model_index < models.count)
          model = models[model_index]
          model.class._reactive_record_associations.each do | attribute, association |
            assoc_value = model.send(attribute)
            if assoc_value.is_a? Association
              assoc_value.each { |assoc| add_new_association.call model, assoc }
            else
              add_new_association.call model, assoc_value
            end   
          end
          model_index += 1
        end
        
        @save_state = React::State.set_state(self, :save_state, :saving)
        
        HTTP.post(`window.ReactiveRecordEnginePath`+"/save", payload: {models: models, associations: associations}).then do |response|
          response.json[:saved_models].each do |klass, attributes|
            Object.const_get(klass)._reactive_record_update_table(attributes)
          end
          @save_state = nil
          yield response.json[:success], response.json[:message] if block
          React::State.set_state(self, :save_state, @save_state)
          React::State.set_state(self, :new_record, nil) if was_new_record
        end
      end
    end

    def destroy(&block)
      id = attributes[primary_key]

      if new_record?
        self.class._reactive_record_table_delete id
        yield true, nil if block
        ---> FIX this #React::State.set_state(@record, :save_state, @record)
      else
        HTTP.post(`window.ReactiveRecordEnginePath`+"/destroy", payload: {model: model_name, id: id}).then do |response|
          self.class._reactive_record_table_delete id
          yield response.json[:success], response.json[:message] if block
          ---> FIX this #React::State.set_state(@record, :save_state, @record) if response.json[:success]
        end
      end
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
        foreign_key = options[:foreign_key] || "#{name}_id"
        association = _reactive_record_associations[name] = {
            klass_name: klass_name, 
            macro: method_name.to_sym, 
            foreign_key: foreign_key
          } unless assoc_type == :aggregate
        define_method(name) do 
          klass = Object.const_get klass_name
          #puts "#{self}.#{name} @state: #{@state}, @vector: [#{@vector}], @record[#{name}]: #{@record[name]}"
          _reactive_record_check_and_resolve_load_state
          React::State.get_state(self, name) if @state == :loaded
          # @state should never be :not_found, means there has been some kind of internal error
          if @state == :not_found
            message = "REACTIVE_RECORD NOT FOUND: #{self}.#{name}, @vector: [#{@vector}], @record[#{name}]: #{@record[name]}"
            `console.error(#{message})`
            nil
          # the association needs to be loaded.  This is a rather complicated check see comments
          elsif !@state or @state == :loading or                            # this is the simple case: has not completed loading
                (!@record.has_key?(name) and                                # even if loaded the association might not be loaded yet
                  (!@record.has_key?(foreign_key) or @record[foreign_key])) # but it association could really be nil, so check the foreign key
                # summary a) are we new or loading?
                #         b) if loaded make sure we have the association loaded
                #         c) if the association is not there, it could be because the association is empty, so check the foreign key value
                # part (c) is needed because an empty association will NEVER be included, so we test the foreign key value if record does not have
                # association key
            #puts "about to create dummy records #{@vector} "
            _reactive_record_fetch if [:aggregate, :plural].include? assoc_type and @state == :loaded
            if assoc_type == :aggregate
              DummyAggregate.new
            elsif assoc_type == :plural
              Association[klass.new._reactive_record_initialize_vector(@vector + [name])].loading!
            else
              klass.new._reactive_record_initialize_vector(@vector + [name])
            end
          # the association is ready to go
          elsif !@record[name] or # happens when a belongs_to relationship is nil
                @record[name].class.ancestors.include? klass or @record[name].is_a? Association
               #( and (@record[name].count == 0 or @record[name].first.class.ancestors.include? klass)) not needed right?
            @record[name]
          # its an aggregate so we need to build it from the attributes
          elsif assoc_type == :aggregate
            @record[name] = klass.send(options[:constructor] || :new, *options[:mapping].collect { |mapping|  @record[name][mapping.last] })
          # its a has_many relationship loaded from the server so it will be in the form [{id: nnn}, {id: mmm}, ...]
          elsif @record[name].is_a? Array and (@record[name].count == 0 or @record[name].first.is_a? Hash)
            #puts "@record[name].is_a? Array and @record[name].first.is_a? Hash"
            @record[name] = Association[*@record[name].collect { |item| klass.find(item.first.last)}].associate(self, association)
          # its a belongs_to or has_one relationship loaded from the server so it will be in the form {id: nnn}
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
          attribute_name = name.gsub(/_changed\?$/,"")
          React::State.get_state(self, attribute_name)
          saved_model = self.class.find(@record[primary_key])
          @record[attribute_name] != saved_model.attributes[attribute_name]
        end
      elsif args.count == 1 && name =~ /=$/ && !block
        _reactive_record_check_and_resolve_load_state
        attribute_name = name.gsub(/=$/,"")
        @record[attribute_name] = args[0]
        @save_state = :dirty
        React::State.set_state(self, attribute_name, args[0]) if @state == :loaded
        args[0]
      elsif args.count == 0 && !block
        _reactive_record_check_and_resolve_load_state
        React::State.get_state(self, name) if @state == :loaded
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
      React::State.get_state(self, :save_state)
      !!@save_state
    end

    def saving?
      React::State.get_state(self, :save_state)
      @save_state == :saving
    end



  end
end
