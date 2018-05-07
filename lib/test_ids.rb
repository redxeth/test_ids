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
   # Initialize
   def initialize
     @softbin_ranges ||= []
     @given_softbins_by_range ||= {}
   end

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

   # Allocates a softbin number from the range specified in the test flow
   # It also keeps a track of the last softbin given out from a particular range
   # and uses that to increment the pointers accordingly.
   # If a numeric number is passed to the softbin, it uses that number.
   # The configuration for the TestId plugin needs to pass in the bin number and the options from the test flow
   # For this method to work as intended.
   def next_in_range(bin, options)
     initialize
     unless options.nil?
       if options[:softbin].is_a?(Range)
         orig_options = options.dup
         if @softbin_ranges.include? orig_options[:softbin]
           previously_given_softbin = @given_softbins_by_range[:"#{orig_options[:softbin]}"]
           temp = @softbin_ranges.index(orig_options[:softbin])
           @pointer = previously_given_softbin.to_i - @softbin_ranges[temp].min
           if previously_given_softbin == orig_options[:softbin].to_a[@pointer].to_s
             @pointer += 1
             given_softbin = orig_options[:softbin].to_a[@pointer]
           else
             given_softbin = orig_options[:softbin].to_a[@pointer]
           end
           @given_softbins_by_range.merge!("#{orig_options[:softbin]}": "#{orig_options[:softbin].to_a[@pointer]}")
         else
           @pointer = 0
           @softbin_ranges << orig_options[:softbin]
           given_softbin = orig_options[:softbin].to_a[@pointer]
           @given_softbins_by_range.merge!("#{orig_options[:softbin]}": "#{orig_options[:softbin].to_a[@pointer]}")
         end
         options[:softbin] = given_softbin
       else
         options[:softbin] = options[:softbin]
       end
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

   ## Can be called in place of TestIDs.configure to change the configuration from
   ## the one that was originally supplied.
   ## It is expected that this is mainly useful for testing purposes only.
   # def reconfigure(id = nil, options = {}, &block)
   #  id, options = nil, id if id.is_a?(Hash)

   #  @configuration_id = id || options[:id] || :not_specified

   #  @configuration ||= {}

   #  old = @configuration[@configuration_id]
   #  new = Configuration.new(@configuration_id)
   #  new.instance_variable_set('@allocator', old.allocator)
   #  new.allocator.instance_variable_set('@config', new)
   #  @configuration[@configuration_id] =  new

   #  yield new

   #  new.validate!
   # end

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
   end

   def testing=(val)
     @testing = val
   end

   def testing?
     !!@testing
   end
  end
end
