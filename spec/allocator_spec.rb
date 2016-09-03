require "spec_helper"

describe "The test ID allocator" do

  before :each do
    TestIds.reset
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

  it "bin numbers increment, then wrap around" do
    TestIds.configure do |config|
      config.bins.include << (1..3)
      config.repo = nil
    end
    a(:t1)[:bin].should == 1
    a(:t2)[:bin].should == 2
    a(:t3)[:bin].should == 3
    a(:t4)[:bin].should == 1
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

end
