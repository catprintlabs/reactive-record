if RUBY_ENGINE == 'opal'
  require "reactive_record/cache"
  require "reactive_record/active_record/aggregations"
  require "reactive_record/active_record/associations"
  require "reactive_record/active_record/reactive_record/base"
  require "reactive_record/active_record/reactive_record/collection"
  require "reactive_record/active_record/class_methods"
  require "reactive_record/active_record/instance_methods"
  require "reactive_record/active_record/base"
  require "reactive_record/interval"
  require "reactive_record/server_data_cache"
else
  require "opal"
  require "reactive_record/version"
  require "reactive_record/engine"
  require "reactive_record/cache"
  require "reactive_record/serializers"
  require "reactive_record/server_data_cache"
  module ActiveRecord::Associations::Builder
    class Association 
      def validate_options
        options.assert_valid_keys(self.class.valid_options + [:server_only])
      end
    end
  end
  begin  # can't figure out how to make this work when gem is released...
    #require "../../config/routes.rb"
    #require "../../app/controllers/reactive_record/reactive_record_controller"
  rescue
  end

  Opal.append_path File.expand_path('../', __FILE__).untaint
  Opal.append_path File.expand_path('../../vendor', __FILE__).untaint
end

module ReactiveRecord
end