if RUBY_ENGINE == 'opal'
  require "reactive_record/cache"
  require "reactive_record/active_record"
  require "reactive_record/interval"
else
  require "opal"
  require "reactive_record/version"
  require "reactive_record/engine"
  require "reactive_record/cache"
  require "reactive_record/serializers"
  require "active_record"
  module ActiveRecord::Associations::Builder
    class Association #:nodoc:
      def validate_options
        options.assert_valid_keys(valid_options + [:server_only])
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
