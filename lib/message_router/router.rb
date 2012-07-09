class MessageRouter
  # To define a router, subclass MessageRouter::Router, then call #match
  # inside the class definition.
  # An example:
  #     class MyApp::Router::Application < MessageRouter::Router
  #       # Share helpers between routers by including modules
  #       include MyApp::Router::MyHelper
  #
  #       match SomeOtherRouter.new
  #       # `mount` is an alias of `match`
  #       mount AnotherRouter.new
  #
  #       match(lamba { env['from'].nil? }) do
  #         Logger.error "Can't reply when when don't know who a message is from: #{env.inspect}"
  #       end
  #
  #       match 'ping' do
  #         PingCounter.increment!
  #         send_reply 'pong', env
  #       end
  #
  #       match /\Ahelp/i do
  #         SupportQueue.contact_asap(env['from'])
  #         send_reply 'Looks like you need some help. Hold tight someone will call you soon.', env
  #       end
  #
  #       # StopRouter would have been defined just like this router.
  #       match /\Astop/i, MyApp::Router::StopRouter
  #
  #       match 'to' => /(12345|54321)/ do
  #         Logger.warn "Use of deprecated short code: #{msg.inspect}"
  #         send_reply "Sorry, you are trying to use a deprecated short code. Please try again.", env
  #       end
  #
  #       match :user_name do
  #         send_reply "I found you! Your name is #{user_name}.", env
  #       end
  #
  #       match %w(stop end quit), StopRouter.new
  #
  #       # Array elements don't need to be the same type
  #       match [
  #         :user_is_a_tester,
  #         {'to' => %w(12345 54321)},
  #         {'RAILS_ENV' => 'test'},
  #         'test'
  #       ], TestRouter.new
  #
  #       # Works inside a Hash too
  #       match 'from' => ['12345', '54321', /111\d\d/] do
  #         puts "'#{env['from']}' is a funny looking short code"
  #       end
  #
  #       match true do
  #         UserMessage.create! env
  #         send_reply "Sorry we couldn't figure out how to handle your message. We have recorded it and someone will get back to you soon.", env
  #       end
  #
  #
  #       def send_reply(body, env)
  #         OutgoingMessage.deliver!(:body => body, :to => env['from'], :from => env['to'])
  #       end
  #
  #       def user_name(env)
  #         env['user_name'] ||= User.find(env['from'])
  #       end
  #     end
  #
  #     router = MyApp::Router::Application.new
  #     router.call({})  # Logs an error about not knowing who the message is from
  #     router.call({'from' => 'mr-smith', 'body' => 'ping'})  # Sends a 'pong' reply
  #     router.call({'from' => 'mr-smith', 'to' => 12345})     # Sends a deprecation warning reply
  class Router

    class << self
      # The 1st argument to a matcher can be:
      # * true, false, or nil
      # * String or Regexp, which match against env['body']. Strings match against
      #   the 1st word.
      # * Array - Elements can be Strings or Regexps. They are matched against
      #   'body'. Matches if any element is matches.
      # * Hash - Keys are expected to be a subset of the env's keys. The
      #   values are String, Regexp, or Array to be match again the corresponding
      #   value in the env Hash. True if there is a match for all keys.
      # * Symbol - Calls a helper method of the same name. If the helper can take
      #   an argument, the env will be passed to it. The return value of the
      #   helper method determines if the matcher matches.
      # * Anything that responds to #call - It is passed the env as the only
      #   arugment. The return value determines if the matcher matches.
      # Because Routers are trigged by the method #call, one _could_ use a Router
      # as the 1st argument to a matcher. However, it would actually run that
      # Router's code, which is not intuitive, and therefore not recommonded.
      # If the 1st argument to a matcher resolves to a true value, then the 2nd
      # argument is sent `#call(env)`. If that also returns a true value,
      # then the matcher has "matched" and the router stops. However, if the 2nd
      # argument returns false, then the router will continue running. This
      # allows us to mount sub-routers and continue trying other rules if those
      # subrouters fail to match something.
      # The 2nd argument to #match can also be specified with a block.
      # If the 1st argument is skipped, then it is assumed to be true. This is
      # useful for passing a message to a sub-router, which will return nil if
      # it doesn't match. For example:
      #     match MyOtherRouter.new
      # is a short-hand for:
      #     match true, MyOtherRouter.new
      # It is important to keep in mind that blocks, procs, and lambdas, whether
      # they are the 1st or 2nd argument, will be run in the scope of the router,
      # just like the methods referenced by Symbols. That means that they have
      # access to all the helper methods. However, it also means they have the
      # ability to edit/add instance variables on the router; NEVER DO THIS. If
      # you want to use an instance variable inside a helper, block, proc, or
      # lambda, you MUST use the env hash instance. Examples:
      #     # BAD
      #     match :my_helper do
      #       @cached_user ||= User.find_by_id(@user_id)
      #     end
      #     def find_user
      #       @id ||= User.get_id_from_guid(env['guid'])
      #     end
      #
      #     # GOOD
      #     match :my_helper do
      #       env['cached_user'] ||= User.find_by_id(env['user_id'])
      #     end
      #     def find_user
      #       env['id'] ||= User.get_id_from_guid(env['guid'])
      #     end
      # If you do not follow this requirement, then when subsequent keywords are
      # routed, they will see the instance variables from the previous message.
      # In the case of the above example, every subsequent message will have
      # @cached_user set the the user for the 1st message.
      def match *args, &block
        args << block if block
        case args.size
        when 0
          raise ArgumentError, "You must provide either a block or an argument which responds to call."
        when 1
          if args[0].respond_to?(:call)
            do_this  = args[0]
            should_i = true
          else
            raise ArgumentError, "You must provide either a block or a 2nd argument which responds to call."
          end
        when 2
          should_i, do_this = args
          raise ArgumentError, "The 2nd argument must respond to call." unless do_this.respond_to?(:call)
        else
          raise ArgumentError, "Too many arguments. Note: you may not provide a block when a 2nd argument has been provided."
        end

        # Save the arguments for later.
        rules << [should_i, do_this]
      end
      alias :mount :match

      # The rules are defined at the class level. But any helper methods
      # referenced by Symbols are defined/executed at the instance level.
      def rules
        @rules ||= []
      end
    end


    # This method initializes all the rules stored at the class level. When you
    # create your subclass, if you want to add your own initializer, it is very
    # important to call `super` or none of your rules will be matched.
    def initialize
      @rules = []
      # Actually create the rules so that the procs we create are in the
      # context of an instance of this object. This is most important when the
      # rule is based on a symbol. We need that symbol to resolve to an
      # instance method; however, instance methods are not available until
      # after an instance is created.
      self.class.rules.each {|rule| match *rule }
    end

    # Kicks off the router. 'env' is a Hash. The keys are up to the user;
    # however, the default key (used when a matcher is just a String or Regexp)
    # is 'body'. If you don't specify this key, then String and Regexp matchers
    # will always be false.
    # Returns nil if no rules match
    # Returns true if a rule matches
    # A rule "matches" if both its procs return true. For example:
    #     match(true) { true }
    # matches. However:
    #     match(true) { false }
    # does not count as a match. This allows us to mount sub-routers and
    # continue trying other rules if those subrouters fail to match something.
    # However, this does mean you need to be careful when writing the 2nd
    # argument to #match. If you return nil or false, the router will keep
    # looking for another match.
    def call(env)
      # I'm pretty sure this is NOT thread safe. Having two threads use the
      # same router at the same time will almost certainly give you VERY weird
      # and incorrect results. We may want to introduce a RouterRun object to
      # encapsulate one invocation of this #call method.
      @env = env
      @rules.detect do |should_i, do_this|
        should_i = if should_i.kind_of?(Proc)
          self.instance_eval &should_i
        else
          should_i.call @env
        end

        if should_i
          do_this = if do_this.kind_of?(Proc)
            self.instance_eval &do_this
          else
            do_this.call @env
          end

          return true if do_this
        end
      end
    ensure
      @env = nil
    end


    private
    def env; @env; end

    def match(should_i, do_this)
      @rules << [normalize_match_params(should_i), do_this]
    end

    def normalize_match_params(should_i=nil, &block)
      should_i ||= block if block

      case should_i
      when Regexp, String
        # TODO: Consider making this default attribute configurable.
        normalize_match_params 'body' => should_i

      when TrueClass, FalseClass, NilClass
        Proc.new { should_i }

      when Symbol
        Proc.new do
          self.send should_i
        end

      when Array
        should_i = should_i.map {|x| normalize_match_params x}
        Proc.new do
          should_i.any? { |x| x.call env }
        end

      when Hash
        Proc.new do
          should_i.all? do |key, val|
            attr_matches? env[key], val
          end
        end

      else
        # Assume it already responds to #call.
        should_i
      end

    end

    def attr_matches?(attr, val)
      case val
      when String
        attr =~ /\A#{val}\b/i # Match 1st word
      when Regexp
        attr =~ val
      when Array
        val.any? do |x|
          attr_matches? attr, x
        end
      else
        raise "Unexpected value '#{val.inspect}'. Should be String, Regexp, or Array of Strings and Regexps."
      end
    end
  end
end
