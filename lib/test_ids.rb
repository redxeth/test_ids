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
    # Allocates a number to the given test and returns a new hash containing
    # :bin, :softbin and :number keys.
    #
    # The given options hash is not modified by calling this method.
    #
    # Use the same arguments as you would normally pass to flow.test, the numbers
    # returned will be the same as would be injected into flow.test.
    def allocate(instance, options = {})
      opts = options.dup
      current_configuration.allocator.allocate(instance, opts)
      { bin: opts[:bin], bin_size: opts[:bin_size], softbin: opts[:softbin], softbin_size: opts[:softbin_size],
        number: opts[:number], number_size: opts[:number_size]
      }
    end

    def current_configuration
      configuration(@configuration_id)
    end

    def configuration(id)
      return @configuration[id] if @configuration && @configuration[id]
      fail('You have to create the configuration first before you can access it')
    end
    alias_method :config, :configuration

    def configure(id = nil, options = {})
      id, options = nil, id if id.is_a?(Hash)

      @configuration_id = id || options[:id] || :not_specified

      @configuration ||= {}

      return if @configuration[@configuration_id]

      @configuration[@configuration_id] = Configuration.new(@configuration_id)

      config = @configuration[@configuration_id]

      yield config

      config.validate!

      initialize_git
    end

    def configured?
      !!@configuration_id
    end

    def initialize_git
      @git_initialized ||= begin
        if repo
          @git = Git.new(local: git_database_dir, remote: repo)
          git.get_lock if publish?
        end
        true
      end
    end

    # Returns a full path to the database file for the given id, returns nil if
    # git storage has not been enabled
    def database_file(id)
      if repo
        if id == :not_specified
          f = 'store.json'
        else
          f = "store_#{id.to_s.downcase}.json"
        end
        "#{git_database_dir}/#{f}"
      end
    end

    def git_database_dir
      @git_database_dir ||= begin
        d = "#{Origen.app.imports_directory}/test_ids/#{Pathname.new(repo).basename}"
        FileUtils.mkdir_p(d)
        d
      end
    end

    def git
      @git
    end

    def repo=(val)
      return if @repo && @repo == val
      if @repo && @repo != val
        fail 'You can only use a single test ids repository per program generation run, one per application is recommended'
      end
      if @configuration
        fail 'TestIds.repo must be set before creating the first configuration'
      end
      @repo = val
    end

    def repo
      @repo
    end

    def publish?
      @publish ? @publish == :save : true
    end

    def publish=(val)
      return if @publish && publish? == val
      if @publish && publish? != val
        fail 'You can only use a single setting for publish per program generation run'
      end
      if @configuration
        fail 'TestIds.publish must be set before creating the first configuration'
      end
      unless [true, false].include?(val)
        fail 'TestIds.publish must be set to either true or false'
      end
      @publish = val ? :save : :dont_save
    end

    private

    def on_origen_shutdown
      if !testing? && @configuration
        if repo
          @configuration.each do |id, config|
            config.allocator.save
          end
          git.publish if publish?
        end
      end
    end

    # For testing, clears all instances including the configuration
    def reset
      @git = nil
      @configuration = nil
    end

    def clear_configuration_id
      @configuration_id = nil
    end

    def testing=(val)
      @testing = val
    end

    def testing?
      !!@testing
    end
  end
end
