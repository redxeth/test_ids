require 'origen'
require_relative '../config/application.rb'
require 'origen_testers'

module TestIds
  # THIS FILE SHOULD ONLY BE USED TO LOAD RUNTIME DEPENDENCIES
  # If this plugin has any development dependencies (e.g. dummy DUT or other models that are only used
  # for testing), then these should be loaded from config/boot.rb

  # Example of how to explicitly require a file
  # require "test_ids/my_file"

  # Load all files in the lib/test_ids directory.
  # Note that there is no problem from requiring a file twice (Ruby will ignore
  # the second require), so if you have a file that must be required first, then
  # explicitly require it up above and then let this take care of the rest.
  Dir.glob("#{File.dirname(__FILE__)}/test_ids/**/*.rb").sort.each do |file|
    require file
  end

  class <<self
    def store
      unless @configuration
        fail 'The test ID generator has to be configured before you can start using it'
      end
      @store ||= Store.new
    end

    def allocator
      unless @configuration
        fail 'The test ID generator has to be configured before you can start using it'
      end
      @allocator ||= Allocator.new
    end

    def configuration
      if block_given?
        configure do |config|
          yield config
        end
      else
        @configuration ||
          fail('You have to create the configuration first before you can access it')
      end
    end
    alias_method :config, :configuration

    def configure
      if @configuration
        fail "You can't modify an existing test IDs configuration"
      end
      @configuration = Configuration.new
      yield @configuration
      @configuration.validate!
      allocator.prepare
    end

    private

    # For testing, clears all instances including the configuration
    def reset
      @git = nil
      @store = nil
      @allocator = nil
      @configuration = nil
    end

    def testing=(val)
      @testing = val
    end

    def testing?
      !!@testing
    end
  end
end
