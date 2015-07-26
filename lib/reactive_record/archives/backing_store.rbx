module ActiveRecord
  
  module BackingStore 
    
    # public api class methods:
    #  none 
    
    # public internal classes:
    #  BackingRecord  (subclass of Hash so loaded BackingRecords can be distinguished from unprocessed Hashes)
    
    # public internal class methods:
    #  _reactive_record_table_find         (finds a record in the table, returns a BackingRecord or nil)
    #  _reactive_record_update_table       (finds AND updates a record from a hash, always returns a BackingRecord) 
    #  _reactive_record_delete_from_table  (deletes a record from the system, including all association references, and all instances)

    # depends on: 
    #  ActiveRecord::ClassMethods (base_class)
    #  ActiveRecord::Association
    #  React::PrerenderDataInterface (load!)
    #  ActiveRecord::Instance (_reactive_record_mark_instances_as_deleted)
    
    # BackingStore contains the internal methods to maintain copies of ActiveRecord records on the client
    # Only loaded (or saved) records with valid primary_key ids are stored.
    
    # Any associations are fully modeled in the BackingStore.  So belongs_to, and has_one attributes will point 
    # to nil or some other BackingRecord. And has_many attributes will have an Association object
    # The conversion from nested hashes and arrays as delivered by ActiveRecord serializable_hash will be converted
    # to this structure when _reactive_record_update_table is called.
    
    # Likewise when a record is deleted, any associations will be removed
    
    class BackingRecord < Hash
    end
    
    def _reactive_record_table
      base_class.instance_eval { @table ||= [] }
    end

    def _reactive_record_table_find(attribute, value)
      base_class.instance_eval do
        # before looking up the records make sure that we have fetched all the prerender data
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
      # record can be a Hash or a BackingRecord.  If its a backing record it just gets returned.
      # if its a hash we need to check all the associations of the class and if these are in the hash
      # we need to realize them as links to other records or Associations
      
      #puts "rr_update_table  #{record}, #{primary_key}"
      
      return record if record.is_a? BackingRecord
      
      raise "_reactive_record_update_table called with invalid record" unless record.is_a? Hash and record[primary_key]
      
      base_class.instance_eval do
        
        reflect_on_all_associations.each do | association | 
          record[attribute] = if record[association.attribute].is_a? Array
            Association.new(record[attribute].collect { |r| association.klass.new(r) }], self, association)
          elsif record[association.attribute]
            klass.new(record[attribute])
          end
        end

        if r = _reactive_record_table_find(primary_key, record[primary_key])
          r.merge! record
        else
          record = BackingRecord[record]
          record.state = :loaded
          _reactive_record_table << record
          record
        end
        
      end
    end
    
    def _reactive_record_delete_from_table(record_to_delete) 
      base_class.instance_eval do
        reflect_on_all_associations.each do | association | 
          associations = record_to_delete[association.attribute] 
          associations = [associations] unless association[:macro] == :has_many
          parent_attribute = association.inverse_of.attribute
          associations.each do |associated_record|
            association.inverse_of.klass.instance_eval do
              if association.inverse_of.macro == :has_many
                parent_associations = associated_record[parent_attribute]
                parent_associations.delete(record_to_delete)
                _reactive_record_report_set(associated_record, {parent_attribute => parent_associations})
              else
                associatiated_record[parent_attribute] = nil
                _reactive_record_report_set(parent_record, {parent_attribute => nil}) 
              end
            end
          end
        end
        _reactive_record_table.reject! { |record| record[primary_key].to_s == id.to_s }
        _reactive_record_mark_instances_as_deleted record
      end
    end
    
  end
end