require 'react-rails'
require 'reactive_record/cache'
  
module React
  module Rails
    module ViewHelper

      alias_method :pre_reactive_record_react_component, :react_component

      def react_component(name, props = {}, render_options={}, &block)
        puts "I'm using the new react_component render_options = #{render_options}"
        @reactive_record_cache ||= ReactiveRecord::Cache.new
        if render_options[:prerender]
          if render_options[:prerender].is_a? Hash 
            render_options[:prerender][:context] ||= {}
          elsif render_options[:prerender]
            render_options[:prerender] = {render_options[:prerender] => true, context: {}} 
          else
            render_options[:prerender] = {context: {}}
          end

          render_options[:prerender][:context].merge!({"ReactiveRecordCache" => @reactive_record_cache})
          puts "render_options: #{render_options}"
        end

        component_rendering = pre_reactive_record_react_component(name, props, render_options, &block)
        component_rendering += "\n" +
          javascript_tag(
            "if (typeof window.ReactiveRecordInitialData == 'undefined') { window.ReactiveRecordInitialData = {} }\n" +
            "if (typeof jQuery != 'undefined') {jQuery.extend(true, window.ReactiveRecordInitialData, #{@reactive_record_cache.to_json})}"
          ) if render_options[:prerender]
        component_rendering
      end
    end
  end
end

