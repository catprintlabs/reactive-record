module ActiveRecord
  
  class ReactiveRecords
    
    class Record
      
      attr_reader :record_store
      attr_reader :model_name
      attr_reader :last_fetch_at
      attr_reader :last_access_at
      attr_reader :state
            
      #       nil       (the record is unloaded, and loading has not begun)
      #       :loading  (the record is still unloaded, but loading has begun)
      #       :synced   (the record is loaded and/or was saved to the database, loaded = synced)
      #       :saving   (the record is being saved)
      #       :new      (the record is newly created on the client)
      #       :deleting (the record is being deleted)
      #       :deleted  (the record has been deleted)
      
      def initialize(record_store, hash, vector, state = nil)
        @record_store = record_store
        @model_name = record_store.model_klass.model_name
        @hash = hash
        @vector = vector 
        @state = state
        @last_fetch_at = nil
        @last_access_at = Time.now
        @synced_hash = @hash if state == :synced
      end
            
      def sync!(incoming_hash = nil)  
        @hash.merge! incoming_hash if incoming_hash
        @synced_hash = @hash
        @record_store.synced_records << self unless [:saving, :synced].include? @state
        @state = :synced
        React::State.set_state(self, :state, @state)
        self
      end
      
      def saving!
        @state = :saving
        React::State.set_state(self, :state, @state)
        self
      end
      
      def delete!
        @record_store.model_klass.reflect_on_all_associations.each do | association | 
          associations = self[association.attribute] 
          associations = [associations] unless association[:macro] == :has_many
          parent_attribute = association.inverse_of.attribute
          associations.each do |associated_record|
            association.inverse_of.klass.instance_eval do
              if association.inverse_of.macro == :has_many
                parent_associations = associated_record[parent_attribute]
                parent_associations.delete(self)
                _reactive_record_report_set(associated_record, {parent_attribute => parent_associations})
              else
                associatiated_record[parent_attribute] = nil
                _reactive_record_report_set(parent_record, {parent_attribute => nil}) 
              end
            end
          end
        end
        @record_store.synced_records.delete(self)
        @state = :deleted
        @synced_hash = nil
      end
      
      def primary_key
        record_store.primary_key
      end
      
      def vector
        if @hash[primary_key]
          [@model_name, primary_key, @hash[primary_key]]
        elsif !@vector
          raise "no vector!"
        else
          @vector
        end
      end
      
      def hash
        @last_access_at = Time.now
        @hash
      end
      
      def [](attribute)
        hash[attribute]
      end
      
      def []=(attribute, value)
        hash[attribute] = value
      end
      
      def reactive_get!(attribute)
        React::State.get_state(@hash, attribute)
        hash[attribute]
      end
      
      def reactive_set!(attribute, value)
        hash[attribute] = value
        React::State.set_state(@hash, attribute, value)
        value
      end
      
      def get_state!
        React::State.get_state(self, :state)
        @state
      end
      
      def changed?(*args)
        args.count == 0 ? React::State.get_state(self, :state) : React::State.get_state(@hash, args[0])
        @synced_hash and @hash != @synced_hash and (args.count == 0 or @hash[args[0]] != @synced_hash[args[0]])
      end
      
    end
  
    def new(model_klass)
      @model_klasses ||= {}
      @model_klasses[model_klass] = super(model_klass)
    end
    
    attr_reader :model_klass
    attr_reader :synced_records
    attr_reader :vectors
    
    def initialize(model_klass)
      @model_klass = model_klass
      @synced_records = []
      @vectors = {}
    end
    
    def primary_key
      @model_klass.primary_key
    end
    
    def infer_type_from_hash(hash)
      return @model_klass unless hash
      type = hash[@model_klass.inheritance_column]
      begin
        return Object.const_get(type)
      rescue Exeception => e
        message = "Could not subclass #{@model_klass.model_name} as #{type}.  Perhaps #{type} class has not been required. Exception: #{e}"
        `console.error(#{message})`
      end if type
      self
    end
    
    def new_record(hash)
      Record.new(self, hash, [], :new_record)
    end
    
    def new_model_instance(hash_or_vector)
      if hash_or_vector.is_a? Array
        vector = Record.new(self, {}, hash_or_vector)
        model_klass.new(vector)
        @vectors[vector] ||= vector
      else
        model_klass.infer_type_from_hash(hash_or_vector).new sync(hash_or_vector)
      end
    end
      
    def find(attribute, value)
      # before looking up the records make sure that we have fetched all the prerender data
      unless @load_started
        # protects this from recursive loading since _reactive_record_table_find is called from PrerenderDataInterface#initialize
        @load_started = true
        React::PrerenderDataInterface.load!
      end
      @synced_records.detect { |record| record[attribute].to_s == value.to_s }
    end
    
    def sync(record)
      
      # record can be a Hash or a ReactiveRecord::Record.  If its a Record it just gets synced and returned.
      
      # If its a hash we need to check all the associations of the class and if these are in the hash
      # we need to realize them as links to other records or Associations.
      
      # Then we look for any vectors (records without primary_keys) and merge these with the new record
            
      return record.sync! if record.is_a? Record
      
      raise "_reactive_record_update_table called with invalid record" unless record.is_a? Hash and record[primary_key]
        
      @model_klass.reflect_on_all_associations.each do | association | 
        attribute = association.attribute
        record[attribute] = if record[attribute].is_a? Array
          Association.new(record[attribute].collect { |r| association.klass.new(r) }], self, association)
        elsif record[attribute]
          klass.new(record[attribute])
        end
      end
      
      if r = find(primary_key, record[primary_key])
        r.sync! record
      else
        Record.new(self, hash, [], :synced).tap { |new_record| @synced_records << new_record }
      end
        
    end
      
      
    def sync_vector(vector, record)
      
      matching_vectors = @vectors[]
      
      @model_klass.reflect_on_all_associations.each do | association |
        attribute = association.attribute
        if record[attribute].is_a? Association
          
      
    def self.[](model_klass)
      @model_klasses[model_klass]
    end
    
    def self.all_records
      @model_klasses.collect { |model_klass, records| records.records }.flatten(1)
    end
  
  end
  
  module ReactiveRecordStore
    
    def self.included(base) 
      base.class_eval do
        def _reactive_record_store
          base_class.class_eval do
            @reactive_record_store ||= ReactiveRecords.new(self)
          end
        end
      end    
    end
    
    def _reactive_record_store
      self.class._reactive_record_store
    end
    
  end
end
      
      
        
        