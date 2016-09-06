require "spec_helper"

describe "The number allocator" do

  before :each do
    TestIds.send(:reset)
    FileUtils.rm(f) if File.exist?(f)
  end

  def f
    "#{Origen.root}/tmp/store.json"
  end

  def a(name, options = {})
    TestIds.allocator.allocate(name, options)
    options
  end

  it "is alive" do
    TestIds.configure do |config|
      config.numbers.include << 3
      config.repo = nil
    end
    a(:t1)[:number].should == 3
  end

  it "number numbers increment" do
    TestIds.configure do |config|
      config.numbers.include << (1..3)
      config.repo = nil
    end
    a(:t1)[:number].should == 1
    a(:t2)[:number].should == 2
    a(:t3)[:number].should == 3
  end

  it "duplicate tests pick up the same number number" do
    TestIds.configure do |config|
      config.numbers.include << (1..3)
      config.repo = nil
    end
    a(:t1)[:number].should == 1
    a(:t2)[:number].should == 2
    a(:t1)[:number].should == 1
    a(:t3)[:number].should == 3
  end

  it "caller can override number number" do
    TestIds.configure do |config|
      config.numbers.include << (1..4)
      config.repo = nil
    end
    a(:t1)[:number].should == 1
    a(:t2, number: 3)[:number].should == 3
  end

  it "manually assigned numbers are reserved" do
    TestIds.configure do |config|
      config.numbers.include << (1..4)
      config.repo = nil
    end
    a(:t1)[:number].should == 1
    a(:t2, number: 3)[:number].should == 3
    a(:t3)[:number].should == 2
    a(:t4)[:number].should == 4
  end

  it "excluded numbers are not used" do
    TestIds.configure do |config|
      config.numbers.include << (1..4)
      config.numbers.exclude << 3
      config.repo = nil
    end
    a(:t1)[:number].should == 1
    a(:t2)[:number].should == 2
    a(:t3)[:number].should == 4
  end

  it "the system can be saved to a file and resumed" do
    TestIds.configure do |config|
      config.numbers.include << (1..4)
      config.repo = f
    end
    a(:t1)[:number].should == 1
    a(:t2, number: 3)[:number].should == 3
    
    TestIds.allocator.save
    TestIds.send(:reset)
    TestIds.configure do |config|
      config.numbers.include << (1..4)
      config.repo = f
    end
    a(:t3)[:number].should == 2
    a(:t4)[:number].should == 4
  end

  it "previously assigned manual numbers are reclaimed next time" do
    TestIds.configure do |config|
      config.numbers.include << (1..4)
      config.repo = f
    end
    a(:t1)[:number].should == 1
    a(:t2)[:number].should == 2
    a(:t3, number: 2)[:number].should == 2
    
    TestIds.allocator.save
    TestIds.send(:reset)
    TestIds.configure do |config|
      config.numbers.include << (1..4)
      config.repo = f
    end
    a(:t1)[:number].should == 1
    a(:t2)[:number].should == 3
    a(:t3, number: 2)[:number].should == 2
  end

  it "when all numbers are used they will be re-used oldest first" do
    TestIds.configure do |config|
      config.numbers.include << (1..3)
      config.repo = f
    end
    a(:t1)[:number].should == 1
    a(:t2)[:number].should == 2
    a(:t3)[:number].should == 3
    a(:t4)[:number].should == 1
    a(:t4)[:number].should == 1
    a(:t5)[:number].should == 2

    TestIds.send(:reset)
    TestIds.configure do |config|
      config.numbers.include << (1..3)
      config.repo = f
    end
    a(:t1)[:number].should == 1
    a(:t2)[:number].should == 2
    a(:t3)[:number].should == 3
    a(:t1)[:number].should == 1  # More recent reference makes 2 the oldest
    a(:t4)[:number].should == 2

    TestIds.allocator.save
    TestIds.send(:reset)
    TestIds.configure do |config|
      config.numbers.include << (1..3)
      config.repo = f
    end
    a(:t1)[:number].should == 1
    a(:t2)[:number].should == 2
    a(:t3)[:number].should == 3
    a(:t1)[:number].should == 1  # More recent reference makes 2 the oldest
    a(:t4)[:number].should == 2
    a(:t5)[:number].should == 3
  end

  it "the numbers can be generated from an algorithm" do
    TestIds.configure do |config|
      config.bins.include << (1..3)
      config.softbins.include << (500..600)
      config.numbers.algorithm = :bbbsss000
    end
    t = a(:t1)
    t[:bin].should == 1
    t[:softbin].should == 500
    t[:number].should == 1500000
    t = a(:t2)
    t[:bin].should == 2
    t[:softbin].should == 501
    t[:number].should == 2501000
    t = a(:t3)
    t[:bin].should == 3
    t[:softbin].should == 502
    t[:number].should == 3502000
  end

  it "algorithm based numbers can include an increment counter" do
    TestIds.configure do |config|
      config.bins.include << 3
      config.softbins.include << 2
      config.numbers.algorithm = "5bbbsssx"
    end
    a(:t0)[:number].should == 50030020
    a(:t1)[:number].should == 50030021
    a(:t2)[:number].should == 50030022
    a(:t3)[:number].should == 50030023
    a(:t4)[:number].should == 50030024
    a(:t5)[:number].should == 50030025
    a(:t6)[:number].should == 50030026
    a(:t7)[:number].should == 50030027
    a(:t8)[:number].should == 50030028
    a(:t9)[:number].should == 50030029
    # Bump these up the reference table
    a(:t0)[:number].should == 50030020
    a(:t1)[:number].should == 50030021
    a(:t2)[:number].should == 50030022
    # The first duplicate
    a(:t10)[:number].should == 50030023
  end

  it "the numbers can be generated from a callback" do
    TestIds.configure do |config|
      config.bins.include << (1..3)
      config.softbins.include << (500..600)
      config.numbers.callback do |bin, softbin|
        bin + softbin
      end
    end
    t = a(:t1)
    t[:bin].should == 1
    t[:softbin].should == 500
    t[:number].should == 501
    t = a(:t2)
    t[:bin].should == 2
    t[:softbin].should == 501
    t[:number].should == 503
    t = a(:t3)
    t[:bin].should == 3
    t[:softbin].should == 502
    t[:number].should == 505
  end
end
