require "spec_helper"

describe "The test ID allocator" do

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
      config.bins.include << 3
      config.repo = nil
    end
    a(:t1)[:bin].should == 3
    a(:t2)[:bin].should == 3
    a(:t3)[:bin].should == 3
  end

  it "bin numbers increment" do
    TestIds.configure do |config|
      config.bins.include << (1..3)
      config.repo = nil
    end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 2
    a(:t3)[:bin].should == 3
  end

  it "duplicate tests pick up the same bin number" do
    TestIds.configure do |config|
      config.bins.include << (1..3)
      config.repo = nil
    end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 2
    a(:t1)[:bin].should == 1
    a(:t3)[:bin].should == 3
    a(:t4)[:bin].should == 1
  end

  it "caller can override bin number" do
    TestIds.configure do |config|
      config.bins.include << (1..4)
      config.repo = nil
    end
    a(:t1)[:bin].should == 1
    a(:t2, bin: 3)[:bin].should == 3
  end

  it "manually assigned bins are reserved" do
    TestIds.configure do |config|
      config.bins.include << (1..4)
      config.repo = nil
    end
    a(:t1)[:bin].should == 1
    a(:t2, bin: 3)[:bin].should == 3
    a(:t3)[:bin].should == 2
    a(:t4)[:bin].should == 4
  end

  it "the system can be saved to a file and resumed" do
    TestIds.configure do |config|
      config.bins.include << (1..4)
      config.repo = f
    end
    a(:t1)[:bin].should == 1
    a(:t2, bin: 3)[:bin].should == 3
    
    TestIds.allocator.save
    TestIds.__reset__
    TestIds.configure do |config|
      config.bins.include << (1..4)
      config.repo = f
    end
    a(:t3)[:bin].should == 2
    a(:t4)[:bin].should == 4
  end

end
