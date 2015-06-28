require 'react-rails'
require 'reactive_record/cache'
  
module React
  module Rails
    module ViewHelper

      alias_method :pre_reactive_record_react_component, :react_component

      def react_component(name, props = {}, render_options={}, &block)
        @reactive_record_cache ||= ReactiveRecord::Cache.new
        initial_while_loading_counter = @reactive_record_cache.while_loading_counter
        if render_options[:prerender]
          if render_options[:prerender].is_a? Hash 
            render_options[:prerender][:context] ||= {}
          elsif render_options[:prerender]
            render_options[:prerender] = {render_options[:prerender] => true, context: {}} 
          else
            render_options[:prerender] = {context: {}}
          end

          render_options[:prerender][:context].merge!({"ReactiveRecordCache" => @reactive_record_cache})
        end

        component_rendering = raw(pre_reactive_record_react_component(name, props, render_options, &block))
        initial_data_string = if render_options[:prerender]
          raw("<style>\n#{@reactive_record_cache.css_to_preload!}\n</style>\n"+javascript_tag(
            "if (typeof window.ReactiveRecordInitialWhileLoadingCounter == 'undefined') { window.ReactiveRecordInitialWhileLoadingCounter = #{initial_while_loading_counter} }\n" +
            "if (typeof window.ReactiveRecordInitialData == 'undefined') { window.ReactiveRecordInitialData = [] }\n" +
            "window.ReactiveRecordInitialData.push(#{@reactive_record_cache.to_json})"
           )).html_safe 
        else
          ""
        end
        component_rendering+initial_data_string
      end
    end
  end
end

