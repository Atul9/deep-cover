require "spec_helper"

module DeepCover
  RSpec.describe Tools::Memoize do
    class Test
      attr_reader :val
      def initialize
        @val = 0
      end

      def foo
        @val += 1
      end

      def more(arg = 0)
        foo + arg
      end

      def step(arg)
        @val += arg
      end
    end
    Tools.memoize Test

    class TestFrozen < Test
      def initialize
        super
        freeze
      end
    end

    describe "Hot class" do
      it { Test.memoized.should =~ [:foo, :more, :val] }
      it { Test.new.val.should == 0 }
      it 'is memoized' do
        t = Test.new
        t.foo.should == 1
        t.foo.should == 1
        t.step(42).should == 43
        t.step(42).should == 85
        t.more.should == 1
        t.more.should == 1
        t.more(42).should == 43
        t.more(42).should == 43
      end
    end

    describe "Frozen class" do
      it { TestFrozen.memoized.should =~ [:foo, :more, :val] }
      it { TestFrozen.new.val.should == 0 }
      it 'is memoized' do
        t = TestFrozen.new
        t.foo.should == 1
        t.foo.should == 1
        -> { t.step(42) }.should raise_error(RuntimeError)
        t.more.should == 1
        t.more.should == 1
        t.more(42).should == 43
        t.more(42).should == 43
      end
    end
  end
end
