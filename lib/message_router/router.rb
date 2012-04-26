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
        if should_i
          do_this.call message
          return true
        end
      end
    end


    private

    def match should_i, do_this
      @rules << [should_i, do_this]
    end
  end
end
