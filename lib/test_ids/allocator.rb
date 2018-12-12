require 'json'
module TestIds
  # The allocator is responsible for assigning new numbers and keeping a record of
  # existing assignments.
  #
  # There is one allocator instance per configuration, and each has its own database
  # file.
  class Allocator
    STORE_FORMAT_REVISION = 2

    def initialize(configuration)
      @config = configuration
    end

    def config(type = nil)
      if type
        type = type.to_s
        type.chop! if type[-1] == 's'
        TestIds.send("#{type}_config") || @config
      else
        @config
      end
    end

    # Allocates a softbin number from the range specified in the test flow
    # It also keeps a track of the last softbin assigned out from a particular range
    # and uses that to increment the pointers accordingly.
    # If a numeric number is passed to the softbin, it uses that number.
    # The configuration for the TestId plugin needs to pass in the bin number and the options from the test flow
    # For this method to work as intended.
    def next_in_range(range, options)
      range_item(range, options)
    end

    def range_item(range, options)
      orig_options = options.dup

      # Create an alias for the database that stores the pointers per range
      rangehash = store['pointers']['ranges'] ||= {}
      # remap keys to correct if file exists
      rangehash = Hash[rangehash.map { |k, v| [k.to_sym, v] }] if file && File.exist?(file)
      # Check the database to see if the passed in range has already been included in the database hash
      if rangehash.key?(:"#{range}")
        # Read out the database hash to see what the last_softbin given out was for that range.
        # This hash is updated whenever a new softbin is assigned, so it should have the updated values for each range.
        previous_assigned_value = rangehash[:"#{range}"].to_i
        # Now calculate the new pointer.
        @pointer = previous_assigned_value - range.min
        # Check if the last_softbin given out is the same as the range[@pointer],
        # if so increment pointer by softbin size, default size is 1, config.softbins.size is configurable.
        # from example above, pointer was calculated as 1,range[1] is 10101 and is same as last_softbin, so pointer is incremented
        # and new value is assigned to the softbin.
        if previous_assigned_value == range.to_a[@pointer]
          @pointer += options[:size]
          assigned_value = range.to_a[@pointer]
        else
          # Because of the pointer calculations above, I don't think it will ever reach here, has not in my test cases so far!
          assigned_value = range.to_a[@pointer]
        end
        # Now update the database pointers to point to the lastest assigned softbin for a given range.
        rangehash.merge!(:"#{range}" => "#{range.to_a[@pointer]}")
      else
        # This is the case for a brand new range that has not been passed before
        # We start from the first value as the assigned softbin and update the database to reflect.
        @pointer = 0
        rangehash.merge!(:"#{range}" => "#{range.to_a[@pointer]}")
        assigned_value = range.to_a[@pointer]
      end
      unless !assigned_value.nil? && assigned_value.between?(range.min, range.max)
        Origen.log.error 'Assigned value not in range'
        fail
      end
      assigned_value
    end

    # Returns an array containing :bin, :softbin, :number in the order that they should be calculated in order to fulfil
    # the requirements of the current configuration and the given options.
    # If an item is not required (e.g. if set to :none in the options), then it will not be present in the array.
    def allocation_order(options)
      items = []
      items_required = 0
      if allocation_required?(:bin, options) ||
         (allocation_required?(:softbin, options) && config(:softbin).softbins.needs?(:bin)) ||
         (allocation_required?(:number, options) && config(:number).numbers.needs?(:bin))
        items_required += 1
      else
        bin_done = true
      end
      if allocation_required?(:softbin, options) ||
         (allocation_required?(:bin, options) && config(:bin).bins.needs?(:softbin)) ||
         (allocation_required?(:number, options) && config(:number).numbers.needs?(:softbin))
        items_required += 1
      else
        softbin_done = true
      end
      if allocation_required?(:number, options) ||
         (allocation_required?(:bin, options) && config(:bin).bins.needs?(:number)) ||
         (allocation_required?(:softbin, options) && config(:softbin).softbins.needs?(:number))
        items_required += 1
      else
        number_done = true
      end
      items_required.times do |i|
        if !bin_done && (!config(:bin).bins.needs?(:softbin) || softbin_done) && (!config(:bin).bins.needs?(:number) || number_done)
          items << :bin
          bin_done = true
        elsif !softbin_done && (!config(:softbin).softbins.needs?(:bin) || bin_done) && (!config(:softbin).softbins.needs?(:number) || number_done)
          items << :softbin
          softbin_done = true
        elsif !number_done && (!config(:number).numbers.needs?(:bin) || bin_done) && (!config(:number).numbers.needs?(:softbin) || softbin_done)
          items << :number
          number_done = true
        else
          fail "Couldn't work out whether to generate next on iteration #{i} of #{items_required}, already picked: #{items}"
        end
      end
      items
    end

    # Main method to inject generated bin and test numbers, the given
    # options instance is modified accordingly
    def allocate(instance, options)
      orig_options = options.dup
      clean(options)
      name = extract_test_name(instance, options)

      nones = []

      # Record any :nones that are present for later
      [:bin, :softbin, :number].each do |type|
        nones << type if options[type] == :none
        config(type).allocator.instance_variable_set('@needs_regenerated', {})
      end

      allocation_order(options).each do |type|
        config(type).allocator.send(:_allocate, type, name, options)
      end

      # Turn any :nones into nils in the returned options
      nones.each do |type|
        options[type] = nil
        options["#{type}_size"] = nil
      end

      options
    end

    # Merge the given other store into the current one, it is assumed that both are formatted
    # from the same (latest) revision
    def merge_store(other_store)
      store['pointers'] = store['pointers'].merge(other_store['pointers'])
      @last_bin = store['pointers']['bins']
      @last_softbin = store['pointers']['softbins']
      @last_number = store['pointers']['numbers']
      store['assigned']['bins'] = store['assigned']['bins'].merge(other_store['assigned']['bins'])
      store['assigned']['softbins'] = store['assigned']['softbins'].merge(other_store['assigned']['softbins'])
      store['assigned']['numbers'] = store['assigned']['numbers'].merge(other_store['assigned']['numbers'])
      store['manually_assigned']['bins'] = store['manually_assigned']['bins'].merge(other_store['manually_assigned']['bins'])
      store['manually_assigned']['softbins'] = store['manually_assigned']['softbins'].merge(other_store['manually_assigned']['softbins'])
      store['manually_assigned']['numbers'] = store['manually_assigned']['numbers'].merge(other_store['manually_assigned']['numbers'])
      store['references']['bins'] = store['references']['bins'].merge(other_store['references']['bins'])
      store['references']['softbins'] = store['references']['softbins'].merge(other_store['references']['softbins'])
      store['references']['numbers'] = store['references']['numbers'].merge(other_store['references']['numbers'])
    end

    def store
      @store ||= begin
        if file && File.exist?(file)
          lines = File.readlines(file)
          # Remove any header comment lines since these are not valid JSON
          lines.shift while lines.first =~ /^\/\// && !lines.empty?
          s = JSON.load(lines.join("\n"))
        end
        if s
          unless s['format_revision']
            # Upgrade the original store format
            t = { 'bin' => {}, 'softbin' => {}, 'number' => {} }
            s['tests'].each do |name, numbers|
              t['bin'][name] = { 'number' => numbers['bin'], 'size' => 1 }
              t['softbin'][name] = { 'number' => numbers['softbin'], 'size' => 1 }
              t['number'][name] = { 'number' => numbers['number'], 'size' => 1 }
            end
            s = {
              'format_revision'   => 1,
              'assigned'          => t,
              'manually_assigned' => s['manually_assigned'],
              'pointers'          => s['pointers'],
              'references'        => s['references']
            }
          end
          # Change the keys to plural versions, this makes it easier to search for in the file
          # since 'number' is used within individual records
          if s['format_revision'] == 1
            s = {
              'format_revision'   => 2,
              'configuration'     => nil,
              'pointers'          => { 'bins' => s['pointers']['bin'], 'softbins' => s['pointers']['softbin'], 'numbers' => s['pointers']['number'] },
              'assigned'          => { 'bins' => s['assigned']['bin'], 'softbins' => s['assigned']['softbin'], 'numbers' => s['assigned']['number'] },
              'manually_assigned' => { 'bins' => s['manually_assigned']['bin'], 'softbins' => s['manually_assigned']['softbin'], 'numbers' => s['manually_assigned']['number'] },
              'references'        => { 'bins' => s['references']['bin'], 'softbins' => s['references']['softbin'], 'numbers' => s['references']['number'] }
            }
          end

          @last_bin = s['pointers']['bins']
          @last_softbin = s['pointers']['softbins']
          @last_number = s['pointers']['numbers']
          s
        else
          {
            'format_revision'   => STORE_FORMAT_REVISION,
            'configuration'     => nil,
            'pointers'          => { 'bins' => nil, 'softbins' => nil, 'numbers' => nil },
            'assigned'          => { 'bins' => {}, 'softbins' => {}, 'numbers' => {} },
            'manually_assigned' => { 'bins' => {}, 'softbins' => {}, 'numbers' => {} },
            'references'        => { 'bins' => {}, 'softbins' => {}, 'numbers' => {} }
          }
        end
      end
    end

    def repair(options = {})
      #####################################################################
      # Add any numbers that are missing from the references pool if the
      # allocator has moved onto the reclamation phase
      #####################################################################
      { 'bins' => 'bins', 'softbins' => 'softbins', 'numbers' => 'test_numbers' }.each do |type, name|
        if !config.send(type).function? && store['pointers'][type] == 'done'
          Origen.log.info "Checking for missing #{name}..."
          recovered = add_missing_references(config.send, store['references'][type])
          if recovered == 0
            Origen.log.info "  All #{name} are already available."
          else
            Origen.log.success "  Another #{recovered} #{name} have been made available!"
          end
        end
      end

      #####################################################################
      # Check that all assignments are valid based on the current config,
      # if not remove them and they will be re-allocated next time
      #####################################################################
      { 'bins' => 'bins', 'softbins' => 'softbins', 'numbers' => 'test_numbers' }.each do |type, name|
        next if config.send(type).function?
        Origen.log.info "Checking all #{name} assignments are valid..."
        also_remove_from = []
        if type == 'bin'
          also_remove_from << store['assigned']['softbins'] if config.softbins.function?
          also_remove_from << store['assigned']['numbers'] if config.numbers.function?
        elsif type == 'softbin'
          also_remove_from << store['assigned']['numbers'] if config.numbers.function?
        else
          also_remove_from << store['assigned']['softbins'] if config.softbins.function?
        end
        removed = remove_invalid_assignments(config.send(type), store['assigned'][type], store['manually_assigned'][type], also_remove_from)
        if removed == 0
          Origen.log.info "  All #{name} assignments are already valid."
        else
          Origen.log.success "  #{removed} #{name} assignments have been removed!"
        end
      end

      #####################################################################
      # Check that all references are valid based on the current config,
      # if not remove them
      #####################################################################
      { 'bins' => 'bins', 'softbins' => 'softbins', 'numbers' => 'test_numbers' }.each do |type, name|
        next if config.send(type).function?
        Origen.log.info "Checking all #{name} references are valid..."
        removed = remove_invalid_references(config.send(type), store['references'][type], store['manually_assigned'][type])
        if removed == 0
          Origen.log.info "  All #{name} references are already valid."
        else
          Origen.log.success "  #{removed} #{name} references have been removed!"
        end
      end
    end

    # Clear the :bins, :softbins and/or :numbers by setting the options for each item to true
    def clear(options)
      if options[:softbin] || options[:softbins]
        store['assigned']['softbins'] = {}
        store['manually_assigned']['softbins'] = {}
        store['pointers']['softbins'] = nil
        store['references']['softbins'] = {}
      end
      if options[:bin] || options[:bins]
        store['assigned']['bins'] = {}
        store['manually_assigned']['bins'] = {}
        store['pointers']['bins'] = nil
        store['references']['bins'] = {}
      end
      if options[:number] || options[:numbers]
        store['assigned']['numbers'] = {}
        store['manually_assigned']['numbers'] = {}
        store['pointers']['numbers'] = nil
        store['references']['numbers'] = {}
      end
    end

    # Saves the current allocator state to the repository
    def save
      if file
        # Ensure the current store has been loaded before we try to re-write it, this
        # is necessary if the program generator has crashed before creating a test
        store
        store['configuration'] = config
        p = Pathname.new(file)
        FileUtils.mkdir_p(p.dirname)
        File.open(p, 'w') do |f|
          f.puts '// The structure of this file is as follows:'
          f.puts '//'
          f.puts '//  {'
          f.puts '//    // A revision number used by TestIDs to identify the format of this file'
          f.puts "//    'format_revision'   => STORE_FORMAT_REVISION,"
          f.puts '//'
          f.puts '//    // Captures the configuration that was used the last time this database was updated.'
          f.puts "//    'configuration'          => { 'bins' => {}, 'softbins' => {}, 'numbers' => {} },"
          f.puts '//'
          f.puts '//    // If some number are still to be allocated, these point to the last number given out.'
          f.puts '//    // If all numbers have been allocated and we are now on the reclamation phase, the pointer'
          f.puts '//    // will contain "done".'
          f.puts "//    'pointers'          => { 'bins' => nil, 'softbins' => nil, 'numbers' => nil, 'ranges' => nil },"
          f.puts '//'
          f.puts '//    // This is the record of all numbers which have been previously assigned.'
          f.puts "//    'assigned'          => { 'bins' => {}, 'softbins' => {}, 'numbers' => {} },"
          f.puts '//'
          f.puts '//    // This is a record of any numbers which have been manually assigned.'
          f.puts "//    'manually_assigned' => { 'bins' => {}, 'softbins' => {}, 'numbers' => {} },"
          f.puts '//'
          f.puts '//    // This contains all assigned numbers with a timestamp of when they were last referenced.'
          f.puts '//    // When numbers need to be reclaimed, they will be taken from the bottom of this list, i.e.'
          f.puts '//    // the numbers which have not been used for the longest time, e.g. because the test they'
          f.puts '//    // were assigned to has since been removed.'
          f.puts "//    'references'        => { 'bins' => {}, 'softbins' => {}, 'numbers' => {} }"
          f.puts '//  }'
          f.puts JSON.pretty_generate(store)
        end
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

    # @api private
    def load_configuration_from_store
      config.load_from_serialized(store['configuration']) if store['configuration']
    end

    private

    def _allocate(type, name, options)
      type_plural = "#{type}s"
      conf = config.send(type_plural)

      # First work out the test ID to be used for each of the numbers, and how many numbers
      # should be reserved
      if (options[type].is_a?(Symbol) || options[type].is_a?(String)) && options[type] != :none
        id = options[type].to_s
      else
        id = name
      end
      id = "#{id}_#{options[:index]}" if options[:index]
      id = "#{id}_#{options[:test_ids_flow_id]}" if config.unique_by_flow?

      val = store['assigned'][type_plural][id] ||= {}

      if options[type].is_a?(Integer)
        unless val['number'] == options[type]
          store['manually_assigned']["#{type}s"][options[type].to_s] = true
          val['number'] = options[type]
        end
      else
        # Will be set if an upstream dependent type has been marked for regeneration by the code below
        if @needs_regenerated[type]
          val['number'] = nil
          val['size'] = nil
        # Regenerate the number if the original allocation has since been applied manually elsewhere
        elsif store['manually_assigned'][type_plural][val['number'].to_s]
          val['number'] = nil
          val['size'] = nil
          # Also regenerate these as they could be a function of the number we just invalidated
          ([:bin, :softbin, :number] - [type]).each do |t|
            if config.send("#{t}s").needs?(type)
              @needs_regenerated[t] = true
            end
          end
        end
      end

      if size = options["#{type}_size".to_sym]
        val['size'] = size
      end

      # Generate the missing ones
      val['size'] ||= conf.size
      val['number'] ||= allocate_item(type, options.merge(size: val['size']))

      # Record that there has been a reference to the final numbers
      time = Time.now.to_f
      val['size'].times do |i|
        store['references'][type_plural][(val['number'] + i).to_s] = time if val['number'] && options[type] != :none
      end

      # Update the supplied options hash that will be forwarded to the program generator
      options[type] = val['number']
      options["#{type}_size".to_sym] = val['size']
    end

    def allocation_required?(type, options)
      if options[type] == :none
        false
      else
        !config(type).send("#{type}s").empty?
      end
    end

    def remove_invalid_references(config_item, references, manually_assigned)
      removed = 0
      references.each do |num, time|
        unless config_item.valid?(num.to_i) || manually_assigned[num]
          removed += 1
          references.delete(num)
        end
      end
      removed
    end

    def remove_invalid_assignments(config_item, assigned, manually_assigned, also_remove_from)
      removed = 0
      assigned.each do |id, a|
        a['size'].times do |i|
          unless config_item.valid?(a['number'] + i) || manually_assigned[(a['number'] + i).to_s]
            removed += 1
            assigned.delete(id)
            also_remove_from.each { |a| a.delete(id) }
            break
          end
        end
      end
      removed
    end

    def add_missing_references(config_item, references)
      recovered = 0
      a_long_time_ago = Time.new(2000, 1, 1).to_f
      config_item.yield_all do |i|
        i = i.to_s
        unless references[i]
          references[i] = a_long_time_ago
          recovered += 1
        end
      end
      recovered
    end

    def allocate_item(type, options)
      type_plural = "#{type}s"
      conf = config.send(type_plural)
      if conf.algorithm
        algo = conf.algorithm.to_s.downcase
        if algo.to_s =~ /^[bsn\dx]+$/
          number = algo.to_s
          ([:bin, :softbin, :number] - [type]).each do |t|
            if number =~ /(#{t.to_s[0]}+)/
              max_size = Regexp.last_match(1).size
              num = options[t].to_s
              if num.size > max_size
                fail "The allocated number, #{num}, overflows the #{t} field in the #{type} algorithm - #{algo}"
              end
              number = number.sub(/#{t.to_s[0]}+/, num.rjust(max_size, '0'))
            end
          end

          if number =~ /(x+)/
            max_counter_size = Regexp.last_match(1).size
            refs = store['references'][type_plural]
            i = 0
            possible = []
            proposal = number.sub(/x+/, i.to_s.rjust(max_counter_size, '0')).to_i.to_s
            possible << proposal
            while refs[proposal] && i.to_s.size <= max_counter_size
              i += 1
              proposal = number.sub(/x+/, i.to_s.rjust(max_counter_size, '0')).to_i.to_s
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
          fail "Illegal algorithm: #{algo}"
        end
        number.to_i
      elsif callback = conf.callback
        callback.call(options)
      else
        if store['pointers'][type_plural] == 'done'
          reclaim_item(type, options)
        else
          b = conf.include.next(after: instance_variable_get("@last_#{type}"), size: options[:size])
          instance_variable_set("@last_#{type}", nil)
          while b && (store['manually_assigned'][type_plural][b.to_s] || conf.exclude.include?(b))
            b = conf.include.next(size: options[:size])
          end
          # When no number is returned it means we have used them all, all future generation
          # now switches to reclaim mode
          if b
            store['pointers'][type_plural] = b + (options[:size] || 1) - 1
            b
          else
            store['pointers'][type_plural] = 'done'
            reclaim_item(type, options)
          end
        end
      end
    end

    def reclaim_item(type, options)
      type_plural = "#{type}s"
      store['references'][type_plural] = store['references'][type_plural].sort_by { |k, v| v }.to_h
      if options[:size] == 1
        v = store['references'][type_plural].first
        v[0].to_i if v
      else
        reclaim(store['references'][type_plural], options)
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
      name = options[:test_id] || options[:name]
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
