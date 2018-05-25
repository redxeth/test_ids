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
    
    TestIds.config = :p1

    a(:t2)[:number].should == 1 * 100 + 10
    
    TestIds.with_config :p2 do
      a(:t2)[:number].should == 2 * 100 + 10
    end
    
    a(:t2)[:number].should == 1 * 100 + 10
  end

  it "you can use different configs for the different number types" do
      TestIds.configure id: :c1 do |config|
        config.bins.include << (10..19)
        config.softbins needs: :number do |options|
          options[:number] + 1
        end
        config.numbers = :bb110
      end

      TestIds.configure id: :c2 do |config|
        config.bins.include << (20..29)
        config.softbins needs: :number do |options|
          options[:number] + 2
        end
        config.numbers = :bb220
      end

      TestIds.configure id: :c3 do |config|
        config.bins.include << (30..39)
        config.softbins needs: :number do |options|
          options[:number] + 3
        end
        config.numbers = :bb330
      end

      TestIds.bin_config = :c3
      TestIds.softbin_config = :c1
      TestIds.number_config = :c2

      a(:t1)[:bin].should == 30
      a(:t1)[:softbin].should == 30221
      a(:t1)[:number].should == 30220

      a(:t2)[:bin].should == 31
      a(:t2)[:softbin].should == 31221
      a(:t2)[:number].should == 31220
  end
end
