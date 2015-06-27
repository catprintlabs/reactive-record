module ReactiveRecord
  
  class WhileLoading
    
    include React::Component
    
    required_param :loading
    required_param :loaded_children
    required_param :loading_children
    required_param :element_type
    required_param :element_props
    optional_param :display, default: ""
     
    class << self
            
      def loading!
        #puts "loading! current_observer: #{React::State.current_observer}"
        React::RenderingContext.waiting_on_resources = true
        React::State.get_state(self, :loaded_at)
      end

      def loaded_at(loaded_at)
        React::State.set_state(self, :loaded_at, loaded_at)
      end
            
    end
        
    before_mount do
      @uniq_id = ActiveRecord::Base._reactive_record_cache.get_next_while_loading_counter
      puts "time: #{Time.now} This is my uniq_id #{@uniq_id}"
    end
    
    after_mount do
      @waiting_on_resources = loading
    end
    
    after_update do
      @waiting_on_resources = loading
    end
    
    def render
      #puts "#{self}.render loading: #{loading} waiting_on_resources: #{waiting_on_resources}"
      props = element_props.dup
      props.merge!({
        "data-reactive_record_while_loading_container_id" => @uniq_id,
        "data-reactive_record_while_loading_loaded_children_count" => loaded_children.length
      })
      React.create_element(element_type, props) { loaded_children + loading_children }
    end
    
  end
  
end


module React
  
  class Element
        
    def while_loading(display = "", &loading_display_block)
      
      loaded_children = []
      loaded_children = block.call.dup if block
      
      loading_children = [display]
      loading_children = RenderingContext.build do |buffer|
        result = loading_display_block.call
        buffer << result.to_s if result.is_a? String
        buffer.dup
      end if loading_display_block 
      
      RenderingContext.replace(
        self,
        React.create_element(
          ReactiveRecord::WhileLoading, 
          loading: waiting_on_resources, 
          loading_children: loading_children, 
          loaded_children: loaded_children, 
          element_type: type, 
          element_props: properties) 
        )
    end
    
    def hide_while_loading
      while_loading
    end
    
  end
      
  module Component
    
    alias_method :original_component_did_mount, :component_did_mount
    
    def component_did_mount(*args)
      #puts "#{self}.component_did_mount"
      original_component_did_mount(*args)
      reactive_record_show_loading_or_unloading
    end
    
    alias_method :original_component_did_update, :component_did_update
    
    def component_did_update(*args)
      #puts "#{self}.component_did_update"
      original_component_did_update(*args)
      reactive_record_show_loading_or_unloading
    end
    
    def reactive_record_show_loading_or_unloading
      
      %x{
        /* needs to be redone with minimal jQuery as follows: 
        
          do I have a parent loading container including myself?
          
          if i am loading give my container the reactive_record_while_loading_is_loading class
          if i am not loading check my containers children, and set the loading status based on that
            
          the rest is css which just gets shoved in the DOM when the while load is mounted
          
            reactive_record_while_loading_is_loading.[data-reactive_record_while_loading_container_id=nnn] > :nth-child(-1n+%{loading_children_count}) {
              display: none 
            }
            reactive_record_while_loading_is_loaded.[data-reactive_record_while_loading_container_id=nnn] > :nth-child(1n+%{loaded_children_count+1}) {
              display: none 
            }
            
          during mount on the server we send this over to the server to build a preload style sheet:

            [data-reactive_record_while_loading_container_id=nnn] > :nth-child(1n+%{loaded_children_count+1}) {
              display: none 
            }
        */    
            
        var loading = (#{waiting_on_resources} == true)
        var node = #{@native}.getDOMNode()
        var while_loading_container
        
        if ($(node).hasClass('reactive_record_while_loading_container')) {
          while_loading_container = node
        } else {
          while_loading_container = $(node).closest('[data-reactive_record_while_loading_container_id]')[0]
        }

        if (while_loading_container) {
          var is_loading_class = 'reactive_record_'+$(while_loading_container).attr('data-reactive_record_while_loading_container_id')+'_is_loading'
        
          if (loading) {
            $(node).addClass(is_loading_class)
          } else {
            $(node).removeClass(is_loading_class)
          }
      
          var loaded_children_count = parseInt($(while_loading_container).attr('data-reactive_record_while_loading_loaded_children_count'))
          var children_loading = loading || $(while_loading_container).find('.'+is_loading_class).length > 0
          $($(while_loading_container).children().splice(0,loaded_children_count)).toggle(!children_loading)
          $($(while_loading_container).children().splice(loaded_children_count)).toggle(children_loading)
        }

      }
    end
  
  end
  


end

