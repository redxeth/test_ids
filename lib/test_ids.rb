require 'origen'
require_relative '../config/application.rb'
require 'origen_testers'

module TestIds
  # THIS FILE SHOULD ONLY BE USED TO LOAD RUNTIME DEPENDENCIES
  # If this plugin has any development dependencies (e.g. dummy DUT or other models that are only used
  # for testing), then these should be loaded from config/boot.rb
  require 'test_ids/allocator'
  require 'test_ids/bin_array'
  require 'test_ids/configuration'
  require 'test_ids/git'
  require 'test_ids/shutdown_handler'
  require 'test_ids/origen/origen'
  require 'test_ids/origen_testers/flow'

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
      inject_flow_id(opts)
      current_configuration.allocator.allocate(instance, opts)
      { bin: opts[:bin], bin_size: opts[:bin_size], softbin: opts[:softbin], softbin_size: opts[:softbin_size],
        number: opts[:number], number_size: opts[:number_size]
      }
    end

    # Similar to allocate, but allocates a test number only, i.e. no bin or softbin
    def allocate_number(instance, options = {})
      opts = options.dup
      opts[:bin] = :none
      opts[:softbin] = :none
      inject_flow_id(opts)
      current_configuration.allocator.allocate(instance, opts)
      {
        number: opts[:number], number_size: opts[:number_size]
      }
    end

    # Similar to allocate, but allocates a softbin number only, i.e. no bin or test number
    def allocate_softbin(instance, options = {})
      opts = options.dup
      opts[:bin] = :none
      opts[:number] = :none
      inject_flow_id(opts)
      current_configuration.allocator.allocate(instance, opts)
      {
        softbin: opts[:softbin], softbin_size: opts[:softbin_size]
      }
    end
    alias_method :allocate_soft_bin, :allocate_softbin

    # Similar to allocate, but allocates a bin number only, i.e. no softbin or test number
    def allocate_bin(instance, options = {})
      opts = options.dup
      opts[:softbin] = :none
      opts[:number] = :none
      inject_flow_id(opts)
      current_configuration.allocator.allocate(instance, opts)
      {
        softbin: opts[:bin], softbin_size: opts[:bin_size]
      }
    end

    # @api private
    def inject_flow_id(options)
      if Origen.interface_loaded?
        flow = Origen.interface.flow
        options[:test_ids_flow_id] = flow.try(:top_level).try(:id) || flow.id
      end
    end

    # Load an existing allocator, which will be loaded with a configuration based on what has
    # been serialized into the database if present, otherwise it will have an empty configuration.
    # Returns nil if the given database can not be found.
    # @api internal
    def load_allocator(id = nil)
      f = TestIds.database_file(id)
      if File.exist?(f)
        a = Configuration.new(id).allocator
        a.load_configuration_from_store
        a
      end
    end

    def current_configuration
      configuration(@configuration_id)
    end

    def configuration(id, fail_on_missing = true)
      return @configuration[id] if @configuration && @configuration[id]
      if fail_on_missing
        fail('You have to create the configuration first before you can access it')
      end
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

    # Switch the current configuration to the given ID
    def config=(id)
      unless @configuration[id]
        fail "The TestIds configuration '#{id}' has not been defined yet!"
      end
      @configuration_id = id
    end

    # Return an Array of configuration IDs
    def configs
      @configuration.ids
    end

    def bin_config=(id)
      @bin_config = id
    end

    def bin_config
      @bin_config ? configuration(@bin_config, false) : current_configuration
    end

    def softbin_config=(id)
      @softbin_config = id
    end

    def softbin_config
      @softbin_config ? configuration(@softbin_config, false) : current_configuration
    end

    def number_config=(id)
      @number_config = id
    end

    def number_config
      @number_config ? configuration(@number_config, false) : current_configuration
    end

    # Temporarily switches the current configuration to the given ID for the
    # duration of the given block, then switches it back to what it was
    def with_config(id)
      orig = @configuration_id
      @configuration_id = id
      yield
      @configuration_id = orig
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
        if id == :not_specified || !id || id == ''
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

    def next_in_range(range, options)
      current_configuration.allocator.next_in_range(range, options)
    end

    ## When set to true, all numbers generated will be checked to see if they comply
    ## with the current configuration, and if not they will be re-assigned based on the
    ## current configuration
    # def reallocate_non_compliant
    #  @reallocate_non_compliant
    # end

    ## When set to true, all numbers generated will be checked to see if they comply
    ## with the current configuration, and if not they will be re-assigned based on the
    ## current configuration
    # def reallocate_non_compliant=(val)
    #  @reallocate_non_compliant = val
    # end

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
      @bin_config = nil
      @softbin_config = nil
      @number_config = nil
    end

    def testing=(val)
      @testing = val
    end

    def testing?
      !!@testing
    end
  end
end
