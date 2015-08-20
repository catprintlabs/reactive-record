module ReactiveRecord

  # will repeatedly execute the block until it is loaded
  # immediately returns a promise that will resolve once the block is loaded

  def self.load(&block)
    promise = Promise.new
    @load_stack ||= []
    @load_stack << @loads_pending
    @loads_pending = nil
    result = block.call
    if @loads_pending
      @blocks_to_load ||= []
      @blocks_to_load << [promise, block]
    else
      promise.resolve result
    end
    @loads_pending = @load_stack.pop
    promise
  end

  def self.loads_pending!
    @loads_pending = true
  end

  def self.run_blocks_to_load
    if @blocks_to_load
      blocks_to_load = @blocks_to_load
      @blocks_to_load = []
      blocks_to_load.each do |promise_and_block|
        @loads_pending = nil
        result = promise_and_block.last.call
        if @loads_pending
          @blocks_to_load << promise_and_block
        else
          promise_and_block.first.resolve result
        end
      end
    end
  rescue Exception => e
    message = "ReactiveRecord.run_blocks_to_load exception raised: #{e}"
    `console.error(#{message})`
  end

  
  # Adds while_loading feature to React
  # to use attach a .while_loading handler to any element for example
  # div { "displayed if everything is loaded" }.while_loading { "displayed while I'm loading" }
  # the contents of the div will be switched (using jQuery.show/hide) depending on the state of contents of the first block
  
  # To notify React that something is loading use React::WhileLoading.loading!
  # once everything is loaded then do React::WhileLoading.loaded_at message (typically a time stamp just for debug purposes)
  
  class WhileLoading
    
    include React::IsomorphicHelpers
        
    before_first_mount do 
      @css_to_preload = ""
      @while_loading_counter = 0
    end
    
    def get_next_while_loading_counter
      @while_loading_counter += 1
    end
    
    def preload_css(css)
      @css_to_preload << css << "\n"
    end
    
    prerender_footer do
      "<style>\n#{@css_to_preload}\n</style>".tap { @css_to_preload = ""}
    end
    
    if RUBY_ENGINE == 'opal'
      
      # I DONT THINK WE USE opal-jquery in this module anymore - require 'opal-jquery' if opal_client?
    
      include React::Component
    
      required_param :loading
      required_param :loaded_children
      required_param :loading_children
      required_param :element_type
      required_param :element_props
      optional_param :display, default: ""
     
      class << self
        
        def loading?
          @is_loading
        end
            
        def loading!
          React::RenderingContext.waiting_on_resources = true
          React::State.get_state(self, :loaded_at)
          @is_loading = true
        end

        def loaded_at(loaded_at)
          React::State.set_state(self, :loaded_at, loaded_at)
          @is_loading = false
        end
     
        def add_style_sheet
          @style_sheet ||= %x{
            $('<style type="text/css">'+
              '  .reactive_record_is_loading > .reactive_record_show_when_loaded { display: none; }'+
              '  .reactive_record_is_loaded > .reactive_record_show_while_loading { display: none; }'+
              '</style>').appendTo("head") 
          } 
        end
          
      end
            
      before_mount do
        @uniq_id = WhileLoading.get_next_while_loading_counter
        WhileLoading.preload_css(
          ".reactive_record_while_loading_container_#{@uniq_id} > :nth-child(1n+#{loaded_children.count+1}) {\n"+
          "  display: none;\n"+ 
          "}\n"
        )
      end
    
      after_mount do
        @waiting_on_resources = loading
        WhileLoading.add_style_sheet
        %x{
          var node = #{@native}.getDOMNode();
          $(node).children(':nth-child(-1n+'+#{loaded_children.count}+')').addClass('reactive_record_show_when_loaded');
          $(node).children(':nth-child(1n+'+#{loaded_children.count+1}+')').addClass('reactive_record_show_while_loading');
        }
      end
    
      after_update do
        @waiting_on_resources = loading
      end
    
      def render
        props = element_props.dup
        classes = [props[:class], props[:className], "reactive_record_while_loading_container_#{@uniq_id}"].compact.join(" ")
        props.merge!({
          "data-reactive_record_while_loading_container_id" => @uniq_id,
          "data-reactive_record_enclosing_while_loading_container_id" => @uniq_id,
          class: classes
        })
        React.create_element(element_type, props) { loaded_children + loading_children }
      end
      
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
      original_component_did_mount(*args)
      reactive_record_link_to_enclosing_while_loading_container
      reactive_record_link_set_while_loading_container_class
    end
    
    alias_method :original_component_did_update, :component_did_update
    
    def component_did_update(*args)
      original_component_did_update(*args)
      reactive_record_link_set_while_loading_container_class
    end
    
    def reactive_record_link_to_enclosing_while_loading_container 
      # Call after any component mounts - attaches the containers loading id to this component
      # Fyi, the while_loading container is responsible for setting its own link to itself

      %x{
        var node = #{@native}.getDOMNode();
        if (!$(node).is('[data-reactive_record_enclosing_while_loading_container_id]')) {
          var while_loading_container = $(node).closest('[data-reactive_record_while_loading_container_id]')
          if (while_loading_container.length > 0) {
            var container_id = $(while_loading_container).attr('data-reactive_record_while_loading_container_id')
            $(node).attr('data-reactive_record_enclosing_while_loading_container_id', container_id)
          }
        }
      }

    end
    
    def reactive_record_link_set_while_loading_container_class
      
      %x{
        
        var node = #{@native}.getDOMNode();
        var while_loading_container_id = $(node).attr('data-reactive_record_enclosing_while_loading_container_id');
        if (while_loading_container_id) {
          var while_loading_container = $('[data-reactive_record_while_loading_container_id='+while_loading_container_id+']');
          var loading = (#{waiting_on_resources} == true);
          if (loading) {
            $(node).addClass('reactive_record_is_loading');
            $(node).removeClass('reactive_record_is_loaded');
            $(while_loading_container).addClass('reactive_record_is_loading');
            $(while_loading_container).removeClass('reactive_record_is_loaded');
            
          } else if (!$(node).hasClass('reactive_record_is_loaded')) {
            
            if (!$(node).attr('data-reactive_record_while_loading_container_id')) {
              $(node).removeClass('reactive_record_is_loading');
              $(node).addClass('reactive_record_is_loaded');  
            }
            if (!$(while_loading_container).hasClass('reactive_record_is_loaded')) {
              var loading_children = $(while_loading_container).
                find('[data-reactive_record_enclosing_while_loading_container_id='+while_loading_container_id+'].reactive_record_is_loading')
              if (loading_children.length == 0) {
                $(while_loading_container).removeClass('reactive_record_is_loading')
                $(while_loading_container).addClass('reactive_record_is_loaded')
              } 
            }
               
          }
          
        }
      } 
      
    end
    
  end if RUBY_ENGINE == 'opal'

end