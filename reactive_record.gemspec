$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "reactive_record/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "reactive_record"
  s.version     = ReactiveRecord::VERSION
  s.authors     = "Mitch VanDuyn"
  s.email       = ["mitch@catprint.com"]
  s.summary     = "Summary of ReactiveRecord."
  s.description = "Description of ReactiveRecord."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  
  # these options are in some other gems (i.e. opal-aasm) do we need them?
  #spec.bindir        = "exe"
  #spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  #spec.require_paths = ["lib"]
  
  s.test_files = Dir["spec-server/**/*"]

  s.add_dependency "rails", ">= 3.2.13"
  # s.add_dependency "jquery-rails"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'factory_girl_rails'
  s.add_dependency 'pry'
  s.add_dependency "opal-rails"
  s.add_dependency "opal-browser"
  s.add_dependency 'react-rails'
  s.add_dependency 'therubyracer'
end
