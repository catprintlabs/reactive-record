require 'json'
require 'opal-react/prerender_data_interface'

module React
  
  class PrerenderDataInterface
    
    alias_method :pre_reactive_record_initialize, :initialize
    
    def initialize(*args)
      pre_reactive_record_initialize(*args)
      @initial_data = Hash.new {|hash, key| hash[key] = Hash.new}
      if on_opal_client?
        @pending_fetches = []
        @last_fetch_at = Time.now
        JSON.from_object(`window.ClientSidePrerenderDataInterface.ReactiveRecordInitialData`).each do |collection|
          collection.each do |klass, models|
            models.each { |key, value| Object.const_get(klass)._reactive_record_update_table(value) }
          end
        end unless `typeof window.ClientSidePrerenderDataInterface === 'undefined'`
      end
    end
    
    attr_reader :last_fetch_at
    
    def self.last_fetch_at
      load!.last_fetch_at
    end

      #def self.on_server?
      #  `typeof window.ReactiveRecordCache != 'undefined'`
      #end

    def fetch(klass, find_by, value, *associations)
      if RUBY_ENGINE != 'opal'
        # we are on the server and have been called by the opal side, so call the actual model
        #Object.const_get(klass).send("find_by_#{find_by}", value).tap { |model|  @initial_data[klass][[find_by, value.to_s]] = ReactiveRecord.build_json_hash(model) }.to_json
        ReactiveRecord.build_json_hash(klass.camelize.constantize.send("find_by_#{find_by}", value)).tap { |model| @initial_data[klass][[find_by, value.to_s]] = model }.to_json
      elsif React::PrerenderDataInterface.on_opal_server?
        # we are on the server on the opal side, so send the message over the ruby side (see previous line)
        #puts "on server side fetch(#{klass}, #{find_by}, #{value}, #{associations})"
        JSON.parse `window.ServerSidePrerenderDataInterface.fetch(#{klass}, #{find_by}, #{value})`
      elsif attributes = @initial_data[klass][[find_by, value.to_s]]
        # we are on the client, and the data was sent down in the initial data set
        #puts "fetch found data in initial data: #{klass}, #{find_by}, #{value} = #{attributes}"
        attributes
      else
        # we are on the client, and we don't have this model instance, so add it to the queue
        #puts "fetch failed on client: #{klass}, #{find_by}, #{value}, #{associations}"
        ReactiveRecord._loads_pending!
        React::WhileLoading.loading! # inform react that the current value is bogus
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
    
    def self.fetch(*args)
      load!.fetch(*args)
    end

    def get_scope(klass, scope)
      # get the scope then add all the returned values to the Cache
      # not implemented yet
    end

    unless RUBY_ENGINE == 'opal'
      
      alias_method :pre_reactive_record_generate_next_footer, :generate_next_footer
      
      def generate_next_footer
        json = @initial_data.to_json
        @initial_data = Hash.new {|hash, key| hash[key] = Hash.new}
        path = ::Rails.application.routes.routes.detect { |route| route.app == ReactiveRecord::Engine }.path.spec
        pre_reactive_record_generate_next_footer + ("<script type='text/javascript'>\n"+
          "window.ReactiveRecordEnginePath = '#{path}';\n"+
          "if (typeof window.ClientSidePrerenderDataInterface.ReactiveRecordInitialData === 'undefined') { window.ClientSidePrerenderDataInterface.ReactiveRecordInitialData = [] }\n" +
          "window.ClientSidePrerenderDataInterface.ReactiveRecordInitialData.push(#{json})\n"+
          "</script>\n"
        ).html_safe
      end
      
    end

    def schedule_fetch
      #puts "start of fetch"
      @fetch_scheduled ||= after(0.001) do
        #puts "starting fetch"
        last_fetch_at = @last_fetch_at
        HTTP.post(`window.ReactiveRecordEnginePath`, payload: {pending_fetches: @pending_fetches.uniq}).then do |response| 
          #puts "fetch returned"
          response.json.each do |klass, models|
            models.each do |id, attributes|
              model = Object.const_get(klass) rescue nil
              if model
                model._reactive_record_update_table(attributes)
              else
                message = "Server returned unknown model: #{klass}."
                `console.error(#{message})`
              end 
            end
          end
          #puts "updating observers"
          ReactiveRecord._run_blocks_to_load
          React::WhileLoading.loaded_at last_fetch_at
          #puts "all done with fetch"
        end if @pending_fetches.count > 0
        @pending_fetches = []
        @pending_components = []
        @last_fetch_at = Time.now
        @fetch_scheduled = nil
      end
      #puts "end of fetch"
    rescue Exception => e
      puts "schedule_fetch Execption #{e.message}"
    end
    
  end
  
end
    

module ReactiveRecord
  
  if RUBY_ENGINE != 'opal'
    
    def self.get_type_hash(record)
      {record.class.inheritance_column => record[record.class.inheritance_column]}
    end

    def self.build_json_include_hash(record)
      Hash[
        *record.class.reflect_on_all_aggregations.collect { |aggregate| [aggregate.name, {}] }.flatten,
        *record.class.reflect_on_all_associations.collect do |assoc| 
          [
            assoc.name, 
            {only: :id, include: Hash[assoc.class_name.camelize.constantize.reflect_on_all_aggregations.collect { |aggregate| [aggregate.name, {}]}]}
          ] unless assoc.options[:server_only]
        end.compact.flatten
      ]
    end

    def self.build_json_hash(record)
      record.serializable_hash(include: build_json_include_hash(record)).merge(get_type_hash(record))
    end

  end
  
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
  
  def self._loads_pending!
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
  
end

    