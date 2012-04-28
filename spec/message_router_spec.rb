require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

# TODO: Maybe move this into a sub-directory
describe MessageRouter::Router do

  describe ".build" do
    it "returns a Router" do
      r = MessageRouter::Router.build {}
      r.should be_kind_of MessageRouter::Router
    end

    describe 'defining matchers' do
      before do
        # For use in confirming whether or not a proc was called.
        $thing_to_match = $did_it_run = nil
      end

      let :message do
        {
          :body => 'hello world',
          :from => '15554443333',
          :to   => '12345'
        }
      end

      # This needs to be a method (and not memoized by #let) so that
      # $thing_to_match can change within a test.
      def router
        MessageRouter::Router.build do
          match($thing_to_match, lambda { $did_it_run = true } )

          # Using these methods also proves that the message is optionally
          # accessable by helper methods.
          def always_true(message)
            message[:body] == 'hello world'
          end
          def always_false
            false
          end
        end
      end

      let :the_test do
        Proc.new do |opts|
          $thing_to_match = opts[:true]
          router.call(message)
          $did_it_run.should == true
          $did_it_run = nil # reset for next time

          $thing_to_match = opts[:false]
          router.call(message)
          $did_it_run.should == nil
          $did_it_run = nil # reset for next time
        end
      end

      it 'accepts a boolean' do
        the_test.call :true => true, :false => false
      end

      it 'accepts a proc which is passed the message' do
        the_test.call(
          :true  => Proc.new {|msg| msg[:to] == '12345'},
          :false => Proc.new {|msg| msg[:to] == '54321'}
        )
      end

      it 'accepts a regex to match against the message body' do
        the_test.call :true => /hello/, :false => /bye bye/
      end

      it 'accepts a string to match against the message body' do
        the_test.call :true => 'hello world', :false => 'hello'
      end

      it 'accepts a symbol which is a method name' do
        the_test.call :true => :always_true, :false => :always_false
      end

      describe 'matching a hash' do
        it 'accepts a string to match against the hash key' do
          the_test.call(
            :true => {
              :from => '15554443333',
              :to   => '12345'
            },
            :false => {
              :from => 'something-else',
              :to   => '12345'
            }
          )
        end
        it 'accepts a regex to match against the hash key' do
          the_test.call(
            :true => {
              :from => /\A1555\d{7}\Z/,
              :to   => /\A\d{5}\Z/
            },
            :false => {
              :from => /\A1555\d{7}\Z/,
              :to   => /\A\d{6}\Z/
            }
          )
        end
      end
    end
  end

  describe "#call" do
    it "returns nil with no rules" do
      r = MessageRouter::Router.build {}
      r.call({}).should be_nil
    end

    context 'a rule matches' do
      subject do
        MessageRouter::Router.build do
          match(true, lambda { $did_it_run = true } )
        end
      end

      it "returns true when a rule matches" do
        subject.call({}).should be_true
      end

      it "calls the matcher's code" do
        subject.call({})
        $did_it_run.should be_true
      end
    end

    it 'supports nested routers' do
      pending
      main_router = MessageRouter::Router.build do
        sub_router = MessageRouter::Router.build do
          match
        end
      end

    end
  end
end
