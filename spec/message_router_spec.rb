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
        end
      end

      let :the_test do
        Proc.new do |opts|
          $thing_to_match = opts[:true]
          router.call(env)
          expect($did_it_run).to eq true
          $did_it_run = nil # reset for next time

          $thing_to_match = opts[:false]
          router.call(env)
          expect($did_it_run).to eq nil
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
          end
        end

        it 'accepts a string to match against the 1st word in the default attribute' do
          r = router.call({ 'tacos' => 'cheese please' })
          expect(r.matched?).to be_truthy
          expect(r.env['result']).to eq 'i found cheese'
        end
        it "does not match strings against the 'body' attribute" do
          r = router.call({ 'body' => 'cheese please' })
          expect(r.matched?).to be_falsey
        end

        it 'accepts a regex to match against the default attribute' do
          r = router.call({ 'tacos' => 'i like beans a lot' })
          expect(r.matched?).to be_truthy
          expect(r.env['result']).to eq 'magical fruit'
        end
        it "does not match regex against the 'body' attribute" do
          r = router.call({ 'body' => 'i like beans a lot' })
          expect(r.matched?).to be_falsey
        end
      end

      it 'accepts a symbol which is a method name' do
        the_test.call :true => :always_true, :false => :always_false
      end

      it 'accepts an Array' do
        the_test.call :true => %w(only one of these needs to be the word hello), :false => %w(none of these match)
      end

      describe 'matching an Array' do
        it "doesn't run the 'action' block multiple times if there are multiple matches" do
          run = double
          expect(run).to receive(:count).once
          router = Class.new(MessageRouter::Router) do
            match [true, true] do
              run.count
              not_matched
            end
          end
          r = router.call({})
          expect(r.matched?).to be_falsey
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
          expect($did_it_run).to eq nil
          $did_it_run = nil # reset for next time
        end
      end
    end

    describe '2nd argument' do
      it 'accepts a Proc' do
        env = {}
        router = Class.new MessageRouter::Router do
          match(true, Proc.new { env['did_it_run'] = true })
        end
        router.call env
        expect(env['did_it_run']).to be_truthy
      end

      it 'accepts a block' do
        env = {}
        router = Class.new MessageRouter::Router do
          match(true) { env['did_it_run'] = true }
        end
        router.call env
        expect(env['did_it_run']).to be_truthy
      end

      it 'raises an execption when both a Proc and a block are given' do
        expect {
          router = Class.new MessageRouter::Router do
            match(true, Proc.new { env['did_it_run'] = true }) { env['did_it_run'] = true }
          end
        }.to raise_error(ArgumentError)
      end

      it 'raises an execption when neither a Proc nor a block are given' do
        expect {
          router = Class.new MessageRouter::Router do
            match true
          end
        }.to raise_error(ArgumentError)
      end
    end

    it 'defaults the 1st argument to true if only a block is given' do
      env = {}
      router = Class.new MessageRouter::Router do
        match { env['did_it_run'] = true }
      end
      router.call env
      expect(env['did_it_run']).to be_truthy
    end

    it 'defaults the 1st argument to true if only a Proc is given' do
      env = {}
      router = Class.new MessageRouter::Router do
        match(Proc.new { env['did_it_run'] = true })
      end
      router.call env
      expect(env['did_it_run']).to be_truthy
    end

    it 'accepts a Hash with a symbol as its only key and a Proc as its only value' do
      env = {}
      router = Class.new MessageRouter::Router do
        match :true_method => (Proc.new { env['did_it_run'] = true })
        def true_method; true; end
      end
      router.call env
      expect(env['did_it_run']).to be_truthy
    end

    it 'raises an execption when no arguments and no block is given' do
      expect {
        router = Class.new MessageRouter::Router do
          match
        end
      }.to raise_error(ArgumentError)
    end
  end


  describe "#call" do
    it "does not match with no rules" do
      router = MessageRouter::Router.call({})
      expect(router.matched?).to be_falsey
    end

    context 'a rule matches' do
      subject do
        Class.new MessageRouter::Router do
          match(true) { env[:did_it_run] = true }
        end
      end

      it "returns true" do
        expect(subject.call({})).to be_truthy
      end

      it "calls the matcher's code" do
        subject.call(env = {})
        expect(env[:did_it_run]).to be_truthy
      end
    end

    context 'there is a prerequisite which is true' do
      subject do
        Class.new MessageRouter::Router do
          prerequisite :true_method
          match(true) { env[:did_it_run] = true }
          def true_method; true; end
        end
      end

      it "returns true" do
        expect(subject.call({})).to be_truthy
      end

      it "calls the matcher's code" do
        subject.call(env = {})
        expect(env[:did_it_run]).to be_truthy
      end
    end

    context 'there is a prerequisite which is false' do
      subject do
        Class.new MessageRouter::Router do
          prerequisite :false_method
          match(true) { env[:did_it_run] = true }
          def false_method; false; end
        end
      end

      it "returns false" do
        expect(subject.call({})).to be_falsey
      end

      it "doesn't calls the matcher's code" do
        subject.call(env = {})
        expect(env[:did_it_run]).to_not be_truthy
      end
    end

    describe 'mount routers' do
      it "can delegate to other routers" do
        sub_router = Class.new(MessageRouter::Router) do
          match do
            env['result'] = true
          end
        end

        main_router = Class.new(MessageRouter::Router) do
          mount sub_router
        end

        r = main_router.call({})
        expect(r.env['result']).to eq true
      end
    end

    describe "explicitly not matching" do
      let(:router) do
        Class.new(MessageRouter::Router) do
          match do
            not_matched
          end
        end
      end

      it "sets matched to false in env" do
        r = router.call({})
        expect(r.matched?).to be_falsey
      end
    end

    describe "explicitly matching" do
      let(:router) do
        Class.new(MessageRouter::Router) do
          match do
            not_matched
          end
          match do
            matched
          end
        end
      end

      it "sets matched to true in env" do
        r = router.call({})
        expect(r.matched?).to be_truthy
      end
    end

    describe 'nested routers' do
      def main_router
        Class.new(MessageRouter::Router) do
          attr_accessor :outer_matcher, :inner_matcher

          sub_router = Class.new(MessageRouter::Router) do
            attr_accessor :inner_matcher
            match(:inner_matcher) { env['did_inner_run'] = true }
          end

          match :outer_matcher do
            env['did_outer_run'] = true
            r = sub_router.new(env).tap do |r|
              r.inner_matcher = self.inner_matcher
            end.run
          end
        end
      end

      it 'runs both when both match' do
        r = main_router.new({}).tap do |r|
          r.outer_matcher = true
          r.inner_matcher = true
        end.run

        expect(r.env['did_outer_run']).to be_truthy
        expect(r.env['did_inner_run']).to be_truthy
      end

      it "runs outer only when outer matches and inner doesn't" do
        r = main_router.new({}).tap do |r|
          r.outer_matcher = true
          r.inner_matcher = false
        end.run
        expect(r.env['did_outer_run']).to be_truthy
        expect(r.env['did_inner_run']).to be_nil
      end

      it "runs neither when inner matches and outer doesn't" do
        $outer_matcher = false
        $inner_matcher = true

        r = main_router.new({}).tap do |r|
          r.outer_matcher = false
          r.inner_matcher = true
        end
        expect(r.env['did_outer_run']).to be_nil
        expect(r.env['did_inner_run']).to be_nil
      end

      context 'multiple inner matchers' do
        before do
          $outer_matcher_1 = $outer_matcher_2 = $inner_matcher_1 = $inner_matcher_2 = $did_outer_run_1 = $did_outer_run_2 = $did_inner_run_1 = $did_inner_run_2 = nil
        end

        def main_router
          Class.new MessageRouter::Router do
            # Define them
            sub_router_1 = Class.new MessageRouter::Router do
              match($inner_matcher_1) { env['did_inner_run_1'] = true }
            end
            sub_router_2 = Class.new MessageRouter::Router do
              match($inner_matcher_2) { env['did_inner_run_2'] = true }
            end

            # 'mount' them
            match $outer_matcher_1 => sub_router_1
            match $outer_matcher_2 => sub_router_2
          end
        end

        it "runs only 1st outer and 1st inner when all match" do
          $outer_matcher_1 = $outer_matcher_2 = $inner_matcher_1 = $inner_matcher_2 = true

          r = main_router.call({})
          expect(r.env['did_inner_run_1']).to eq true
          expect(r.env['did_inner_run_2']).to eq nil
        end

        it "runs both outers, and 2nd inner when all but 1st inner match" do
          $outer_matcher_1 = $outer_matcher_2 = $inner_matcher_2 = true
          $inner_matcher_1 = false

          r = main_router.call({})
          expect(r.env['did_inner_run_1']).to be_nil
          expect(r.env['did_inner_run_2']).to be_truthy
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
        end
      end

      it 'can access/modify the env via #env' do
        r = router.call({'id' => 1})
        expect(r.matched?).to be_truthy
        expect($is_john).to be_truthy            # Prove the inner matcher can see the new value
        expect(r.env['human_name']).to eq 'John' # Prove we can get at the value after the router has finished.
      end

      %w(block proc lambda).each do |type|
        it "can be accessed from a #{type} that is the 2nd argument" do
          r = router.call({'run_a' => type})
          expect(r.matched?).to be_truthy
          expect(r.env['the_name']).to eq 'Jim'
        end
      end

      %w(proc lambda).each do |type|
        it "can be accessed from a #{type} that is the 1st argument" do
          r = router.call({'match_with' => type})
          expect(r.matched?).to be_truthy
          expect(r.env['human_name']).to eq 'Jules'
        end
      end

      describe "instance variables" do
        let :router do
          Class.new MessageRouter::Router do
            prerequisite :helper_method

            match do
              env['result'] = @helper_method
            end

            private
            def helper_method
              @helper_method ||= 0
              @helper_method += 1
            end
          end
        end

        it "doesn't leak state to a 2nd run" do
          router.call({})
          r = router.call({})
          expect(r.env['result']).to eq 1
        end
      end
    end
  end
end
