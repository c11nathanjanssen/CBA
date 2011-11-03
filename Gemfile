source 'http://rubygems.org'

gem 'simplecov', :require => false, :group => :test #, '>= 0.4.0'

gem "rails" #, "~> 3.1.0" # prev was rc8

# Rails 3.1 - Asset Pipeline
group :assets do
  gem 'sass-rails', "~> 3.1.0.rc"
  gem 'coffee-script'
  gem 'uglifier'
  gem 'json'
  gem 'jquery-rails'
  gem 'therubyracer', :platforms => :ruby
  gem 'execjs'
  gem 'sprockets', '~> 2.0.0.beta.12'
end

# Bundle gems needed for Mongoid
gem "mongoid", :git => 'git://github.com/mongoid/mongoid.git'
gem "bson_ext"  #"1.1.5"

# Bundle gem needed for Devise and cancan
gem "devise" #, :git => 'git://github.com/iboard/devise.git' #:path => "/Users/aa/Development/R31/devise" #'1.2.rc2' #, "~>1.4.0" # ,"1.1.7"
gem "cancan"
gem "omniauth", ">= 0.2.6"

gem "googlecharts"

# we need some stuff too (tbb)
gem 'simple_form'

group :production do
  gem 'unicorn'
end

# connection gems
gem 'json'
gem 'geocoder'
gem 'httparty'
gem "nokogiri", "~> 1.5.0"
gem 'feedzirra' 
gem 'sax-machine'

# Bundle gem needed for paperclip and attachments
# gem "paperclip" dependency of mongoid-paperclip
gem "mongoid-paperclip", :require => 'mongoid_paperclip'

# MongoID Extensions and extras
gem 'mongoid-tree', :require => 'mongoid/tree'
gem 'mongoid_fulltext'
gem 'mongoid_taggable'
gem 'mongoid_spacial' # For GeoIndex
gem 'mongoid_session_store'

# Bundle gems for views
gem "haml"
gem "will_paginate", "3.0.pre4"
gem 'escape_utils'
gem "RedCloth", "4.2.5" #"4.2.4.pre3 doesn't work with ruby 1.9.2-p180
gem 'stamp'

# a scheduling gem
gem 'whenever', :require => false

# Gems by iboard.cc <andreas@altendorfer.at>
gem "jsort", "~> 0.0.1"
gem 'progress_upload_field', '~> 0.0.1'
gem "capistrano"
gem "coffeebeans"

# Markdown
# do "easy_install pygments" on your system
gem 'redcarpet'
gem 'albino'

# Bundle gems for development
group :development do
  gem "nifty-generators"
  gem "rails-erd"
  gem 'rdoc'
  gem "rails3-generators"
  gem 'unicorn'
  gem 'yard'
end

# Testing
group :development, :test do
  gem 'jasmine' #, '1.0.2.1'
  gem 'headless', '0.1.0'  
  gem 'rspec', '2.6.0'
  gem 'rspec-rails', '2.6.1'
  gem 'faker'
  gem 'json_pure'
  gem 'capybara'
  gem 'database_cleaner'
  gem 'cucumber-rails'
  gem 'cucumber'
  gem 'rspec', '2.6.0'
  gem 'rspec-rails', '2.6.1'
  gem 'spork', '0.9.0.rc9'
  gem 'spork-testunit'
  gem 'launchy'
  gem 'ZenTest', '4.5.0'
  gem 'autotest'
  gem 'autotest-rails'
  gem 'ruby-growl'
  gem 'autotest-growl'
  gem "mocha"
  gem "fabrication"
  gem "gherkin"
  gem 'test-unit'
#  gem "autotest-fsevent", :platforms => :ruby
  gem 'webmock', ">= 1.7.0"
  gem 'vcr'
  gem 'syntax'
  gem "nifty-generators"
  gem "rails-erd"
  gem 'rdoc'
  gem 'unicorn'
  gem 'yard'
  gem 'rails3-generators'
  gem "haml-rails"
end

# !! THE GRAVEYARD !!
#gem "omniauth", :git => 'git://github.com/intridea/omniauth.git' # maybe we need this latest version instead of the gem -tbb
#gem "govkit" #, :git => 'git://github.com/tbbooher/govkit.git'
#gem "nytimes-congress"
#gem "geokit"
#gem 'drumbone'
#gem "omniauth" "0.2.6"
#gem 'omniauth', '>= 0.2.6'
#gem "heroku"
#gem 'webmock'
#gem 'vcr'
#gem 'factory_girl'
#gem 'factory_girl_rails'
#gem 'ym4r'
#gem "formtastic"
#gem "ruby-debug-base19", :git => "git://github.com/JetBrains/ruby-debug-base19.git"
#gem 'factory_girl_rails', "1.1.0"
#gem 'mongoid_counter_cache'