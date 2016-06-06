if RUBY_ENGINE == 'opal'

  require "reactrb"
  require "reactive_record/active_record/error"
  require "reactive_record/server_data_cache"
  require "reactive_record/active_record/reactive_record/while_loading"
  require "reactive_record/active_record/reactive_record/isomorphic_base"
  require "reactive_record/active_record/aggregations"
  require "reactive_record/active_record/associations"
  require "reactive_record/active_record/reactive_record/base"
  require "reactive_record/active_record/reactive_record/collection"
  require "reactive_record/reactive_scope"
  require "reactive_record/active_record/class_methods"
  require "reactive_record/active_record/instance_methods"
  require "reactive_record/active_record/base"
  require "reactive_record/interval"

else

  require "opal"
  require "reactive_record/version"
  require "reactive_record/permissions"
  require "reactive_record/engine"
  require "reactive_record/server_data_cache"
  require "reactive_record/active_record/reactive_record/isomorphic_base"
  require "reactive_record/reactive_scope"
  require "reactive_record/serializers"
  require "reactive_record/pry"

  Opal.append_path File.expand_path('../', __FILE__).untaint
  Opal.append_path File.expand_path('../../vendor', __FILE__).untaint

end
