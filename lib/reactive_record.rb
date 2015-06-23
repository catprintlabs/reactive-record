
module ReactiveRecord
end

if RUBY_ENGINE == 'opal'
  require "reactive_record/cache"
  require "reactive_record/active_record"
  require "reactive_record/interval"
else
  require "opal"
  require "reactive_record/version"
  require "reactive_record/engine"
  require "reactive_record/react_rails_extensions"
  require "../../config/routes.rb"
  require "../../app/controllers/reactive_record/reactive_record_controller"

  Opal.append_path File.expand_path('../', __FILE__).untaint
  Opal.append_path File.expand_path('../../vendor', __FILE__).untaint
end