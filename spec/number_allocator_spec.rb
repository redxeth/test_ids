require "spec_helper"

describe "The number allocator" do

  before :each do
    TestIds.__reset__
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
    TestIds.__reset__
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
    TestIds.__reset__
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

    TestIds.__reset__
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
    TestIds.__reset__
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
end
