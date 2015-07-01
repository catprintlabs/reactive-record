require 'json'

module ReactiveRecord
  
  def self.load(&block)
    promise = Promise.new
    @load_stack ||= []
    @load_stack << @loads_pending
    @loads_pending = nil
    block.call
    if @loads_pending
      @blocks_to_load ||= []
      @blocks_to_load << [promise, block]
    else
      promise.resolve
    end
    @loads_pending = @load_stack.pop
    promise
  end
  
  def self._load_pending!
    @loads_pending = true
  end
  
  def self._run_blocks_to_load
    if @blocks_to_load
      @blocks_to_load = @blocks_to_load.collect do |promise_and_block|
        @loads_pending = nil
        block.call
        if @loads_pending
          promise_and_block
        else
          promise.resolve
          nil
        end
      end.compact
    end
  end
  
  class Cache
    
    attr_reader :last_fetch_at
    
    attr_reader :while_loading_counter
        
    def get_next_while_loading_counter(i)
      if RUBY_ENGINE != 'opal' or `typeof window.ReactiveRecordCache == 'undefined'`
        # we are on the server and have been called by the opal side, or we are the client
        @while_loading_counter += 1
      else
        # we are on the server on the opal side, so send the message over the ruby side (see previous line)
        `window.ReactiveRecordCache.get_next_while_loading_counter(1)`.to_i
      end
    end
    
    def preload_css(css)
      if RUBY_ENGINE != 'opal'
        @css_to_preload << css << "\n"
      elsif `typeof window.ReactiveRecordCache != 'undefined'`
        `window.ReactiveRecordCache.preload_css(#{css})`
      end
    end
    
    def css_to_preload!
      @css_to_preload.tap { @css_to_preload = "" }
    end
    
    def cookie(name)
      if RUBY_ENGINE != 'opal'
        @controller.send(:cookies)[name]
      elsif `typeof window.ReactiveRecordCache != 'undefined'`
        `window.ReactiveRecordCache.cookie(#{name})`
      end
    end
    
    def initialize(controller = nil)
      @controller = controller
      @initial_data = Hash.new {|hash, key| hash[key] = Hash.new}
      @while_loading_counter = 0
      @css_to_preload = ""
      if RUBY_ENGINE == 'opal' and `typeof window.ReactiveRecordCache == 'undefined'`
        # we are running on the client 
        require 'opal-jquery'
        #puts "running on the client"
        @while_loading_counter = `ReactiveRecordInitialWhileLoadingCounter` rescue 0
        @pending_fetches = []
        @last_fetch_at = Time.now
        JSON.from_object(`ReactiveRecordInitialData`).each do |collection|
          collection.each do |klass, models|
            #puts "got #{klass} and #{models}"
            models.each { |key, value| Object.const_get(klass)._reactive_record_update_table(value) }
          end
        end if `typeof ReactiveRecordInitialData != 'undefined'`
      else
        #puts "hey not running on client"
      end
    end
    
    def self.on_server?
      `typeof window.ReactiveRecordCache != 'undefined'`
    end
    
    def fetch(klass, find_by, value, *associations)
      if RUBY_ENGINE != 'opal'
        # we are on the server and have been called by the opal side, so call the actual model
        #Object.const_get(klass).send("find_by_#{find_by}", value).tap { |model|  @initial_data[klass][[find_by, value.to_s]] = ReactiveRecord::Cache.build_json_hash(model) }.to_json
        ReactiveRecord::Cache.build_json_hash(Object.const_get(klass).send("find_by_#{find_by}", value)).tap { |model| @initial_data[klass][[find_by, value.to_s]] = model }.to_json
      elsif `typeof window.ReactiveRecordCache != 'undefined'`
        # we are on the server on the opal side, so send the message over the ruby side (see previous line)
        JSON.parse `window.ReactiveRecordCache.fetch(#{klass}, #{find_by}, #{value})`
      elsif attributes = @initial_data[klass][[find_by, value.to_s]]
        # we are on the client, and the data was sent down in the initial data set
        #puts "fetch found data in initial data: #{klass}, #{find_by}, #{value} = #{attributes}"
        attributes
      else
        # we are on the client, and we don't have this model instance, so add it to the queue
        #puts "fetch failed on client: #{klass}, #{find_by}, #{value}, #{associations}"
        ReactiveRecord._load_pending!
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
      puts "fetch exception #{RUBY_ENGINE} fetch(#{klass}, #{find_by}, #{value}, #{associations}) #{e}"
      raise e
    end
    
    def get_scope(klass, scope)
      # get the scope then add all the returned values to the Cache
    end
    
    def as_json(*args, &block)
      #puts "as_json: #{@initial_data}"
      @initial_data.tap { @initial_data = Hash.new {|hash, key| hash[key] = Hash.new} } unless RUBY_ENGINE == 'opal'
    end
    
    if RUBY_ENGINE != 'opal'
      
      def self.build_json_include_hash(record)
        Hash[
          *record.class.reflect_on_all_aggregations.collect { |aggregate| [aggregate.name, {}] }.flatten,
          *record.class.reflect_on_all_associations.collect do |assoc| 
            [assoc.name, {only: :id, include: Hash[assoc.klass.reflect_on_all_aggregations.collect { |aggregate| [aggregate.name, {}] }]}] 
          end.flatten
        ]
      end
    
      def self.build_json_hash(record)
        record.as_json root: nil, include: build_json_include_hash(record)
      end
      
    end
    
    
    def schedule_fetch
      #puts "start of fetch"
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
          ReactiveRecord._run_blocks_to_load
          WhileLoading.loaded_at last_fetch_at
          #puts "all done with fetch"
        end if @pending_fetches.count > 0
        @pending_fetches = []
        @pending_components = []
        @last_fetch_at = Time.now
        @fetch_scheduled = nil
      end
      #puts "end of fetch"
    rescue Exception => e
      puts "schdule_fetch Execption #{e.message}"
    end
    
  end
  
end
      
    