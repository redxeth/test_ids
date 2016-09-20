require "spec_helper"

describe "The multi-configurator" do

  before :each do
    TestIds.send(:reset)
  end

  def configs
    [:p1,:p2,:f1]
  end
  
  def a(name, options = {})
    TestIds.current_configuration.allocator.allocate(name, options)
    options
  end

  it "is alive" do
    i = 0
    configs.each do |cfg|
      i += 1
      TestIds.configure id: cfg do |config|
        config.softbins = i
        config.numbers = :sx0
      end
      a(:t1)[:number].should == i * 100
      a(:t2)[:number].should == i * 100 + 10
      a(:t3)[:number].should == i * 100 + 20
    end
  end

  it "current_configuration can be updated" do
    i = 0
    configs.each do |cfg|
      i += 1
      TestIds.configure id: cfg do |config|
        config.softbins = i
        config.numbers = :sx0
      end
      a(:t1)[:number].should == i * 100
    end
  
    a(:t2)[:number].should == 3 * 100 + 10
    
    TestIds.configure id: configs[0] do |config|
      # do nothing
    end

    a(:t2)[:number].should == 1 * 100 + 10
    
    TestIds.configure configs[1] do |config|
      # do nothing
    end

    a(:t2)[:number].should == 2 * 100 + 10
    
  end


end
