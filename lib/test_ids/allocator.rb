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
      test = fetch_existing(name) || Test.new(name)
      test.update_from_options(options)
      test.bin ||= allocate_bin
      test.softbin ||= allocate_softbin
      test.number ||= allocate_number
      test.update_options(options)
      store.record(test)
    end

    def config
      TestIds.config
    end

    def store
      TestIds.store
    end

    private

    def allocate_bin
      config.bins.include.next
    end

    def allocate_softbin
    end

    def allocate_number
    end

    def fetch_existing(name)
      store.find(name)
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
