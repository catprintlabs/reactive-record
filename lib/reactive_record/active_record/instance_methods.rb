module ActiveRecord
  
  module InstanceMethods
        
    def attributes
      @backing_record
    end
    
    def initialize(hash = {})
      if hash.is_a? ReactiveRecord::Base
        @backing_record = hash
      else
        # standard active_record new -> creates a new instance, primary key is ignored if present
        hash[primary_key] = nil
        @backing_record = ReactiveRecord::Base.new(self.class, hash, self)
      end
    end
    
    def primary_key
      self.class.primary_key
    end
    
    def id
      @backing_record.id
    end
    
    def id=(value)
      @backing_record.id = value
    end

    def model_name
      # in reality should return ActiveModel::Name object, blah blah
      self.class.model_name
    end
    
    def changed?
      @backing_record.changed?
    end
    
    def ==(ar_instance)
      @backing_record == ar_instance.instance_eval { @backing_record }
    end
    
    def method_missing(name, *args, &block)
      if name =~ /_changed\?$/
        @backing_record.changed?(name.gsub(/_changed\?$/,""))
      elsif args.count == 1 && name =~ /=$/ && !block
        attribute_name = name.gsub(/=$/,"")
        @backing_record.reactive_set!(attribute_name, args[0])
        args[0]
      elsif args.count == 0 && !block
        @backing_record.reactive_get!(name) 
      else
        super
      end
    end
    
    def save(&block) 
      @backing_record.save &block
    end
    
    def destroy(&block)
      @backing_record.destroy &block
    end
    
  end
  
end
    