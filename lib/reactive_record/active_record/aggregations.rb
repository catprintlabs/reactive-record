module ActiveRecord

  class Base

    def self.reflect_on_all_aggregations
      base_class.instance_eval { @aggregations ||= [] }
    end

    def self.reflect_on_aggregation(attribute)
      reflect_on_all_aggregations.detect { |aggregation| aggregation.attribute == attribute }
    end

  end

  module Aggregations

    class AggregationReflection

      attr_reader :klass_name
      attr_reader :attribute
      attr_reader :mapped_attributes

      def initialize(owner_class, macro, name, options = {})
        owner_class.reflect_on_all_aggregations << self
        @owner_class = owner_class
        @klass_name =  options[:class_name] || name.camelize
        @attribute =   name
        @mapped_attributes = options[:mapping].collect &:last
      end

      def klass
        @klass ||= Object.const_get(@klass_name)
      end

    end

  end


end
