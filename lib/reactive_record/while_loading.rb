#require 'reactive_record'

module ReactiveRecord
  
  class WhileLoading
    
    include React::Component
    
    required_param :loaded_display_block
    required_param :loading_display_block
    optional_param :display, default: ""
    
    def self.loading!
      puts "loading! current_observer: #{React::State.current_observer}"
      React::State.get_state(self, :loaded_at)
    end

    def self.loaded_at(loaded_at)
      React::State.set_state(self, :loaded_at, loaded_at)
    end
    
    def render
      div(class: :reactive_record_while_loading_container, "data-reactive_record_while_loading_container_id" => object_id) do
        div(class: :reactive_record_show_loaded_container) do
          React::RenderingContext.render(nil, &loaded_display_block)
        end
        div(class: :reactive_record_show_loading_container) do
          if loading_display_block
            React::RenderingContext.render(nil, &loading_display_block)
          else
            display.to_s
          end
        end
      end
    end
    
  end
  
end


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
    
    alias_method :original_component_did_mount, :component_did_mount
    
    def component_did_mount(*args)
      puts "#{self}.component_did_mount"
      original_component_did_mount(*args)
      reactive_record_show_loading_or_unloading
    end
    
    alias_method :original_component_did_update, :component_did_update
    
    def component_did_update(*args)
      puts "#{self}.component_did_update"
      original_component_did_update(*args)
      reactive_record_show_loading_or_unloading
    end
    
    def reactive_record_show_loading_or_unloading
      loading = React::State.is_observing?(ReactiveRecord::WhileLoading, :loaded_at, self)
      node = `#{@native}.getDOMNode()`
      `if ($(node).hasClass('reactive_record_while_loading_container')) node = $(node).parent()`  unless self.is_a? ReactiveRecord::WhileLoading
      while_loading_container = `$(node).closest('.reactive_record_while_loading_container')`.first
      puts "#{self}.after_update loading=(#{loading})"
      # `debugger` if loading
      return unless while_loading_container
      loading_container_id = `$(while_loading_container).attr('data-reactive_record_while_loading_container_id')`
      if loading
        `$(node).addClass('reactive_record_'+#{loading_container_id}+'_is_loading')`
        `$(while_loading_container).children('.reactive_record_show_loaded_container').hide()`
        `$(while_loading_container).children('.reactive_record_show_loading_container').show()`
        puts "SHOULD HAVE HIDDEN SOMETHING"
        # `debugger` 
        nil
      else
        `$(node).removeClass('reactive_record_'+#{loading_container_id}+'_is_loading')`
        children_loading = `$(while_loading_container).find('.reactive_record_'+#{loading_container_id}+'_is_loading')`

        if children_loading.length > 0
          puts "SHOULD BE HIDING"
        else
          puts "SHOULD BE DISPLAYING"
        end
        # `debugger`
        `$(while_loading_container).children('.reactive_record_show_loaded_container').toggle(!children_loading.length > 0)`
        `$(while_loading_container).children('.reactive_record_show_loading_container').toggle(children_loading.length > 0)`
        nil
      end    
    end
      
    def while_loading(opts = {}, &loaded_display_block)
      puts "well I am trying to render this baby"
      RenderingContext.render(
        ReactiveRecord::WhileLoading, 
        opts.merge({loaded_display_block: loaded_display_block, loading_display_block: nil})
      ).setup_while_loading(opts, loaded_display_block)
    end
  
  end

end

