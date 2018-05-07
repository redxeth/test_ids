module TestIds
  class Configuration
    class Item
      attr_accessor :include, :exclude, :algorithm, :size

      def initialize
        @include = BinArray.new
        @exclude = BinArray.new
        @size = 1
      end

      def callback(&block)
        if block_given?
          @callback = block
        else
          @callback
        end
      end

      def empty?
        include.empty? && exclude.empty? && !algorithm && !callback
      end

      def function?
        !!algorithm || !!callback
      end

      # def compliant?(number)
      # end

      def freeze
        @include.freeze
        @exclude.freeze
        super
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

    def bins
      @bins ||= Item.new
    end

    def softbins
      @softbins ||= Item.new
      if block_given?
        @softbins.callback(&block)
      end
      @softbins
    end

    # An alias for config.softbins.algorithm=
    def softbins=(val)
      softbins.algorithm = val
    end

    def numbers(&block)
      @numbers ||= Item.new
      if block_given?
        @numbers.callback(&block)
      end
      @numbers
    end

    # An alias for config.numbers.algorithm=
    def numbers=(val)
      numbers.algorithm = val
    end

    def send_to_ate=(val)
      @send_to_ate = val
    end

    def send_to_ate
      @send_to_ate
    end

    def validate!
      unless validated?
        if bins.algorithm
          fail 'The TestIds bins configuration cannot be set to an algorithm, only a range set by bins.include and bins.exclude is permitted'
        end
        if bins.callback
          fail 'The TestIds bins configuration cannot be set by a callback, only a range set by bins.include and bins.exclude is permitted'
        end
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
  end
end
