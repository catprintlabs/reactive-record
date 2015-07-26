module ActiveRecord
  
  class Base
    
    def reflect_on_all_associations
      base_class.instance_eval { @associations ||= [] }
    end
    
    def self.reflect_on_association(attribute)
      reflect_on_all_associations.detect { |association| association.attribute == attribute }}
    end
  
  end
  
  module Associations
    
    class AssociationReflection
      
      attr_reader :foreign_key
      attr_reader :klass_name
      attr_reader :attribute
      attr_reader :macro
            
      def initialize(owner_class, macro, name, options = {})
        owner_class.reflect_on_all_associations << self
        @owner_class = owner_class
        @macro =       macro
        @klass_name =  options[:class_name] || (collection? && name.camelize.gsub(/s$/,"")) || name.camelize
        @foreign_key = options[:foreign_key] || "#{name}_id"
        @attribute =   name
      end
      
      def inverse_of
        @inverse_of ||= klass.base_class.instance_eval do
          reflect_on_all_associations.detect { | association | association.foreign_key == @foreign_key }
        end
      end
      
      def klass
        @klass ||= Object.const_get(@klass_name)
      end
      
      def collection?
        [:has_many].include? @macro
      end
      
    end
    
  end
  
  
end