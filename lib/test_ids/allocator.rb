module TestIds
  class Allocator
    include Origen::Callbacks
    attr_reader :config

    def initialize
      @@allocators ||= 0
      @@allocators += 1
      if @@allocators > 1 && !TestIds.send(:testing?)
        fail 'TestIds::Allocators is a singleton, there can be only one'
      end
    end

    # Main method to inject generated bin and test numbers, the given
    # options instance is modified accordingly
    def allocate(instance, options)
      @changes_made = true
      clean(options)
      @callbacks = []
      name = extract_test_name(instance, options)
      name = "#{name}_#{options[:index]}" if options[:index]
      store['tests'][name] ||= {}
      t = store['tests'][name]
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
        t['softbin'] = nil if config.softbins.function?
        t['number'] = nil if config.numbers.function?
      end
      if options[:softbin]
        t['softbin'] = options[:softbin]
        store['manually_assigned']['softbin'][options[:softbin].to_s] = true
      elsif store['manually_assigned']['softbin'][t['softbin'].to_s]
        t['softbin'] = nil
        # Also regenerate the number as it could be a function of the softbin
        t['number'] = nil if config.numbers.function?
      end
      if options[:number]
        t['number'] = options[:number]
        store['manually_assigned']['number'][options[:number].to_s] = true
      elsif store['manually_assigned']['number'][t['number'].to_s]
        t['number'] = nil
      end
      # Otherwise generate the missing ones
      t['bin'] ||= allocate_bin
      t['softbin'] ||= allocate_softbin(t['bin'])
      t['number'] ||= allocate_number(t['bin'], t['softbin'])
      # Record that there has been a reference to the final numbers
      time = Time.now.to_f
      store['references']['bin'][t['bin'].to_s] = time if t['bin']
      store['references']['softbin'][t['softbin'].to_s] = time if t['softbin']
      store['references']['number'][t['number'].to_s] = time if t['number']
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
          @last_bin = s['pointers']['bin']
          @last_softbin = s['pointers']['softbin']
          @last_number = s['pointers']['number']
          s
        else
          { 'tests'             => {},
            'manually_assigned' => { 'bin' => {}, 'softbin' => {}, 'number' => {} },
            'pointers'          => { 'bin' => nil, 'softbin' => nil, 'number' => nil },
            'references'        => { 'bin' => {}, 'softbin' => {}, 'number' => {} }
          }
        end
      end
    end

    # Saves the current allocator state to the repository
    def save
      if file
        p = Pathname.new(file)
        FileUtils.mkdir_p(p.dirname)
        File.open(p, 'w') { |f| f.puts JSON.pretty_generate(store) }
      end
    end

    def on_origen_shutdown
      unless TestIds.send(:testing?)
        if config.repo && @changes_made && config.on_completion != :discard
          save
          publish if config.on_completion == :publish
        end
      end
    end

    # Returns a path to the file that will be used to store the allocated bins/numbers.
    # If config.repo has not been set it returns nil.
    def file
      if config.repo
        @file ||= begin
          if config.repo =~ /git/i
          else
            config.repo
          end
        end
      end
    end

    private

    # Returns the next available bin in the pool, if they have all been given out
    # the one that hasn't been used for the longest time will be given out
    def allocate_bin
      return nil if config.bins.empty?
      if store['pointers']['bin'] == 'done'
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
          store['pointers']['bin'] = 'done'
          reclaim_bin
        end
      end
    end

    def reclaim_bin
      store['references']['bin'] = store['references']['bin'].sort_by { |k, v| v }.to_h
      store['references']['bin'].first[0].to_i
    end

    def allocate_softbin(bin)
      return nil if config.softbins.empty?
      if config.softbins.algorithm
        algo = config.softbins.algorithm.to_s.downcase
        if algo.to_s =~ /^[b\dx]+$/
          number = algo.to_s
          bin = bin.to_s
          if number =~ /(b+)/
            max_bin_size = Regexp.last_match(1).size
            if bin.size > max_bin_size
              fail "Bin number (#{bin}) overflows the test number algorithm (#{algo})"
            end
            number = number.sub(/b+/, bin.rjust(max_bin_size, '0'))
          end
          if number =~ /(x+)/
            max_counter_size = Regexp.last_match(1).size
            refs = store['references']['softbin']
            i = 0
            possible = []
            proposal = number.sub(/x+/, i.to_s.rjust(max_counter_size, '0'))
            possible << proposal
            while refs[proposal] && i.to_s.size <= max_counter_size
              i += 1
              proposal = number.sub(/x+/, i.to_s.rjust(max_counter_size, '0'))
              possible << proposal
            end
            # Overflowed, need to go search for the oldest duplicate now
            if i.to_s.size > max_counter_size
              i = 0
              # Not the most efficient search algorithm, but this should be hit very rarely
              # and even then only to generate the bin the first time around
              p = refs.sort_by { |bin, last_used| last_used }.find do |bin, last_used|
                possible.include?(bin)
              end
              proposal = p[0]
            end
            number = proposal
          end
        else
          fail "Unknown softbin algorithm: #{algo}"
        end
        number.to_i
      elsif callback = config.softbins.callback
        callback.call(bin)
      else
        if store['pointers']['softbin'] == 'done'
          reclaim_softbin
        else
          b = config.softbins.include.next(@last_softbin)
          @last_softbin = nil
          while b && (store['manually_assigned']['softbin'][b.to_s] || config.softbins.exclude.include?(b))
            b = config.softbins.include.next
          end
          # When no softbin is returned it means we have used them all, all future generation
          # now switches to reclaim mode
          if b
            store['pointers']['softbin'] = b
          else
            store['pointers']['softbin'] = 'done'
            reclaim_softbin
          end
        end
      end
    end

    def reclaim_softbin
      store['references']['softbin'] = store['references']['softbin'].sort_by { |k, v| v }.to_h
      store['references']['softbin'].first[0].to_i
    end

    def allocate_number(bin, softbin)
      return nil if config.numbers.empty?
      if config.numbers.algorithm
        algo = config.numbers.algorithm.to_s.downcase
        if algo.to_s =~ /^[bs\dx]+$/
          number = algo.to_s
          bin = bin.to_s
          if number =~ /(b+)/
            max_bin_size = Regexp.last_match(1).size
            if bin.size > max_bin_size
              fail "Bin number (#{bin}) overflows the test number algorithm (#{algo})"
            end
            number = number.sub(/b+/, bin.rjust(max_bin_size, '0'))
          end
          softbin = softbin.to_s
          if number =~ /(s+)/
            max_softbin_size = Regexp.last_match(1).size
            if softbin.size > max_softbin_size
              fail "Softbin number (#{softbin}) overflows the test number algorithm (#{algo})"
            end
            number = number.sub(/s+/, softbin.rjust(max_bin_size, '0'))
          end
          if number =~ /(x+)/
            max_counter_size = Regexp.last_match(1).size
            refs = store['references']['number']
            i = 0
            possible = []
            proposal = number.sub(/x+/, i.to_s.rjust(max_counter_size, '0'))
            possible << proposal
            while refs[proposal] && i.to_s.size <= max_counter_size
              i += 1
              proposal = number.sub(/x+/, i.to_s.rjust(max_counter_size, '0'))
              possible << proposal
            end
            # Overflowed, need to go search for the oldest duplicate now
            if i.to_s.size > max_counter_size
              i = 0
              # Not the most efficient search algorithm, but this should be hit very rarely
              # and even then only to generate the bin the first time around
              p = refs.sort_by { |bin, last_used| last_used }.find do |bin, last_used|
                possible.include?(bin)
              end
              proposal = p[0]
            end
            number = proposal
          end
          number.to_i
        else
          fail "Unknown test number algorithm: #{algo}"
        end
      elsif callback = config.numbers.callback
        callback.call(bin, softbin)
      else
        if store['pointers']['number'] == 'done'
          reclaim_number
        else
          b = config.numbers.include.next(@last_number)
          @last_number = nil
          while b && (store['manually_assigned']['number'][b.to_s] || config.numbers.exclude.include?(b))
            b = config.numbers.include.next
          end
          # When no number is returned it means we have used them all, all future generation
          # now switches to reclaim mode
          if b
            store['pointers']['number'] = b
          else
            store['pointers']['number'] = 'done'
            reclaim_number
          end
        end
      end
    end

    def reclaim_number
      store['references']['number'] = store['references']['number'].sort_by { |k, v| v }.to_h
      store['references']['number'].first[0].to_i
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
