module TestIds
  class Allocator
    attr_reader :config

    # Main method to inject generated bin and test numbers, the given
    # options instance is modified accordingly
    def allocate(instance, options)
      clean(options)
      @callbacks = []
      name = extract_test_name(instance, options)
      name = "#{name}_#{options[:index]}" if options[:index]
      store['tests'][name] ||= {}
      t = store['tests'][name]
      t['referenced'] = Time.now.utc
      # If the user has supplied any of these, that number should be used
      # and reserved so that it is not automatically generated later
      if options[:bin]
        t['bin'] = options[:bin]
        store['manually_assigned']['bin'][options[:bin].to_s] = true
      # Regenerate the bin if the original allocation has since been applied
      # manually elsewhere
      elsif store['manually_assigned']['bin'][t['bin'].to_s]
        t['bin'] = nil
        # Also regenerate these as they could be a function of the bin
        t['softbin'] = nil
        t['number'] = nil
      end
      t['softbin'] = options[:softbin] if options[:softbin]
      t['number'] = options[:number] if options[:number]
      # Otherwise generate the missing ones
      t['bin'] ||= allocate_bin
      t['softbin'] ||= allocate_softbin
      t['number'] ||= allocate_number
      # Update the supplied options hash that will be forwarded to the
      # program generator
      options[:bin] = t['bin']
      options[:softbin] = t['softbin']
      options[:number] = t['number']
      options
    end

    def config
      TestIds.config
    end

    def store
      @store ||= begin
        if config.repo && File.exist?(config.repo)
          s = JSON.load(File.read(config.repo))
          @last_bin = s['pointers']['bin'] if s['pointers']['bin']
          s
        else
          { 'manually_assigned' => { 'bin' => {}, 'softbin' => {}, 'number' => {} },
            'pointers'          => { 'bin' => nil, 'softbin' => nil, 'number' => nil,
                                     'bin_ref' => nil, 'softbin_ref' => nil, 'number_ref' => nil },
            'tests'             => {}
          }
        end
      end
    end

    # Saves the current allocator state to the repository
    def save
      if config.repo
        p = Pathname.new(config.repo)
        FileUtils.mkdir_p(p.dirname)
        sort_tests_by_reference_time
        File.open(p, 'w') { |f| f.puts JSON.pretty_generate(store) }
      end
    end

    private

    def sort_tests_by_reference_time
      store['tests'] = store['tests'].sort_by { |k, v| v['referenced'] }.to_h
    end

    # Returns the next available bin in the pool, if they have all been given out
    # the one that hasn't been used for the longest time will be given out
    def allocate_bin
      if store['pointers']['bin_ref']
        reclaim_bin
      else
        b = config.bins.include.next(@last_bin)
        @last_bin = nil
        while b && (store['manually_assigned']['bin'][b.to_s] || config.bins.exclude.include?(b))
          b = config.bins.include.next
        end
        # When no bin is returned it means we have used them all, all future generation
        # now switches to reclaim mode
        if b
          store['pointers']['bin'] = b
        else
          reclaim_bin
        end
      end
    end

    def reclaim_bin
      sort_tests_by_reference_time
      if ref = store['pointers']['bin_ref']
        t = store['tests'].find do |name, test|
          test['referenced'] > ref
        end
        store['pointers']['bin_ref'] = t[1]['referenced']
        t[1]['bin']
      else
        store['pointers']['bin_ref'] = store['tests'].first[1]['referenced']
        store['tests'].first[1]['bin']
      end
    end

    def allocate_softbin
    end

    def allocate_number
    end

    def extract_test_name(instance, options)
      name = options[:name]
      unless name
        if instance.is_a?(String)
          name = instance
        elsif instance.is_a?(Symbol)
          name = instance.to_s
        elsif instance.is_a?(Hash)
          h = instance.with_indifferent_access
          name = h[:name] || h[:tname] || h[:testname] || h[:test_name]
        elsif instance.respond_to?(:name)
          name = instance.name
        else
          fail "Could not get the test name from #{instance}"
        end
      end
      name.to_s.downcase
    end

    # Cleans the given options hash by consolidating any bin/test numbers
    # to the following option keys:
    #
    # * :bin
    # * :softbin
    # * :number
    # * :name
    # * :index
    def clean(options)
      options[:softbin] ||= options.delete(:sbin) || options.delete(:soft_bin)
      options[:number] ||= options.delete(:test_number) || options.delete(:tnum) ||
                           options.delete(:testnumber)
      options[:name] ||= options.delete(:tname) || options.delete(:testname) ||
                         options.delete(:test_name)
      options[:index] ||= options.delete(:ix)
    end
  end
end
