require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

# TODO: Maybe move this into a sub-directory
describe MessageRouter::Router do

  describe 'defining matchers' do
    describe '1st argument' do
      before do
        # For use in confirming whether or not a proc was called.
        $thing_to_match = $did_it_run = nil
      end

      let :env do
        {
          'body' => 'hello world',
          'from' => '15554443333',
          'to'   => '12345'
        }
      end

      # This needs to be a method (and not memoized by #let) so that
      # $thing_to_match can change within a test.
      def router
        Class.new MessageRouter::Router do
          match($thing_to_match) { $did_it_run = true }

          # Using these methods also proves that the message is optionally
          # passed to helper methods.
          def always_true
            env['body'] == 'hello world'
          end
          def always_false
            false
          end
        end.new
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
          :true  => Proc.new { env['to'] == '12345'},
          :false => Proc.new { env['to'] == '54321'}
        )
      end

      it 'accepts a regex to match against the message body' do
        the_test.call :true => /hello/, :false => /bye bye/
      end

      it 'accepts a string to match against the 1st word in the message body' do
        the_test.call :true => 'hello', :false => 'hell'
      end

      context 'the default attribute has been over-written' do
        let(:router) do
          Class.new MessageRouter::Router do
            match('cheese') { env['result'] = 'i found cheese' }
            match(/bean/)   { env['result'] = 'magical fruit' }

            def default_attribute
              env['tacos']
            end
          end.new
        end

        it 'accepts a string to match against the 1st word in the default attribute' do
          env = { 'tacos' => 'cheese please' }
          router.call(env).should be_true
          env['result'].should == 'i found cheese'
        end
        it "does not match strings against the 'body' attribute" do
          env = { 'body' => 'cheese please' }
          router.call(env).should be_nil
        end

        it 'accepts a regex to match against the default attribute' do
          env = { 'tacos' => 'i like beans a lot' }
          router.call(env).should be_true
          env['result'].should == 'magical fruit'
        end
        it "does not match regex against the 'body' attribute" do
          env = { 'body' => 'i like beans a lot' }
          router.call(env).should be_nil
        end
      end

      it 'accepts a symbol which is a method name' do
        the_test.call :true => :always_true, :false => :always_false
      end

      it 'accepts an Array' do
        the_test.call :true => %w(only one of these needs to be the word hello), :false => %w(none of these match)
      end

      describe 'matching an Array' do
        it "doesn't run the 'do_this' block multiple times if there are multiple matches" do
          $run_count = 0
          router = Class.new(MessageRouter::Router) do
            match [true, true] do
              $run_count += 1
              nil # Return nil to ensure this matcher failed.
            end
          end.new

          router.call({})
          $run_count.should == 1
        end

        it "returns nil if the 'do_this' block returns nil" do
          $run_count = 0
          router = Class.new(MessageRouter::Router) do
            match [true, true] do
              $run_count += 1
              nil # Return nil to ensure this matcher failed.
            end
          end.new

          router.call({}).should == nil
        end

      end

      describe 'matching a hash' do
        it 'accepts a string to match against the hash key' do
          the_test.call(
            :true => {
              'from' => '15554443333',
              'to'   => '12345'
            },
            :false => {
              'from' => 'something-else',
              'to'   => '12345'
            }
          )
        end
        it 'accepts a regex to match against the hash key' do
          the_test.call(
            :true => {
              'from' => /\A1555\d{7}\Z/,
              'to'   => /\A\d{5}\Z/
            },
            :false => {
              'from' => /\A1555\d{7}\Z/,
              'to'   => /i don't match/
            }
          )
        end
        it 'accepts an Array to match against the hash key' do
          the_test.call(
            :true => {
              'from' => [/i don't match/, 'neither do i', 'but this last one does', /\A1555\d{7}\Z/],
              'to'   => [/i don't match/, 'neither do i', 'but this last one does', /\A\d{5}\Z/]
            },
            :false => {
              'from' => [/\A1555\d{7}\Z/, 'that last one did not match'],
              'to'   => [/i don't match/, 'neither do i']
            }
          )
        end

        it 'accepts keys that are missing (but is always false)' do
          $thing_to_match = {'i dont exist' => /.*/}
          router.call(env)
          $did_it_run.should == nil
          $did_it_run = nil # reset for next time
        end
      end
    end

    describe '2nd argument' do
      it 'accepts a Proc' do
        env = {}
        router = Class.new MessageRouter::Router do
          match(true, Proc.new { env['did_it_run'] = true })
        end.new
        router.call env
        env['did_it_run'].should be_true
      end

      it 'accepts a block' do
        env = {}
        router = Class.new MessageRouter::Router do
          match(true) { env['did_it_run'] = true }
        end.new
        router.call env
        env['did_it_run'].should be_true
      end

      it 'raises an execption when both a Proc and a block are given' do
        lambda {
          router = Class.new MessageRouter::Router do
            match(true, Proc.new { env['did_it_run'] = true }) { env['did_it_run'] = true }
          end.new
        }.should raise_error(ArgumentError)
      end

      it 'raises an execption when neither a Proc nor a block are given' do
        lambda {
          router = Class.new MessageRouter::Router do
            match true
          end.new
        }.should raise_error(ArgumentError)
      end
    end

    it 'defaults the 1st argument to true if only a block is given' do
      env = {}
      router = Class.new MessageRouter::Router do
        match { env['did_it_run'] = true }
      end.new
      router.call env
      env['did_it_run'].should be_true
    end

    it 'defaults the 1st argument to true if only a Proc is given' do
      env = {}
      router = Class.new MessageRouter::Router do
        match(Proc.new { env['did_it_run'] = true })
      end.new
      router.call env
      env['did_it_run'].should be_true
    end

    it 'accepts a Hash with a symbol as its only key and a Proc as its only value' do
      env = {}
      router = Class.new MessageRouter::Router do
        match :true_method => (Proc.new { env['did_it_run'] = true })
        def true_method; true; end
      end.new
      router.call env
      env['did_it_run'].should be_true
    end

    it 'raises an execption when no arguments and no block is given' do
      lambda {
        router = Class.new MessageRouter::Router do
          match
        end.new
      }.should raise_error(ArgumentError)
    end
  end


  describe "#call" do
    it "returns nil with no rules" do
      r = MessageRouter::Router.new
      r.call({}).should be_nil
    end

    context 'a rule matches' do
      subject do
        Class.new MessageRouter::Router do
          match(true) { env[:did_it_run] = true }
        end.new
      end

      it "returns true" do
        subject.call({}).should be_true
      end

      it "calls the matcher's code" do
        subject.call(env = {})
        env[:did_it_run].should be_true
      end
    end

    context 'there is a prerequisite which is true' do
      subject do
        Class.new MessageRouter::Router do
          prerequisite :true_method
          match(true) { env[:did_it_run] = true }
          def true_method; true; end
        end.new
      end

      it "returns true" do
        subject.call({}).should be_true
      end

      it "calls the matcher's code" do
        subject.call(env = {})
        env[:did_it_run].should be_true
      end
    end

    context 'there is a prerequisite which is false' do
      subject do
        Class.new MessageRouter::Router do
          prerequisite :false_method
          match(true) { env[:did_it_run] = true }
          def false_method; false; end
        end.new
      end

      it "returns false" do
        subject.call({}).should be_false
      end

      it "doesn't calls the matcher's code" do
        subject.call(env = {})
        env[:did_it_run].should_not be_true
      end
    end

    describe 'nested routers' do
      def main_router
        Class.new(MessageRouter::Router) do
          sub_router = Class.new(MessageRouter::Router) do
            match($inner_matcher) { $did_inner_run = true }
          end.new

          match $outer_matcher do
            $did_outer_run = true
            sub_router.call(env)
          end
        end.new
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
          Class.new MessageRouter::Router do
            # Define them
            sub_router_1 = Class.new MessageRouter::Router do
              match($inner_matcher_1) { $did_inner_run_1 = true }
            end.new
            sub_router_2 = Class.new MessageRouter::Router do
              match($inner_matcher_2) { $did_inner_run_2 = true }
            end.new

            # 'mount' them
            match $outer_matcher_1 do
              $did_outer_run_1 = true
              sub_router_1.call(env)
            end

            match $outer_matcher_2 do
              $did_outer_run_2 = true
              sub_router_2.call(env)
            end
          end.new
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
        def lookup_human_name
          env['human_name'] = LOOKUP[env['id']]
        end
      end

      let :router do
        Class.new MessageRouter::Router do
          include MyTestHelper
          match :lookup_human_name do
            $is_john = env['human_name'] == 'John'
          end

          match 'run_a' => 'block' do
            env['id'] = 2
            env['the_name'] = lookup_human_name
          end
          match({'run_a' => 'proc'}, Proc.new do
            env['id'] = 2
            env['the_name'] = lookup_human_name
          end)
          match({'run_a' => 'lambda'}, lambda do |args|
            env['id'] = 2
            env['the_name'] = lookup_human_name
          end)

          match(
            Proc.new do
              env['id'] = 3 if %w(proc lambda).include?(env['match_with'])
              lookup_human_name
            end
           ) { true }
        end.new
      end

      it 'can access/modify the env via #env' do
        env = {'id' => 1}
        router.call(env).should be_true
        $is_john.should be_true            # Prove the inner matcher can see the new value
        env['human_name'].should == 'John' # Prove we can get at the value after the router has finished.
      end

      it '#env is reset after #call has finished' do
        router.call({'id' => 1}).should be_true
        router.send(:env).should be_nil
      end

      %w(block proc lambda).each do |type|
        it "can be accessed from a #{type} that is the 2nd argument" do
          env = {'run_a' => type}
          router.call(env).should be_true
          env['the_name'].should == 'Jim'
        end
      end

      %w(proc lambda).each do |type|
        it "can be accessed from a #{type} that is the 1st argument" do
          env = {'match_with' => type}
          router.call(env).should be_true
          env['human_name'].should == 'Jules'
        end
      end
    end
  end
end
