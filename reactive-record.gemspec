$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "reactive_record/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|

  s.name        = "reactive-record"
  s.version     = ReactiveRecord::VERSION
  s.authors     = "Mitch VanDuyn"
  s.email       = ["mitch@catprint.com"]
  s.summary     = %q{Access active-record models inside Reactrb components.}
  s.description = %q{Access active-record models inside Reactrb components.  Model data is calculated during pre-rerendering, and then dynamically loaded as components update.}

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]

  s.test_files = Dir["spec-server/**/*"]

  s.add_dependency "rails", ">= 3.2.13"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'pry'

  s.add_dependency "opal-rails"
  s.add_dependency "opal-browser"
  s.add_dependency 'react-rails'
  s.add_dependency 'therubyracer'
  s.add_dependency 'reactrb'

end
