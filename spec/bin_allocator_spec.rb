require "spec_helper"

describe "The bin allocator" do

  before :each do
    TestIds.send(:reset)
  end

  def a(name, options = {})
    TestIds.current_configuration.allocator.allocate(name, options)
    options
  end

  it "is alive" do
    TestIds.configure do |config|
      config.bins.include << 3
    end
    a(:t1)[:bin].should == 3
  end

  it "bin numbers increment" do
    TestIds.configure do |config|
      config.bins.include << (1..3)
    end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 2
    a(:t3)[:bin].should == 3
  end

  it "duplicate tests pick up the same bin number" do
    TestIds.configure do |config|
      config.bins.include << (1..3)
    end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 2
    a(:t1)[:bin].should == 1
    a(:t3)[:bin].should == 3
  end

  it "caller can override bin number" do
    TestIds.configure do |config|
      config.bins.include << (1..4)
    end
    a(:t1)[:bin].should == 1
    a(:t2, bin: 3)[:bin].should == 3
    TestIds.allocate(:t1)[:bin].should == 1
    TestIds.allocate(:t2, bin: 3)[:bin].should == 3
    TestIds.allocate(:t3)[:bin].should == 2
  end

  it "manually assigned bins are reserved" do
    TestIds.configure do |config|
      config.bins.include << (1..4)
    end
    a(:t1)[:bin].should == 1
    a(:t2, bin: 3)[:bin].should == 3
    a(:t3)[:bin].should == 2
    a(:t4)[:bin].should == 4
  end

  it "bin assignments can be inhibited by passing :none" do
    TestIds.configure do |config|
      config.bins.include << (1..4)
    end
    a(:t1)[:bin].should == 1
    a(:t1, bin: :none)[:bin].should == nil
  end

  it "excluded bins are not used" do
    TestIds.configure do |config|
      config.bins.include << (1..4)
      config.bins.exclude << 3
    end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 2
    a(:t3)[:bin].should == 4
  end

  it "the system can be saved to a file and resumed" do
    TestIds.configure do |config|
      config.bins.include << (1..4)
    end
    a(:t1)[:bin].should == 1
    a(:t2, bin: 3)[:bin].should == 3
    
    #TestIds.allocator.save
    #TestIds.send(:reset)
    #TestIds.configure do |config|
    #  config.bins.include << (1..4)
    #end
    a(:t3)[:bin].should == 2
    a(:t4)[:bin].should == 4
  end

  it "previously assigned manual bins are reclaimed next time" do
    TestIds.configure do |config|
      config.bins.include << (1..4)
    end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 2
    a(:t3, bin: 2)[:bin].should == 2
    
    #TestIds.allocator.save
    #TestIds.send(:reset)
    #TestIds.configure do |config|
    #  config.bins.include << (1..4)
    #end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 3
    a(:t3, bin: 2)[:bin].should == 2
  end

  it "when all bins are used they will be re-used oldest first" do
    TestIds.configure do |config|
      config.bins.include << (1..3)
    end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 2
    a(:t3)[:bin].should == 3
    a(:t4)[:bin].should == 1
    a(:t4)[:bin].should == 1
    a(:t5)[:bin].should == 2

    #TestIds.send(:reset)
    #TestIds.configure do |config|
    #  config.bins.include << (1..3)
    #end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 2
    a(:t3)[:bin].should == 3
    a(:t1)[:bin].should == 1  # More recent reference makes 2 the oldest
    a(:t6)[:bin].should == 2

    #TestIds.allocator.save
    #TestIds.send(:reset)
    #TestIds.configure do |config|
    #  config.bins.include << (1..3)
    #end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 2
    a(:t3)[:bin].should == 3
    a(:t1)[:bin].should == 1  # More recent reference makes 2 the oldest
    a(:t7)[:bin].should == 2
    a(:t8)[:bin].should == 3
  end

  it "tests can reserve multiple bins" do
    TestIds.configure do |config|
      config.bins.include << (10..30)
      config.bins.size = 5
    end

    t = a(:t1, bin_size: 2)
    t[:bin].should == 10
    # Verify the pointer takes account of the size
    TestIds.current_configuration.allocator.store['pointers']['bins'].should == 11
    t = a(:t2)
    t[:bin].should == 12
    # Verify the pointer takes account of the size
    TestIds.current_configuration.allocator.store['pointers']['bins'].should == 16
    t = a(:t3)
    t[:bin].should == 17
    t = a(:t4)
    t[:bin].should == 22
    t = a(:t5)
    t[:bin].should == 10
    t = a(:t6)
    t[:bin].should == 15
  end

  #it "existing test IDs can be checked for compliance and re-assigned if non-compliant" do
  #  TestIds.configure do |config|
  #    config.bins.include << (1..3)
  #  end
  #  a(:t1)[:bin].should == 1
  #  a(:t2)[:bin].should == 2
  #  a(:t3)[:bin].should == 3
  #  a(:t4)[:bin].should == 1
  #  a(:t4)[:bin].should == 1
  #  a(:t5)[:bin].should == 2

  #  TestIds.reconfigure do |config|
  #    config.bins.include << (11..13)
  #  end

  #  # Verify that the original allocations are still around
  #  a(:t1)[:bin].should == 1
  #  a(:t2)[:bin].should == 2
  #  a(:t3)[:bin].should == 3
  #  a(:t4)[:bin].should == 1
  #  a(:t4)[:bin].should == 1
  #  a(:t5)[:bin].should == 2

  #  TestIds.reallocate_non_compliant = true

  #  a(:t1)[:bin].should == 11
  #  a(:t2)[:bin].should == 12
  #  a(:t3)[:bin].should == 13
  #  a(:t4)[:bin].should == 11
  #  a(:t4)[:bin].should == 11
  #  a(:t5)[:bin].should == 12
  #end
end
