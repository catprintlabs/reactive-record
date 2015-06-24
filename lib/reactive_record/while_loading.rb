module React
  
  class Element
      
    def setup_while_loading(opts, loaded_display_block)
      puts "setting up while_loading"
      @while_loading_opts = opts || {}
      @loaded_display_block = loaded_display_block
      self
    end
  
    def show(s = nil, &loading_display_block)
      puts "adding the show thing"
      raise "show can only be attached to a while_loading element" unless @while_loading_opts
      @while_loading_opts.merge!(display: s) unless loading_display_block
      RenderingContext.replace(
        self,
        React.create_element(
          ReactiveRecord::WhileLoading, 
          @while_loading_opts.merge({loaded_display_block: @loaded_display_block, loading_display_block: loading_display_block})
      ))
    end
      
  end

  module Component
  
    def while_loading(opts = {}, &loaded_display_block)
      puts "well I am trying to render this baby"
      RenderingContext.render(
        ReactiveRecord::WhileLoading, 
        opts.merge({loaded_display_block: loaded_display_block, loading_display_block: nil})
      ).setup_while_loading(opts, loaded_display_block)
    end
  
  end

end

module ReactiveRecord
  
  class WhileLoading
    
    include React::Component
    
    required_param :loaded_display_block
    required_param :loading_display_block
    optional_param :display, default: ""
    
    def self.current_loading_observer
      if @current_loading_observers and @current_loading_observers.count > 0
        @current_loading_observers.last
      else
        React::State.current_observer
      end
    end
    
    def self.push_current_loading_observer
      (@current_loading_observers ||= []) << current_loading_observer
    end
    
    def self.pop_current_loading_observer
      @current_loading_observers.pop
    end
    
    def self.loading!
      puts "adding observer for #{current_loading_observer} self = #{self}, WhileLoading = #{WhileLoading}"
      #React::State.get_state(self, :loaded_at)
      React::State.get_state(self, :loaded_at, current_loading_observer) # will register current observer
    end

    def self.loaded_at(loaded_at)
      puts "updating loaded_at to #{loaded_at}"
      React::State.set_state(self, :loaded_at, loaded_at)
    end
    
    def self.loading?
      React::State.will_be_observing?(self, :loaded_at, current_loading_observer) 
    end
    
    after_mount do
      puts "while_loading after_mount"
      WhileLoading.pop_current_loading_observer
      puts "after while mount #{self} will_be_observing? #{React::State.will_be_observing?(WhileLoading, :loaded_at, self)} showing loaded display: (#{@showing_loaded_display_block})"
      if React::State.will_be_observing?(WhileLoading, :loaded_at, self) and @showing_loaded_display_block 
        puts "FORCING UPDATE AFTER MOUNT!!!!!!!!!!"
        @forced_update = true
        force_update!
      end
    end
    
    before_update do
      WhileLoading.loading! if @forced_update
    end
    
    after_update do
      WhileLoading.pop_current_loading_observer
      @forced_update = false
      puts "after while rendering update #{self} will_be_observing? #{React::State.will_be_observing?(WhileLoading, :loaded_at, self)} showing loaded display: (#{@showing_loaded_display_block})"
      if React::State.will_be_observing?(WhileLoading, :loaded_at, self) and @showing_loaded_display_block 
        puts "FORCING UPDATE AFTER RENDER!!!!!!!!!!"
        @forced_update = true
        force_update!
      end
    end
    
    def render
      puts "while rendering"
      WhileLoading.push_current_loading_observer
      unless WhileLoading.loading? and @showing_loaded_display_block
        puts "rendering loaded display"
        element = React::RenderingContext.render(nil, &loaded_display_block)
        @showing_loaded_display_block = true
      end
      if WhileLoading.loading? 
        puts "replacing loaded display with loading display"
        React::RenderingContext.delete(element)
        if loading_display_block
          puts "replacing with block call"
          element = React::RenderingContext.render(nil, &loading_display_block)
        else
          puts "replacing with display value: #{display}"
          element = display.to_s 
        end
        @showing_loaded_display_block = false
      end
      puts "returning #{element}"
      element
    end
    
  end
  
end
  