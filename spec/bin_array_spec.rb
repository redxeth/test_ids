require "spec_helper"

describe "A Bin Array" do

  it 'min and max works' do
    b = TestIds::BinArray.new
    b << 100
    b.min.should == 100
    b.max.should == 100

    b << (200..300)
    b.min.should == 100
    b.max.should == 300

    b << (20..50)
    b.min.should == 20
    b.max.should == 300
  end

  it "the next method works" do
    b = TestIds::BinArray.new
    b << 10
    b << (15..20)
    b << 30

    b.next.should == 10
    b.next.should == 15
    b.next.should == 16
    b.next(18).should == 19
    b.next.should == 20
    b.next.should == 30
    b.next.should == 10
    b.next(13).should == 15
    b.next(25).should == 30
    b.next(100).should == 10
  end

  it "the include? method works" do
    b = TestIds::BinArray.new
    b << 10
    b << (15..20)
    b << 30

    b.include?(5).should == false
    b.include?(10).should == true
    b.include?(14).should == false
    b.include?(15).should == true
    b.include?(19).should == true
    b.include?(20).should == true
    b.include?(21).should == false
    b.include?(30).should == true
    b.include?(31).should == false
  end
end
