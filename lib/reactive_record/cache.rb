require 'json'
require 'opal-react/prerender_data_interface'

module React

  class PrerenderDataInterface

    alias_method :pre_reactive_record_initialize, :initialize

    def initialize(*args)
      pre_reactive_record_initialize(*args)
      if on_opal_client?
        @pending_fetches = []
        @last_fetch_at = Time.now
        ReactiveRecord::Base.load_from_json(
            JSON.from_object(`window.ClientSidePrerenderDataInterface.ReactiveRecordInitialData`)
        ) unless `typeof window.ClientSidePrerenderDataInterface === 'undefined'`
      end
    end

    attr_reader :last_fetch_at

    def self.last_fetch_at
      load!.last_fetch_at
    end
    
    def server_data_cache
      class_eval { @server_data_cache ||= ReactiveRecord::ServerDataCache.new }
    end   
    
    def fetch_from_db(vector) 
      # vector must end with either :all, or be a simple attribute
      if RUBY_ENGINE != 'opal'
        # we are on the server and have been called by the opal side, so call the actual model
        server_data_cache[*vector].value
      elsif React::PrerenderDataInterface.on_opal_server?
        klass_name = klass.name
        # we are on the server on the opal side, so send the message over the ruby side (see previous if block)
        JSON.parse `window.ServerSidePrerenderDataInterface.fetch_from_db(#{vector})`
      end
    end
    
    def find_in_db(klass, attribute, value)
      if RUBY_ENGINE != 'opal'
        # we are on the server and have been called by the opal side, so call the actual model
        server_data_cache[klass, attribute, value].id
      elsif React::PrerenderDataInterface.on_opal_server?
        klass_name = klass.name
        # we are on the server on the opal side, so send the message over the ruby side (see previous if block)
        JSON.parse `window.ServerSidePrerenderDataInterface.find_in_db(#{klass_name}, #{attribute}, #{value})`
      end
    end

    def load_from_db(*vector)
      # only called from the client side
      # pushes the value of vector onto the a list of vectors that will be loaded from the server when the next
      # rendering cycle completes.  
      # takes care of informing react that there are things to load, and schedules the loader to run
      # Note there is no equivilent to find_in_db, because each vector implicitly does a find.
      ReactiveRecord.loads_pending!
      React::WhileLoading.loading! # inform react that the current value is bogus
      @pending_fetches << vector
      schedule_fetch
      ""
    end


#what was this for????
#    def self.fetch(*args)
#      load!.fetch(*args)
#    end

    unless RUBY_ENGINE == 'opal'

      alias_method :pre_reactive_record_generate_next_footer, :generate_next_footer

      def generate_next_footer
        json = server_data_cache.clear_requests.as_json
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
      @fetch_scheduled ||= after(0.001) do
        last_fetch_at = @last_fetch_at
        HTTP.post(`window.ReactiveRecordEnginePath`, payload: {pending_fetches: @pending_fetches.uniq}).then do |response|
          ReactiveRecord::Base.load_from_json(response.json)
          ReactiveRecord.run_blocks_to_load
          React::WhileLoading.loaded_at last_fetch_at
        end if @pending_fetches.count > 0
        @pending_fetches = []
        @last_fetch_at = Time.now
        @fetch_scheduled = nil
      end
    rescue Exception => e
      puts "schedule_fetch Exception #{e.message}"
    end

  end

end


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

  def self.loads_pending!
    @loads_pending = true
  end

  def self.run_blocks_to_load
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