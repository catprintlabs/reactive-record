module ReactiveRecord

  class Collection

    def initialize(target_klass, owner = nil, association = nil, *vector)
      @owner = owner  # can be nil if this is an outer most scope
      @association = association
      @target_klass = target_klass
      if owner and !owner.id and vector.length <= 1
        @collection = []
      elsif vector.length > 0
        @vector = vector
      elsif owner
        @vector = owner.backing_record.vector + [association.attribute]
      else
        @vector = [target_klass]
      end
      @scopes = {}
    end

    def dup_for_sync
      self.dup.instance_eval do
        @collection = @collection.dup if @collection
        @scopes = @scopes.dup
        self
      end
    end

    def all
      @dummy_collection.notify if @dummy_collection
      unless @collection
        @collection = []
        if ids = ReactiveRecord::Base.fetch_from_db([*@vector, "*all"])
          ids.each do |id|
            @collection << @target_klass.find_by(@target_klass.primary_key => id)
          end
        else
          @dummy_collection = ReactiveRecord::Base.load_from_db(*@vector, "*all")
          @dummy_record = ReactiveRecord::Base.new_from_vector(@target_klass, nil, *@vector, "*")
          @dummy_record.backing_record.attributes[@association.inverse_of] = @owner if @association and @association.inverse_of
          @collection << @dummy_record
        end
      end
      @collection
    end

    def ==(other_collection)
      my_collection = (@collection || []).select { |target| target != @dummy_record }
      other_collection = (other_collection ? (other_collection.collection || []) : []).select { |target| target != other_collection.dummy_record }
      my_collection == other_collection
    end

    def apply_scope(scope, *args)
      # The value returned is another ReactiveRecordCollection with the scope added to the vector
      # no additional action is taken
      scope = [scope, *args] if args.count > 0
      @scopes[scope] ||= Collection.new(@target_klass, @owner, @association, *@vector, [scope])
    end

    def proxy_association
      @association || self # returning self allows this to work with things like Model.all
    end

    def klass
      @target_klass
    end


    def <<(item)
      backing_record = item.backing_record
      # if backing_record and @owner and @association and inverse_of = @association.inverse_of
      #   item.attributes[inverse_of].attributes[@association.attribute].delete(item) if item.attributes[inverse_of] and item.attributes[inverse_of].attributes[@association.attribute]
      #   item.attributes[inverse_of] = @owner
      #   React::State.set_state(backing_record, inverse_of, @owner) unless backing_record.data_loading?
      # end
      #all << item unless all.include? item
      all << item unless all.include? item
      if backing_record and @owner and @association and inverse_of = @association.inverse_of and item.attributes[inverse_of] != @owner
        current_association = item.attributes[inverse_of]
        backing_record.update_attribute(inverse_of, @owner)
        current_association.attributes[@association.attribute].delete(item) if current_association and current_association.attributes[@association.attribute]
        @owner.backing_record.update_attribute(@association.attribute) # forces a check if association contents have changed from synced values
      end
      @collection.delete(@dummy_record)
      @dummy_record = @dummy_collection = nil
      self
    end

    [:first, :last].each do |method|
      define_method method do |*args|
        if args.count == 0
          all.send(method)
        else
          apply_scope(method, *args)
        end
      end
    end

    def replace(new_array)
      #return new_array if @collection == new_array  #not sure we need this anymore
      @dummy_collection.notify if @dummy_collection
      @collection.dup.each { |item| delete(item) } if @collection
      @collection = []
      if new_array.is_a? Collection
        @dummy_collection = new_array.dummy_collection
        @dummy_record = new_array.dummy_record
        new_array.collection.each { |item| self << item } if new_array.collection
      else
        @dummy_collection = @dummy_record = nil
        new_array.each { |item| self << item }
      end
      new_array
    end

    def delete(item)
      if @owner and @association and inverse_of = @association.inverse_of
        if backing_record = item.backing_record and backing_record.attributes[inverse_of] == @owner
          # the if prevents double update if delete is being called from << (see << above)
          backing_record.update_attribute(inverse_of, nil)
        end
        all.delete(item).tap { @owner.backing_record.update_attribute(@association.attribute) } # forces a check if association contents have changed from synced values
      else
        all.delete(item)
      end
    end

    def method_missing(method, *args, &block)
      if [].respond_to? method
        all.send(method, *args, &block)
      elsif @target_klass.respond_to?(method) or (args.count == 1 && method =~ /^find_by_/)
        apply_scope(method, *args)
      else
        super
      end
    end

    protected

    def dummy_record
      @dummy_record
    end

    def collection
      @collection
    end

    def dummy_collection
      @dummy_collection
    end

  end

end
