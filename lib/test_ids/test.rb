module TestIds
  # Each test will be represented by this class and stored
  # in the datastore, serialized into YAML
  class Test
    attr_reader :name
    attr_accessor :bin, :softbin, :number

    def initialize(name)
      @name = name
    end

    def update_from_options(options)
      @bin = options[:bin] if options[:bin]
      @softbin = options[:softbin] if options[:softbin]
      @number = options[:number] if options[:number]
    end

    def to_options
      { bin: bin, softbin: softbin, number: number }
    end

    def update_options(options)
      options[:bin] = bin
      options[:softbin] = softbin
      options[:number] = number
    end
  end
end
