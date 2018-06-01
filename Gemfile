source 'http://artifactory.amd.com:8081/artifactory/rubygems'

# Only development dependencies (things your only plugin needs when running in its own workspace) should
# be listed here in the Gemfile
# This gem provides integration with https://coveralls.io/ to monitor
# your application's test coverage
gem 'coveralls', require: false
gem 'byebug', "~>8"  # Keep support for Ruby 2.0
gem 'origen_doc_helpers'
gem 'ripper-tags'
# Uncomment these if you want to use a visual debugger (e.g. Visual Studio Code) to debug your app
#gem 'ruby-debug-ide'
#gem 'debase'


gem 'origen_testers', git: 'ssh://git@stash.amd.com:7999/osdk/origen_testers.git'

gem 'origen', git: 'ssh://git@stash.amd.com:7999/osdk/origen.git'

# Specify your gem's runtime dependencies in test_ids.gemspec
# THIS LINE SHOULD BE LEFT AT THE END
gemspec
