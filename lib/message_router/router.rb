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
    def call(message)
      @rules.detect do |should_i, do_this|
        if should_i.call(message)
          do_this.call message
          return true
        end
      end
    end


    private

    def match should_i, do_this
      case should_i
      when Regexp
        match(Proc.new { |message| message[:body] && message[:body] =~ should_i }, do_this)
      when String
        match(Proc.new { |message| message[:body] && message[:body] == should_i }, do_this)
      when TrueClass, FalseClass
        match(Proc.new { should_i }, do_this)
      else
        # Assume it already responds to #call.
        @rules << [should_i, do_this]
      end
    end
  end
end
