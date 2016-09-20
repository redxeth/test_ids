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
          git.get_lock if on_completion == :save
        end
        true
      end
    end

    # Returns a full path to the database file for the given id, returns nil if
    # git storage has not been enabled
    def database_file(id)
      if repo && on_completion == :save
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

    # Returns what should be done with the database for the given configuration
    # at the end, :save (the default) or :discard.
    #
    # If a repo has not been specified, then this attribute has no effect and the
    # data will always be discarded.
    def on_completion
      @on_completion || :save
    end

    def on_completion=(val)
      return if @on_completion && @on_completion == val
      if @on_completion && @on_completion != val
        fail 'You can only use a single setting for on_completion per program generation run'
      end
      if @configuration
        fail 'TestIds.on_completion must be set before creating the first configuration'
      end
      unless %w(save discard).include?(val.to_s)
        fail 'on_completion must be set to either :save or :discard'
      end
      @on_completion = val.to_sym
    end

    private

    def on_origen_shutdown
      unless testing?
        if repo && on_completion == :save
          @configuration.each do |id, config|
            config.allocator.save
          end
          git.publish
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
