module ActiveRecord
  class Base
    
    extend  ClassMethods
     
    include InstanceMethods
    
    include Associations
    
    include Aggregations
    
    include ReactiveAttributes
    
  end