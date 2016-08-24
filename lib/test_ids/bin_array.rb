module TestIds
  class BinArray
    def initialize
      @store = []
    end

    def <<(val)
      @store += Array(val)
      @store = @store.sort do |a, b|
        a = a.min if a.is_a?(Range)
        b = b.min if b.is_a?(Range)
        a <=> b
      end
      nil
    end

    def empty?
      @store.empty?
    end

    def freeze
      @store.freeze
      super
    end

    # Returns true if the array contains the given bin number
    def include?(bin)
      @store.any? do |v|
        v == bin || (v.is_a?(Range) && bin >= v.min && bin <= v.max)
      end
    end

    # Returns the next bin in the array, starting from the first and remembering the last bin
    # when called the next time.
    # A bin can optionally be supplied in which case the internal pointer will be reset and the
    # next bin that occurs after the given number will be returned.
    def next(after = nil)
      if after
        # Need to work out the pointer here as it is probably out of sync with the
        # last value now
        @pointer = nil
        i = 0
        until @pointer
          v = @store[i]
          if v
            if after == v || (v.is_a?(Range) && after >= v.min && after <= v.max)
              @pointer = i
              @next = after
            elsif after < min_val(v)
              @pointer = previous_pointer(i)
              @next = min_val(v) - 1
            end
          else
            # Gone past the end of the array
            @pointer = @store.size - 1
            @next = min_val(@store[0]) - 1
          end
          i += 1
        end
      end
      if @next
        @pointer ||= 0
        if @store[@pointer].is_a?(Range) && @next != @store[@pointer].max
          @next += 1
        else
          @pointer += 1
          # Wrap around when we get to the end of the array
          @pointer = 0 if @pointer == @store.size
          @next = @store[@pointer]
          @next = @next.min if @next.is_a?(Range)
        end
      else
        v = @store.first
        if v.is_a?(Range)
          @next = v.min
        else
          @next = v
        end
      end
      @next
    end

    def min
      v = @store.first
      if v.is_a?(Range)
        v.min
      else
        v
      end
    end

    def max
      v = @store.last
      if v.is_a?(Range)
        v.max
      else
        v
      end
    end

    private

    def previous_pointer(i)
      i == 0 ? @store.size - 1 : i - 1
    end

    def min_val(v)
      v.is_a?(Range) ? v.min : v
    end

    def max_val(v)
      v.is_a?(Range) ? v.max : v
    end
  end
end
