module TestIds
  # The allocator is responsible for assigning new numbers and keeping a record of
  # existing assignments.
  #
  # There is one allocator instance per configuration, and each has its own database
  # file.
  class Allocator
    STORE_FORMAT_REVISION = 1

    attr_reader :config

    def initialize(configuration)
      @config = configuration
    end

    # Main method to inject generated bin and test numbers, the given
    # options instance is modified accordingly
    def allocate(instance, options)
      orig_options = options.dup
      clean(options)
      @callbacks = []
      name = extract_test_name(instance, options)
      name = "#{name}_#{options[:index]}" if options[:index]

      # First work out the test ID to be used for each of the numbers, and how many numbers
      # should be reserved
      if (options[:bin].is_a?(Symbol) || options[:bin].is_a?(String)) && options[:bin] != :none
        bin_id = options[:bin].to_s
      else
        bin_id = name
      end
      if (options[:softbin].is_a?(Symbol) || options[:softbin].is_a?(String)) && options[:softbin] != :none
        softbin_id = options[:softbin].to_s
      else
        softbin_id = name
      end
      if (options[:number].is_a?(Symbol) || options[:number].is_a?(String)) && options[:number] != :none
        number_id = options[:number].to_s
      else
        number_id = name
      end

      bin_size = options[:bin_size] || config.bins.size
      softbin_size = options[:softbin_size] || config.softbins.size
      number_size = options[:number_size] || config.numbers.size

      bin = store['assigned']['bin'][bin_id] ||= {}
      softbin = store['assigned']['softbin'][softbin_id] ||= {}
      number = store['assigned']['number'][number_id] ||= {}

      # If the user has supplied any of these, that number should be used
      # and reserved so that it is not automatically generated later
      if options[:bin] && options[:bin].is_a?(Numeric)
        bin['number'] = options[:bin]
        bin['size'] = bin_size
        store['manually_assigned']['bin'][options[:bin].to_s] = true
      # Regenerate the bin if the original allocation has since been applied
      # manually elsewhere
      elsif store['manually_assigned']['bin'][bin['number'].to_s]
        bin['number'] = nil
        bin['size'] = nil
        # Also regenerate these as they could be a function of the bin
        if config.softbins.function?
          softbin['number'] = nil
          softbin['size'] = nil
        end
        if config.numbers.function?
          number['number'] = nil
          number['size'] = nil
        end
      end
      if options[:softbin] && options[:softbin].is_a?(Numeric)
        softbin['number'] = options[:softbin]
        softbin['size'] = softbin_size
        store['manually_assigned']['softbin'][options[:softbin].to_s] = true
      elsif store['manually_assigned']['softbin'][softbin['number'].to_s]
        softbin['number'] = nil
        softbin['size'] = nil
        # Also regenerate the number as it could be a function of the softbin
        if config.numbers.function?
          number['number'] = nil
          number['size'] = nil
        end
      end
      if options[:number] && options[:number].is_a?(Numeric)
        number['number'] = options[:number]
        number['size'] = number_size
        store['manually_assigned']['number'][options[:number].to_s] = true
      elsif store['manually_assigned']['number'][number['number'].to_s]
        number['number'] = nil
        number['size'] = nil
      end

      # Otherwise generate the missing ones
      bin['number'] ||= allocate_bin(size: bin_size)
      bin['size'] ||= bin_size
      # If the softbin is based on the test number, then need to calculate the
      # test number first
      if config.softbins.algorithm && config.softbins.algorithm.to_s =~ /n/
        number['number'] ||= allocate_number(bin: bin['number'], size: number_size)
        number['size'] ||= number_size
        softbin['number'] ||= allocate_softbin(bin: bin['number'], number: number['number'], size: softbin_size)
        softbin['size'] ||= softbin_size
      else
        softbin['number'] ||= allocate_softbin(bin: bin['number'], size: softbin_size)
        softbin['size'] ||= softbin_size
        number['number'] ||= allocate_number(bin: bin['number'], softbin: softbin['number'], size: number_size)
        number['size'] ||= number_size
      end

      # Record that there has been a reference to the final numbers
      time = Time.now.to_f
      bin_size.times do |i|
        store['references']['bin'][(bin['number'] + i).to_s] = time if bin['number'] && options[:bin] != :none
      end
      softbin_size.times do |i|
        store['references']['softbin'][(softbin['number'] + i).to_s] = time if softbin['number'] && options[:softbin] != :none
      end
      number_size.times do |i|
        store['references']['number'][(number['number'] + i).to_s] = time if number['number'] && options[:number] != :none
      end

      # Update the supplied options hash that will be forwarded to the program generator
      unless options.delete(:bin) == :none
        options[:bin] = bin['number']
        options[:bin_size] = bin['size']
      end
      unless options.delete(:softbin) == :none
        options[:softbin] = softbin['number']
        options[:softbin_size] = softbin['size']
      end
      unless options.delete(:number) == :none
        options[:number] = number['number']
        options[:number_size] = number['size']
      end

      ## If reallocation is on, then check if the generated numbers are compliant, if not
      ## clear them and go back around again to generate a new set
      # if TestIds.reallocate_non_compliant
      #  if !config.bins.function?
      #    if !config.bins.compliant?(options[:bin])
      #      store["assigned"]["bin"].delete(bin_id)
      #      return allocate(instance, orig_options)
      #    end
      #  end
      # end

      options
    end

    def store
      @store ||= begin
        s = JSON.load(File.read(file)) if file && File.exist?(file)
        if s
          if s['format_revision'] != STORE_FORMAT_REVISION
            # Upgrade the original store format
            t = { 'bin' => {}, 'softbin' => {}, 'number' => {} }
            s['tests'].each do |name, numbers|
              t['bin'][name] = { 'number' => numbers['bin'], 'size' => 1 }
              t['softbin'][name] = { 'number' => numbers['softbin'], 'size' => 1 }
              t['number'][name] = { 'number' => numbers['number'], 'size' => 1 }
            end
            s = {
              'format_revision'   => STORE_FORMAT_REVISION,
              'assigned'          => t,
              'manually_assigned' => s['manually_assigned'],
              'pointers'          => s['pointers'],
              'references'        => s['references']
            }
          end
          @last_bin = s['pointers']['bin']
          @last_softbin = s['pointers']['softbin']
          @last_number = s['pointers']['number']
          s
        else
          {
            'format_revision'   => STORE_FORMAT_REVISION,
            'assigned'          => { 'bin' => {}, 'softbin' => {}, 'number' => {} },
            'manually_assigned' => { 'bin' => {}, 'softbin' => {}, 'number' => {} },
            'pointers'          => { 'bin' => nil, 'softbin' => nil, 'number' => nil },
            'references'        => { 'bin' => {}, 'softbin' => {}, 'number' => {} }
          }
        end
      end
    end

    # Clear the :bins, :softbins and/or :numbers by setting the options for each item to true
    def clear(options)
      if options[:softbin] || options[:softbins]
        store['assigned']['softbin'] = {}
        store['manually_assigned']['softbin'] = {}
        store['pointers']['softbin'] = nil
        store['references']['softbin'] = {}
      end
      if options[:bin] || options[:bins]
        store['assigned']['bin'] = {}
        store['manually_assigned']['bin'] = {}
        store['pointers']['bin'] = nil
        store['references']['bin'] = {}
      end
      if options[:number] || options[:numbers]
        store['assigned']['number'] = {}
        store['manually_assigned']['number'] = {}
        store['pointers']['number'] = nil
        store['references']['number'] = {}
      end
    end

    # Saves the current allocator state to the repository
    def save
      if file
        # Ensure the current store has been loaded before we try to re-write it, this
        # is necessary if the program generator has crashed before creating a test
        store
        p = Pathname.new(file)
        FileUtils.mkdir_p(p.dirname)
        File.open(p, 'w') { |f| f.puts JSON.pretty_generate(store) }
      end
    end

    # Returns a path to the file that will be used to store the allocated bins/numbers,
    # returns nil if remote storage not enabled
    def file
      TestIds.database_file(id)
    end

    def id
      config.id
    end

    private

    # Returns the next available bin in the pool, if they have all been given out
    # the one that hasn't been used for the longest time will be given out
    def allocate_bin(options)
      return nil if config.bins.empty?
      if store['pointers']['bin'] == 'done'
        reclaim_bin(options)
      else
        b = config.bins.include.next(after: @last_bin, size: options[:size])
        @last_bin = nil
        while b && (store['manually_assigned']['bin'][b.to_s] || config.bins.exclude.include?(b))
          b = config.bins.include.next(size: options[:size])
        end
        # When no bin is returned it means we have used them all, all future generation
        # now switches to reclaim mode
        if b
          store['pointers']['bin'] = b
        else
          store['pointers']['bin'] = 'done'
          reclaim_bin(options)
        end
      end
    end

    def reclaim_bin(options)
      store['references']['bin'] = store['references']['bin'].sort_by { |k, v| v }.to_h
      if options[:size] == 1
        store['references']['bin'].first[0].to_i
      else
        reclaim(store['references']['bin'], options)
      end
    end

    def allocate_softbin(options)
      bin = options[:bin]
      num = options[:number]
      return nil if config.softbins.empty?
      if config.softbins.algorithm
        algo = config.softbins.algorithm.to_s.downcase
        if algo.to_s =~ /^[b\dxn]+$/
          number = algo.to_s
          bin = bin.to_s
          if number =~ /(b+)/
            max_bin_size = Regexp.last_match(1).size
            if bin.size > max_bin_size
              fail "Bin number (#{bin}) overflows the softbin number algorithm (#{algo})"
            end
            number = number.sub(/b+/, bin.rjust(max_bin_size, '0'))
          end
          if number =~ /(n+)/
            num = num.to_s
            max_num_size = Regexp.last_match(1).size
            if num.size > max_num_size
              fail "Test number (#{num}) overflows the softbin number algorithm (#{algo})"
            end
            number = number.sub(/n+/, num.rjust(max_num_size, '0'))
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
          reclaim_softbin(options)
        else
          b = config.softbins.include.next(after: @last_softbin, size: options[:size])
          @last_softbin = nil
          while b && (store['manually_assigned']['softbin'][b.to_s] || config.softbins.exclude.include?(b))
            b = config.softbins.include.next(size: options[:size])
          end
          # When no softbin is returned it means we have used them all, all future generation
          # now switches to reclaim mode
          if b
            store['pointers']['softbin'] = b
          else
            store['pointers']['softbin'] = 'done'
            reclaim_softbin(options)
          end
        end
      end
    end

    def reclaim_softbin(options)
      store['references']['softbin'] = store['references']['softbin'].sort_by { |k, v| v }.to_h
      if options[:size] == 1
        store['references']['softbin'].first[0].to_i
      else
        reclaim(store['references']['softbin'], options)
      end
    end

    def allocate_number(options)
      bin = options[:bin]
      softbin = options[:softbin]
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
            number = number.sub(/s+/, softbin.rjust(max_softbin_size, '0'))
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
          reclaim_number(options)
        else
          b = config.numbers.include.next(after: @last_number, size: options[:size])
          @last_number = nil
          while b && (store['manually_assigned']['number'][b.to_s] || config.numbers.exclude.include?(b))
            b = config.numbers.include.next(size: options[:size])
          end
          # When no number is returned it means we have used them all, all future generation
          # now switches to reclaim mode
          if b
            store['pointers']['number'] = b
          else
            store['pointers']['number'] = 'done'
            reclaim_number(options)
          end
        end
      end
    end

    def reclaim_number(options)
      store['references']['number'] = store['references']['number'].sort_by { |k, v| v }.to_h
      if options[:size] == 1
        store['references']['number'].first[0].to_i
      else
        reclaim(store['references']['number'], options)
      end
    end

    # Returns the oldest number in the given reference hash, however also supports a :size option
    # and in that case it will look for the oldest contiguous range of the given size
    def reclaim(refs, options)
      a = []
      i = 0 # Pointer to references hash, which is already sorted with oldest first
      s = 0 # Largest contiguous size in the array of considered numbers
      p = 0 # Pointer to start of a suitable contiguous section in the array
      while s < options[:size] && i < refs.size
        a << refs.keys[i].to_i
        a.sort!
        s, p = largest_contiguous_section(a)
        i += 1
      end
      a[p]
    end

    def largest_contiguous_section(array)
      max_ptr = 0
      max_size = 0
      p = nil
      s = nil
      prev = nil
      array.each_with_index do |v, i|
        if prev
          if v == prev + 1
            s += 1
          else
            if s > max_size
              max_size = s
              max_ptr = p
            end
            p = i
            s = 1
          end
          prev = v
        else
          p = i
          s = 1
          prev = v
        end
      end
      if s > max_size
        max_size = s
        max_ptr = p
      end
      [max_size, max_ptr]
    end

    def extract_test_name(instance, options)
      name = options[:test_id]
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
