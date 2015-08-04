require 'json'

module ReactiveRecord

  class Base
    
    include React::IsomorphicHelpers
        
    before_first_mount do
      puts "mounting reactive record"
      if RUBY_ENGINE != 'opal'
        @server_data_cache = ReactiveRecord::ServerDataCache.new
      else
        @records = Hash.new { |hash, key| hash[key] = [] }
        if on_opal_client? 
          @pending_fetches = []
          @last_fetch_at = Time.now
          JSON.from_object(`window.ReactiveRecordInitialData`).each do |hash|
            load_from_json hash
          end unless `typeof window.ReactiveRecordInitialData === 'undefined'`
        end
      end
    end
    
    def records
      self.class.instance_variable_get(:@records)
    end
    
    # Prerendering db access (returns nil if on client):
    # at end of prerendering dumps all accessed records in the footer
    
    isomorphic_method(:fetch_from_db) do |f, vector|
      # vector must end with either "*all", or be a simple attribute
      puts "fetch from db vector = #{vector} RUBY_ENGINE = #{RUBY_ENGINE}"
      f.send_to_server [vector.shift.name, *vector] if  RUBY_ENGINE == 'opal'
      f.when_on_server { @server_data_cache[*vector] }
    end
    
    isomorphic_method(:find_in_db) do |f, klass, attribute, value|
      puts "OKAY OKAY OKAY #{klass}, #{attribute}, #{value}"
      f.send_to_server klass.name, attribute, value if  RUBY_ENGINE == 'opal'
      f.when_on_server { @server_data_cache[klass, ["find_by_#{attribute}", value], :id] }
    end
    
    prerender_footer do
      json = @server_data_cache.as_json.to_json  # can this just be to_json?
      @server_data_cache.clear_requests
      path = ::Rails.application.routes.routes.detect { |route| route.app == ReactiveRecord::Engine }.path.spec
      "<script type='text/javascript'>\n"+
        "window.ReactiveRecordEnginePath = '#{path}';\n"+
        "if (typeof window.ReactiveRecordInitialData === 'undefined') { window.ReactiveRecordInitialData = [] }\n" +
        "window.ReactiveRecordInitialData.push(#{json})\n"+
      "</script>\n"
    end if RUBY_ENGINE != 'opal'
    
    # Client side db access (never called during prerendering):
    # queue up fetches, and at the end of each rendering cycle fetch the records
    # notify that loads are pending

    def self.load_from_db(*vector)
      # only called from the client side
      # pushes the value of vector onto the a list of vectors that will be loaded from the server when the next
      # rendering cycle completes.  
      # takes care of informing react that there are things to load, and schedules the loader to run
      # Note there is no equivilent to find_in_db, because each vector implicitly does a find.
      puts "load_from_db called with #{vector}"
      ReactiveRecord.loads_pending!
      ReactiveRecord::WhileLoading.loading! # inform react that the current value is bogus
      @pending_fetches << vector
      schedule_fetch
      ""
    end

    def self.schedule_fetch
      @fetch_scheduled ||= after(0.001) do
        last_fetch_at = @last_fetch_at
        HTTP.post(`window.ReactiveRecordEnginePath`, payload: {pending_fetches: @pending_fetches.uniq}).then do |response|
          begin
            ReactiveRecord::Base.load_from_json(response.json)
          rescue Exception => e
            puts "Exception raised while loading json #{e}"
          end
          puts "schedule fetch"
          ReactiveRecord.run_blocks_to_load
          ReactiveRecord::WhileLoading.loaded_at last_fetch_at
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