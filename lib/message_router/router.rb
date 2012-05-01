class MessageRouter
  class Router

    # The main method for defining a router. Use this instead of .new.
    # An example:
    #     MyApp::Router::Application = MessageRouter::Router.build do
    #       # Share helpers between routers by extending modules
    #       extend MyApp::Router::MyHelper
    #
    #       match(lamba { |env| env[:from].nil? }) do |env|
    #         Logger.error "Can't reply when when don't know who a message is from: #{env.inspect}"
    #       end
    #
    #       match 'ping' do |env|
    #         PingCounter.increment!
    #         send_reply 'pong', env
    #       end
    #
    #       match /\Ahelp/i do |env|
    #         SupportQueue.contact_asap(env[:from])
    #         send_reply 'Looks like you need some help. Hold tight someone will call you soon.', env
    #       end
    #
    #       # StopRouter would have been defined just like this router.
    #       match /\Astop/i, MyApp::Router::StopRouter
    #
    #       match :to => /(12345|54321)/ do |env|
    #         Logger.warn "Use of deprecated short code: #{msg.inspect}"
    #         send_reply "Sorry, you are trying to use a deprecated short code. Please try again.", env
    #       end
    #
    #       match :user_name do |env|
    #         send_reply "I found you! Your name is #{user_name}.", env
    #       end
    #
    #       match true do |env|
    #         UserMessage.create! env
    #         send_reply "Sorry we couldn't figure out how to handle your message. We have recorded it and someone will get back to you soon.", env
    #       end
    #
    #
    #       def send_reply(body, orig_msg)
    #         OutgoingMessage.deliver!(:body => body, :to => orig_msg[:from], :from => orig_msg[:to])
    #       end
    #
    #       def user_name(env)
    #         env[:user_name] ||= User.find(env[:from])
    #       end
    #     end
    #
    #     MyApp::Router::Application.call({})  # Logs an error about not knowing who the message is from
    #     MyApp::Router::Application.call({:from => 'mr-smith', :body => 'ping'})  # Sends a 'pong' reply
    #     MyApp::Router::Application.call({:from => 'mr-smith', :to => 12345})  # Sends a deprecation warning reply
    #
    # The 1st argument to a matcher can be:
    # * true, false, or nil
    # * String or Regexp, which match against env[:body]. Strings require
    #   an exact match.
    # * Hash - Keys are expected to be a subset of the env's keys. The
    #   values are String or Regexp to be match again the corresponding value
    #   in the env Hash. Again, Strings require an exact match.
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
    def self.build &block
      router = Router.new
      router.instance_eval &block
      router
    end


    def initialize
      @rules = []
    end

    # Kicks off the router. 'env' is a Hash. The keys are up to the user;
    # however, the default key (used when a matcher is just a String or Regexp)
    # is :body. If you don't specify this key, then String and Regexp matchers
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
      @rules.detect do |should_i, do_this|
        if should_i.call(env)
          return true if do_this.call env
        end
      end
    end


    private

    def match should_i, do_this=nil, &do_this_block
      if do_this && do_this_block
        raise ArgumentError, "You may not provide a block when a 2nd argument has been provided."
      elsif do_this.nil? && do_this_block.nil?
        raise ArgumentError, "You must provide either a block or a 2nd argument which responds to call."
      end

      do_this ||= do_this_block

      case should_i
      when Regexp, String
        # TODO: Consider making this default attribute configurable.
        match({:body => should_i}, do_this)

      when TrueClass, FalseClass, NilClass
        match(Proc.new { should_i }, do_this)

      when Symbol
        match(Proc.new do |env|
          if self.method(should_i).arity == 0
            # Method won't accept arguments
            self.send should_i
          else
            # Method will accept arguments. Try sending the env.
            self.send should_i, env
          end
        end, do_this)

      when Hash
        match(Proc.new do |env|
          should_i.all? do |key, val|
            case val
            when String
              env[key] == val
            when Regexp
              env[key] =~ val
            else
              raise "Unexpected value '#{val.inspect}'. Should be String or Regexp."
            end
          end
        end, do_this)

      else
        # Assume it already responds to #call.
        @rules << [should_i, do_this]
      end
    end
  end
end
