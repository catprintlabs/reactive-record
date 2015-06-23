begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

APP_RAKEFILE = File.expand_path("../spec/dummy/Rakefile", __FILE__)
load 'rails/tasks/engine.rake'
Bundler::GemHelper.install_tasks
Dir[File.join(File.dirname(__FILE__), 'tasks/**/*.rake')].each {|f| load f }
require 'rspec/core'
require 'rspec/core/rake_task'
desc "Run all specs in spec directory (excluding plugin specs)"
RSpec::Core::RakeTask.new(:spec => 'app:db:test:prepare') 

require 'opal/rspec/rake_task'
require 'bundler'
Bundler.require

# Add our opal/ directory to the load path
#Opal.append_path File.expand_path('../lib', __FILE__)

Opal::RSpec::RakeTask.new(:spec_opal) do |s|
  s.sprockets.paths.tap { s.sprockets.clear_paths }[0..-2].each { |path| s.sprockets.append_path path}
  s.main = 'sprockets_runner'
  s.append_path 'spec-opal'
end

task :default => [:spec, :spec_opal]
