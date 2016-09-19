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

      # Note: TestIds will keep a hash of stores
      #
      @store = {} if @store.nil?               # Empty has if this is first store object
      
      # Return existing or create new store object in store hash
      @store[config_id] ||= Store.new(config_id)
    end

    def allocator
      unless @configuration
        fail 'The test ID generator has to be configured before you can start using it'
      end

      # Note: TestIds will keep a hash of allocators
      #
      @allocator = {} if @allocator.nil?       # Empty has if this is first allocator object

      # Return existing or create new store object in allocator hash
      @allocator[config_id] ||= Allocator.new(config_id)     
    end

    # Returns the id of the current configuration in-use, use this to access store and allocator
    def config_id
      current_configuration.id
    end
    
    def configuration
      if block_given?
        configure do |config|
          yield config
        end
      else
        @configuration[config_id] ||
          fail('You have to create the configuration first before you can access it')
      end
    end
    alias_method :config, :configuration

    def configure(options = {})
      # Don't force 'id' usage
      _id = options[:id] || :not_specified

      # Create empty hash if first configuration
      @configuration = {} if @configuration.nil?

      # Note: TestIds will keep a hash of configurations with the 'id' as the key
      #
      # If this configuration doesn't exist, create new configuration (hash item)
      # Else, shoot user a warning and set configuration as current (but don't allow bin/tnum changes)
      if @configuration[_id].nil?
        @configuration[_id] ||= Configuration.new(_id)
        set_current_configuration(_id)
      else
        # Configuration already exists, skip re-configure, but set configuration to current
        set_current_configuration(_id)
        return      
      end
      yield @configuration[_id]
      @configuration[_id].validate!
      allocator.prepare
    end

    def current_configuration
      unless @configuration
        fail 'The test ID generator has to be configured before you can start using it'
      end
      @current_configuration
    end

    def set_current_configuration(_id)
      unless @configuration
        fail 'The test ID generator has to be configured before you can start using it'
      end
      if @configuration[_id].nil?
        fail "Configuration '#{_id}' does not exist"
      end
      @current_configuration = @configuration[_id]
    end
    
    def empty?
      @configuration.nil?
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
