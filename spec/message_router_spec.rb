require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

# TODO: Maybe move this into a sub-directory
describe MessageRouter::Router do

  describe ".build" do
    it "returns a Router" do
      r = MessageRouter::Router.build {}
      r.should be_kind_of MessageRouter::Router
    end

    describe 'defining matchers' do
      describe '1st argument' do
        before do
          # For use in confirming whether or not a proc was called.
          $thing_to_match = $did_it_run = nil
        end

        let :env do
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
            match($thing_to_match) { $did_it_run = true }

            # Using these methods also proves that the message is optionally
            # passed to helper methods.
            def always_true(env)
              env[:body] == 'hello world'
            end
            def always_false
              false
            end
          end
        end

        let :the_test do
          Proc.new do |opts|
            $thing_to_match = opts[:true]
            router.call(env)
            $did_it_run.should == true
            $did_it_run = nil # reset for next time

            $thing_to_match = opts[:false]
            router.call(env)
            $did_it_run.should == nil
            $did_it_run = nil # reset for next time
          end
        end

        it 'accepts a boolean' do
          the_test.call :true => true, :false => false
        end

        it 'accepts a nil' do
          # True is just here as a placeholder
          the_test.call :true => true, :false => nil
        end

        it 'accepts a proc which is passed the env' do
          the_test.call(
            :true  => Proc.new {|env| env[:to] == '12345'},
            :false => Proc.new {|env| env[:to] == '54321'}
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
                :to   => /i don't match/
              }
            )
          end
        end
      end

      describe '2nd argument' do
        it 'accepts a Proc' do
          env = {}
          router = MessageRouter::Router.build do
            match(true, Proc.new { |env| env[:did_it_run] = true })
          end
          router.call env
          env[:did_it_run].should be_true
        end

        it 'accepts a block' do
          env = {}
          router = MessageRouter::Router.build do
            match(true) { |env| env[:did_it_run] = true }
          end
          router.call env
          env[:did_it_run].should be_true
        end

        it 'raises an execption when both a Proc and a block are given' do
          lambda {
            router = MessageRouter::Router.build do
              match(true, Proc.new { |env| env[:did_it_run] = true }) { |env| env[:did_it_run] = true }
            end
          }.should raise_error(ArgumentError)
        end

        it 'raises an execption when neithr a Proc nor a block are given' do
          lambda {
            router = MessageRouter::Router.build do
              match true
            end
          }.should raise_error(ArgumentError)
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
          match(true) { $did_it_run = true }
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

    describe 'nested routers' do
      def main_router
        MessageRouter::Router.build do
          sub_router = MessageRouter::Router.build do
            match($inner_matcher) { $did_inner_run = true }
          end

          match $outer_matcher do |env|
            $did_outer_run = true
            sub_router.call(env)
          end
        end
      end

      before do
        $outer_matcher = $inner_matcher = $did_outer_run = $did_inner_run = nil
      end

      it 'runs both when both match' do
        $outer_matcher = $inner_matcher = true

        main_router.call({}).should be_true
        $did_outer_run.should be_true
        $did_inner_run.should be_true
      end

      it "runs outer only when outer matches and inner doesn't" do
        $outer_matcher = true
        $inner_matcher = false

        main_router.call({}).should be_nil
        $did_outer_run.should be_true
        $did_inner_run.should be_nil
      end

      it "runs neither when inner matches and outer doesn't" do
        $outer_matcher = false
        $inner_matcher = true

        main_router.call({}).should be_nil
        $did_outer_run.should be_nil
        $did_inner_run.should be_nil
      end

      context 'multiple inner matchers' do
        before do
          $outer_matcher_1 = $outer_matcher_2 = $inner_matcher_1 = $inner_matcher_2 = $did_outer_run_1 = $did_outer_run_2 = $did_inner_run_1 = $did_inner_run_2 = nil
        end

        def main_router
          MessageRouter::Router.build do
            # Define them
            sub_router_1 = MessageRouter::Router.build do
              match($inner_matcher_1) { $did_inner_run_1 = true }
            end
            sub_router_2 = MessageRouter::Router.build do
              match($inner_matcher_2) { $did_inner_run_2 = true }
            end

            # 'mount' them
            match $outer_matcher_1 do |env|
              $did_outer_run_1 = true
              sub_router_1.call(env)
            end

            match $outer_matcher_2 do |env|
              $did_outer_run_2 = true
              sub_router_2.call(env)
            end
          end
        end

        it "runs only 1st outer and 1st inner when all match" do
          $outer_matcher_1 = $outer_matcher_2 = $inner_matcher_1 = $inner_matcher_2 = true

          main_router.call({}).should be_true
          $did_outer_run_1.should be_true
          $did_outer_run_2.should be_nil
          $did_inner_run_1.should be_true
          $did_inner_run_2.should be_nil
        end

        it "runs both outers, and 2nd inner when all but 1st inner match" do
          $outer_matcher_1 = $outer_matcher_2 = $inner_matcher_2 = true
          $inner_matcher_1 = false

          main_router.call({}).should be_true
          $did_outer_run_1.should be_true
          $did_outer_run_2.should be_true
          $did_inner_run_1.should be_nil
          $did_inner_run_2.should be_true
        end

      end
    end


    describe 'helper methods' do
      module MyTestHelper
        LOOKUP = {
          1 => 'John',
          2 => 'Jim',
          3 => 'Jules'
        }
        def lookup_human_name(env)
          env[:human_name] = LOOKUP[env[:id]]
        end
      end

      it 'can modify the env' do
        router = MessageRouter::Router.build do
          extend MyTestHelper
          match :lookup_human_name do |env|
            $is_john = env[:human_name] == 'John'
          end
        end

        env = {:id => 1}
        router.call(env).should be_true
        $is_john.should be_true               # Prove the inner matcher can see the new value
        env[:human_name].should == 'John' # Prove we can get at the value after the router has finished.
      end
    end
  end
end
