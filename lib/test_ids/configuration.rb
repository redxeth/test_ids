module TestIds
  class Configuration
    class Item
      attr_accessor :include, :exclude, :algorithm, :size, :needs

      def initialize
        @include = BinArray.new
        @exclude = BinArray.new
        @needs = []
        @size = 1
      end

      def callback(options = {}, &block)
        if block_given?
          @needs += Array(options[:needs])
          @callback = block
        else
          @callback
        end
      end

      def needs?(type)
        !!(!empty? && function? && (needs.include?(type) ||
            (algorithm && (algorithm.to_s =~ /#{type.to_s[0]}/i))))
      end

      def empty?
        include.empty? && exclude.empty? && !algorithm && !callback
      end

      def function?
        !!algorithm || !!callback
      end

      def valid?(number)
        if function?
          fail 'valid? is not supported for algorithm or callback-based assignments'
        end
        number = number.to_i
        include.include?(number) && !exclude.include?(number)
      end

      def freeze
        @include.freeze
        @exclude.freeze
        @needs.freeze
        super
      end

      # @api private
      def load_from_serialized(o)
        if o.is_a?(Hash)
          @size = o['size']
          @include.load_from_serialized(o['include'])
          @exclude.load_from_serialized(o['exclude'])
        elsif o == 'callback'
          callback do
            fail 'The callback for this configuration is not available!'
          end
        else
          self.algorithm = o
        end
      end

      def to_json(*a)
        if callback
          'callback'.to_json(*a)
        elsif algorithm
          algorithm.to_s.to_json(*a)
        else
          {
            'include' => include,
            'exclude' => exclude,
            'size'    => size
          }.to_json(*a)
        end
      end

      # Yields all included numbers to the given block, one at a time
      def yield_all
        include.yield_all do |i|
          yield i unless exclude.include?(i)
        end
        nil
      end
    end

    attr_reader :allocator

    def initialize(id)
      @id = id
      @allocator = Allocator.new(self)
    end

    def id
      @id
    end

    def bins(options = {}, &block)
      @bins ||= Item.new
      if block_given?
        @bins.callback(options, &block)
      end
      @bins
    end

    # An alias for config.bins.algorithm=
    def bins=(val)
      bins.algorithm = val
    end

    def softbins(options = {}, &block)
      @softbins ||= Item.new
      if block_given?
        @softbins.callback(options, &block)
      end
      @softbins
    end

    # An alias for config.softbins.algorithm=
    def softbins=(val)
      softbins.algorithm = val
    end

    def numbers(options = {}, &block)
      @numbers ||= Item.new
      if block_given?
        @numbers.callback(options, &block)
      end
      @numbers
    end

    # An alias for config.numbers.algorithm=
    def numbers=(val)
      numbers.algorithm = val
    end

    def send_to_ate=(val)
      @send_to_ate = !!val
    end

    def send_to_ate?
      defined?(@send_to_ate) ? @send_to_ate : true
    end

    def unique_by_flow=(val)
      @unique_by_flow = !!val
    end

    def unique_by_flow?
      @unique_by_flow || false
    end

    def validate!
      unless validated?
        @validated = true
        freeze
      end
    end

    def empty?
      bins.empty? && softbins.empty? && numbers.empty?
    end

    def validated?
      @validated
    end

    def freeze
      bins.freeze
      softbins.freeze
      numbers.freeze
      super
    end

    def to_json(*a)
      {
        'bins'     => bins,
        'softbins' => softbins,
        'numbers'  => numbers
      }.to_json(*a)
    end

    # @api private
    def load_from_serialized(store)
      bins.load_from_serialized(store['bins'])
      softbins.load_from_serialized(store['softbins'])
      numbers.load_from_serialized(store['numbers'])
    end
  end
end
