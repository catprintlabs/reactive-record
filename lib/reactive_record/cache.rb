require 'json'
require 'opal-jquery'

module ReactiveRecord
  
  class Cache
    
    attr_reader :last_fetch_at
    
    def initialize
      @initial_data = Hash.new {|hash, key| hash[key] = Hash.new}
      if RUBY_ENGINE == 'opal' and `typeof window.ReactiveRecordCache == 'undefined'`
        # we are running on the client 
        #puts "running on the client"
        @pending_fetches = []
        @last_fetch_at = Time.now
        JSON.from_object(`ReactiveRecordInitialData`).each do |klass, models|
          #puts "got a #{klass} and #{models}"
          @initial_data[klass] = models
        end if `typeof ReactiveRecordInitialData != 'undefined'`
      end
    end
    
    def fetch(klass, find_by, value, *associations)
      if RUBY_ENGINE != 'opal'
        # we are on the server and have been called by the opal side, so call the actual model
        Object.const_get(klass).send("find_by_#{find_by}", value).tap { |model| @initial_data[klass][[find_by, value]] = ReactiveRecord::Cache.build_json_hash(model) }.to_json
      elsif `typeof window.ReactiveRecordCache != 'undefined'`
        # we are on the server on the opal side, so send the message over the ruby side (see previous line)
        JSON.parse `window.ReactiveRecordCache.fetch(#{klass}, #{find_by}, #{value})`
      elsif found = @initial_data[klass][[find_by, value.to_s]]
        # we are on the client, and the data was sent down in the initial data set
        found
      else
        # we are on the client, and we don't have this model instance, so add it to the queue
        #puts "fetch failed on client: #{klass}, #{find_by}, #{value}, #{associations}"
        WhileLoading.loading! # inform react that the current value is bogus
        #puts "element loading called"
        #React::State.get_state self, :last_fetch_at # this just sets up the current component to watch next_fetch_at
        #puts "get state called"
        @pending_fetches << [klass, find_by, value, *associations]
        #puts "added to queue"
        schedule_fetch
        #puts "fetch scheduled!"
        nil
      end
    rescue Exception => e
      puts "fetch exception #{RUBY_ENGINE}fetch(#{klass}, #{id}, #{associations}) #{e}"
    end
    
    def get_scope(klass, scope)
      # get the scope then add all the returned values to the Cache
    end
    
    def as_json(*args, &block)
      #puts "as_json: #{@initial_data}"
      @initial_data.tap { @initial_data = Hash.new {|hash, key| hash[key] = Hash.new} } unless RUBY_ENGINE == 'opal'
    end
    
    def self.build_json_hash(record)
      record.as_json root: nil, include: Hash[*record.class.reflect_on_all_associations.collect { |assoc| [assoc.name, {only: :id}]}.flatten]
    end
    
    def schedule_fetch
      @fetch_scheduled ||= after(1) do
        #puts "starting fetch"
        # how to get the current mount point???? hardcoding as /reactive_record for now
        last_fetch_at = @last_fetch_at
        HTTP.post("/reactive_record", payload: {pending_fetches: @pending_fetches.uniq}).then do |response| 
          #puts "fetch returned"
          response.json.each do |klass, models|
            models.each do |id, attributes|
              Object.const_get(klass)._reactive_record_update_table(attributes)
            end
          end
          #puts "updating observers"
          WhileLoading.loaded_at last_fetch_at
          #puts "all done with fetch"
        end if @pending_fetches.count > 0
        @pending_fetches = []
        @pending_components = []
        @last_fetch_at = Time.now
        @fetch_scheduled = nil
      end
    rescue Exception => e
      puts e.message
    end
    
  end
  
end
      
    