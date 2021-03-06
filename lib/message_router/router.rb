class MessageRouter
  # To define a router, subclass MessageRouter::Router, then call #match
  # inside the class definition.
  # An example:
  #     class MyApp::Router::Application < MessageRouter::Router
  #       # Share helpers between routers by including modules
  #       include MyApp::Router::MyHelper
  #
  #       prerequisite :db_connected?
  #
  #       match SomeOtherRouter
  #       # `mount` is an alias of `match`
  #       mount AnotherRouter
  #
  #       match(lambda { env['from'].nil? }) do
  #         Logger.error "Can't reply when when don't know who a message is from: #{env.inspect}"
  #       end
  #
  #       # Matches if the first word of env['body'] is PING (case insensitive).
  #       # Overwrite #default_attribute in your router to match against a
  #       # different value.
  #       match 'ping' do
  #         PingCounter.increment!
  #         send_reply 'pong', env
  #       end
  #
  #       # Matches if env['body'] matches the given Regexp.
  #       # Overwrite #default_attribute in your router to match against a
  #       # different value.
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
  #       match :user_name => PriorityUsernameRouter
  #       match :user_name, OldStyleUsernameRouter
  #       match :user_name do
  #         send_reply "I found you! Your name is #{user_name}.", env
  #       end
  #
  #       match %w(stop end quit), StopRouter
  #
  #       # Array elements don't need to be the same type
  #       match [
  #         :user_is_a_tester,
  #         {'to' => %w(12345 54321)},
  #         {'RAILS_ENV' => 'test'},
  #         'test'
  #       ], TestRouter
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
  #
  #       def db_connected?
  #         Database.connected?
  #       end
  #     end
  #
  #     router = MyApp::Router::Application
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
          if args[0].respond_to?(:env)
            condition = true
            action  = args[0]
          elsif args[0].respond_to?(:call)
            condition = true
            action  = args[0]
          elsif args[0].kind_of?(Hash) && args[0].values.size == 1 && args[0].values[0].respond_to?(:call)
            # Syntactical suger to make:
            #     match :cool? => OnlyForCoolPeopleRouter
            # work just like:
            #     match :cool?, OnlyForCoolPeopleRouter
            condition = args[0].keys[0]
            action  = args[0].values[0]
          else
            raise ArgumentError, "You must provide either a block or a 2nd argument which responds to call."
          end
        when 2
          condition, action = args
          raise ArgumentError, "The 2nd argument must respond to call." unless action.respond_to?(:call)
        else
          raise ArgumentError, "Too many arguments. Note: you may not provide a block when a 2nd argument has been provided."
        end

        # Save the arguments for later.
        rules << [condition, action]
      end
      alias :mount :match

      # Defines a prerequisite for this router. Prerequisites are like rules,
      # except that if any of them don't match, the rest of the router is
      # skipped.
      # Anything that can be the 1st argument to `match` can be passed as an
      # argument to `prerequisite`.
      def prerequisite(arg=nil, &block)
        arg ||= block if block
        prerequisites << arg
      end

      # The rules are defined at the class level. But any helper methods
      # referenced by Symbols are defined/executed at the instance level.
      def rules
        @rules ||= []
      end

      def prerequisites
        @prerequisites ||= []
      end

      # Kicks off the router. 'env' is a Hash. The keys are up to the user;
      # however, the default key (used when a matcher is just a String or Regexp)
      # is 'body'. If you don't specify this key, then String and Regexp matchers
      # will always be false.
      # Returns a new instance of this class, that gets run before being returned
      # A rule "matches" if its condition return true and the action does not
      # explicitly call not_matched. For example:
      #     match(true) { }
      # matches. However:
      #     match(true) { not_matched }
      # does not count as a match. This allows us to mount sub-routers and
      # continue trying other rules if those subrouters fail to match something.
      def call(env)
        new(env).run
      end
    end


    # This method initializes all the rules stored at the class level. When you
    # create your subclass, if you want to add your own initializer, it is very
    # important to call `super` or none of your rules will be matched.
    def initialize(env) #:nodoc:
      @env = env.dup
      # a parent router may be assuming a successful match
      # but this subrouter may not, so we explicitly set it to not matched
      # on creation
      not_matched
      @rules = []
      # Actually create the rules so that the procs we create are in the
      # context of an instance of this object. This is most important when the
      # rule is based on a symbol. We need that symbol to resolve to an
      # instance method; however, instance methods are not available until
      # after an instance is created.
      self.class.rules.each {|rule| match *rule }

      @prerequisites = []
      self.class.prerequisites.each do |prerequisite|
        @prerequisites << normalize_match_params(prerequisite)
      end
    end

    def run #:nodoc:
      # All prerequisites must return true in order to continue.
      return self unless @prerequisites.all? do |condition|
        self.instance_eval &condition
      end

      @rules.detect do |condition, action|
        if self.instance_eval &condition
          matched
          r = self.instance_eval &action
          @env = r.respond_to?(:env) ? r.env : r
          return self if matched?
        end
      end

      self # always return router instance
    end

    def not_matched
      env['_matched'] = false
    end
    def matched
      env['_matched'] = true
    end
    def matched?
      !!env['_matched']
    end


    def env; @env; end
    private

    def match(condition, action)
      @rules << [normalize_match_params(condition), normalize_action(action)]
    end

    def normalize_action(action)
      if action.kind_of?(Proc) # This is true for blocks and lamdas too.
        Proc.new do
          self.instance_eval &action
          env
        end
      else
        Proc.new do
          action.call(env)
        end
      end
    end

    def normalize_match_params(condition=nil, &block)
      condition ||= block if block

      case condition
      when Regexp, String
        Proc.new { attr_matches? default_attribute, condition }

      when TrueClass, FalseClass, NilClass
        Proc.new { condition }

      when Symbol
        Proc.new do
          self.send condition
        end

      when Array
        condition = condition.map {|x| normalize_match_params x}
        Proc.new do
          condition.any? { |x| x.call env }
        end

      when Hash
        Proc.new do
          condition.all? do |key, val|
            attr_matches? env[key], val
          end
        end

      when Proc
        condition

      else
        # Assume it already responds to #call.
        Proc.new do
          condition.call env
        end
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

    def default_attribute
      env['body']
    end
  end
end
