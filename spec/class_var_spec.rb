require File.dirname(__FILE__) + '/spec_helper.rb'

describe Doodle, 'class attributes:' do
  temporary_constant :Foo, :Bar do
    before :each do
      class Foo < Doodle::Base
        has :ivar
        class << self
          has :cvar, :kind => Integer, :init => 1
        end
      end
      class Bar < Doodle::Base
      end
    end

    it 'should be possible to set a class var without setting an instance var' do
      proc { Foo.cvar = 42 }.should_not raise_error
      Foo.cvar.should == 42
    end

    it 'should be possible to set an instance variable without setting a class var' do
      proc { Foo.new :ivar => 42 }.should_not raise_error
    end
    
    it 'should be possible to set a class variable without setting an newly added instance var' do
      proc {
        foo = Bar.new
        class << Bar
          has :cvar, :init => 43
        end
        class Bar < Doodle::Base
          has :ivar
        end
        Bar.cvar = 44
      }.should_not raise_error
    end

    it 'should be possible to set a singleton variable without setting an instance var' do
      proc {
        class Bar < Doodle::Base
          has :ivar
        end
        foo = Bar.new :ivar => 42
        class << foo
          has :svar, :init => 43
        end
        foo.svar = 44
      }.should_not raise_error
    end

    it 'should be possible to set a singleton variable without setting a newly added instance var' do
      pending 'figuring out if this is a pathological case and if so how to handle it' do
        proc {
          foo = Bar.new
          class << foo
            has :svar, :init => 43
          end
          class Bar < Doodle::Base
            has :ivar
          end
          foo.svar = 44
        }.should_not raise_error
      end
    end
    
    it 'should validate class var' do
      proc { Foo.cvar = "Hello" }.should raise_error(Doodle::ValidationError)
    end

    it 'should be possible to read initialized class var' do
      #pending 'getting this working' do
        proc { Foo.cvar == 1 }.should_not raise_error
      #end
    end
  end
end
