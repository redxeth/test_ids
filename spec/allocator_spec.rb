require "spec_helper"

describe "The allocator" do

  before :each do
    TestIds.send(:reset)
  end

  def allocator
    TestIds.current_configuration.allocator
  end

  def config
    TestIds.current_configuration
  end

  # Don't need to test the other permutations since they use the same logic
  it "knows when the bin needs the softbin" do
    TestIds.configure do |config|
    end
    config.bins.needs?(:softbin).should == false
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.include << (0..10)
    end
    config.bins.needs?(:softbin).should == false
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.algorithm = :ssssxxxx
    end
    config.bins.needs?(:softbin).should == true
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.callback do |options|
        10 * 10
      end
    end
    config.bins.needs?(:softbin).should == false
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.callback needs: :softbin do |softbin, options|
        softbin * 10
      end
    end
    config.bins.needs?(:softbin).should == true
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.callback needs: [:softbin, :number] do |softbin, number, options|
        softbin * 10
      end
    end
    config.bins.needs?(:softbin).should == true
    TestIds.send(:reset)
  end

  it "can workout what to generate first" do
    TestIds.configure do |config|
    end
    allocator.allocation_order({}).should == []
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.include << (0..10)
    end
    allocator.allocation_order({}).should == [:bin]
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.include << (0..10)
      config.softbins.include << (0..10)
      config.numbers.include << (0..10)
    end
    allocator.allocation_order({}).should == [:bin, :softbin, :number]
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.algorithm = :ssssxxxx
      config.softbins.include << (0..10)
      config.numbers.include << (0..10)
    end
    allocator.allocation_order({}).should == [:softbin, :bin, :number]
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.algorithm = :ssssxxxx
      config.softbins.include << (0..10)
      config.numbers.callback do |options|
        10 * 10
      end
    end
    allocator.allocation_order({}).should == [:softbin, :bin, :number]
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.algorithm = :ssssxxxx
      config.softbins.include << (0..10)
      config.numbers.callback needs: :bin do |bin, options|
        bin * 10
      end
    end
    allocator.allocation_order({}).should == [:softbin, :bin, :number]
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.algorithm = :ssssxxxx
      config.softbins.include << (0..10)
      config.numbers.callback needs: :softbin do |softbin, options|
        softbin * 10
      end
    end
    allocator.allocation_order({}).should == [:softbin, :bin, :number]
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.algorithm = :ssssxxxx
      config.softbins.callback needs: :number do |number, options|
        number * 10
      end
      config.numbers.include << (0..10)
    end
    allocator.allocation_order({}).should == [:number, :softbin, :bin]
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.algorithm = :ssssxxxx
      config.softbins.callback needs: :number do |number, options|
        number * 10
      end
      config.numbers.include << (0..10)
    end
    allocator.allocation_order({bin: :none}).should == [:number, :softbin]
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.algorithm = :ssssxxxx
      config.softbins.callback needs: :number do |number, options|
        number * 10
      end
      config.numbers.include << (0..10)
    end
    # Softbin still here because bin needs it
    allocator.allocation_order({softbin: :none}).should == [:number, :softbin, :bin]
    TestIds.send(:reset)

    TestIds.configure do |config|
      config.bins.algorithm = :ssssxxxx
      config.softbins.callback needs: :number do |number, options|
        number * 10
      end
      config.numbers.include << (0..10)
    end
    allocator.allocation_order({softbin: :none, bin: :none}).should == [:number]
    TestIds.send(:reset)
  end

  it "can allocate only a bin number" do
    TestIds.configure do |config|
      config.bins.include << (0..10)
      config.softbins.include << (0..10)
      config.numbers.include << (0..10)
    end

    r = TestIds.allocate_number(:t1)
    r.should == { number: 0, number_size: 1}
    r = TestIds.allocate_number(:t2)
    r = TestIds.allocate_number(:t3)
    r = TestIds.allocate_number(:t4)
    r.should == { number: 3, number_size: 1}
    r = TestIds.allocate(:t5)
    r[:number].should == 4
    r[:bin].should == 0
    r[:softbin].should == 0
  end
end
