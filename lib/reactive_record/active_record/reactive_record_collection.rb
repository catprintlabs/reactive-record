module ReactiveRecord
  
  class Collection
  
    def initialize(target_klass, owner = nil, association = nil, *vector)
      @owner = owner  # can be nil if this is an outer most scope
      @association = association
      @target_klass = target_klass
      @vector = vector.count == 0 ? [target_klass] : vector
      @scopes = {}
    end

    def all
      unless @collection
        @collection = []
        if ids = fetch_from_db(*@vector, "*all")  
          ids.each do |id| 
            @collection << @target_klass.find(@target_klass.primary_key, id) 
          end
        else
          load_from_db(@vector, "*all")
          @collection << @target_klass.new(ReactiveRecord.new_from_vector(@target_klass, nil, [*@vector, "*"]))
        end
      end
      @collection
    end
    
    def apply_scope(scope)
      # The value returned is another ReactiveRecordCollection with the scope added to the vector
      # no additional action is taken
      @scopes[scope] ||= new(@target_klass, @owner, @association, *vector, scope)
    end
    
    def proxy_association
      @association
    end
    
    def <<(item)
      item.attributes[inverse_of.attribute] = @owner if @owner and inverse_of = @association.inverse_of
      all << item unless all.include? item
    end
  
    def method_missing(method, *args, &block)
      if [].respond_to? method
        all.send(method, *args, &block)
      elsif @target_klass.respond_to? method
        apply_scope(method)
      else
        super
      end
    end
    
  end
  
end