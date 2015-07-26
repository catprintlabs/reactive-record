module ActiveRecord
  
  module ClassMethods
    
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

    def find(id)
      ReactiveRecord::Base.find(self, primary_key, id)
    end
    
    def find_by(opts = {})
      ReactiveRecord::Base.find(self, opts.first.first, opts.first.last)
    end
    
    def self.method_missing(name, *args, &block)
      #puts "#{self.name}.#{name}(#{args}) (called class method missing)"
      if args.count == 1 && name =~ /^find_by_/ && !block
        find_by(name.gsub(/^find_by_/, "") => args[0])
      else
        super
      end
    end
    
    def abstract_class=(val)
      @abstract_class = val
    end
    
    def scope(name, body)
      singleton_class.send(:define_method, name) { ReactiveRecord::Collection.new(self, nil, nil, self, name) }
    end
    
    def all
      ReactiveRecord::Collection.new(self)
    end
        
    [:belongs_to, :has_many, :has_one].each do |macro| 
      define_method(macro) do |name, opts = {}| 
        Associations::AssociationReflection.new(base_class, macro, name, opts)
      end
    end
    
    def composed_of(name, opts = {})
      Aggregations::AggregationReflection.new(base_class, :composed_of, name, opts)
    end

    [
      "table_name=", "before_validation", "with_options", "validates_presence_of", "validates_format_of", 
      "accepts_nested_attributes_for", "after_create", "before_save", "before_destroy", "where", "validate", 
      "attr_protected", "validates_numericality_of", "default_scope", "has_attached_file", "attr_accessible"
    ].each do |method|
      define_method(method.to_s) { |*args, &block| }
    end
    
    def _react_param_conversion(param, opt = nil)
      # defines how react will convert incoming json to this ActiveRecord model
      param_is_native = !param.respond_to?(:is_a?) rescue true
      param = JSON.from_object param if param_is_native
      if param.is_a? self
        param
      elsif param.is_a? Hash
        if opt == :validate_only
          ReactiveRecord::Base.infer_type_from_hash(self, param) == self
        else
          param.each { |key, value| param[key] = [value] }
          ReactiveRecord::Base.load_from_json({self.name => {["find", param[self.primary_key].first] =>  param})
        end
      else
        nil
      end
    end
    
  end
  
end