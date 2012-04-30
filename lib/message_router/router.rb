class MessageRouter
  class Router

    # Class Methods #
    def self.build &block
      router = Router.new
      router.instance_eval &block
      router
    end


    # Instance Methods #
    def initialize
      @rules = []
    end

    # Returns nil if no rules match
    # Returns true if a rule matched
    # NOTE: It is assumed that a rule failed to match if the 'do_this' block
    #       returns nil or false. This allows us to mount sub-routers and
    #       continue trying other rules if those subrouters fail to match
    #       something.
    def call(message)
      @rules.detect do |should_i, do_this|
        if should_i.call(message)
          return true if do_this.call message
        end
      end
    end


    private

    def match should_i, do_this
      case should_i
      when Regexp, String
        match({:body => should_i}, do_this)

      when TrueClass, FalseClass, NilClass
        match(Proc.new { should_i }, do_this)

      when Symbol
        match(Proc.new do |message|
          if self.method(should_i).arity == 0
            # Method won't accept arguments
            self.send should_i
          else
            # Method will accept arguments. Try sending the message.
            self.send should_i, message
          end
        end, do_this)

      when Hash
        match(Proc.new do |message|
          should_i.all? do |key, val|
            case val
            when String
              message[key] == val
            when Regexp
              message[key] =~ val
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
