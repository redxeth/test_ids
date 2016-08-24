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
  end

end
