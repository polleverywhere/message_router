$LOAD_PATH.unshift File.join(File.dirname(__FILE__))

class MessageRouter
  
  autoload :Context, 'message_router/context'
  autoload :Matcher, 'message_router/matcher'
  
  class << self
    def match(*args, &block)
      route Matcher.new(*args, &block)
    end
    
    def context(proc, &block)
      route Context.new(proc, &block)
    end
    
    def route(proc)
      routes.push proc
    end
    
    def routes
      @routes ||= []
    end
    
    def dispatch(message)
      new(message).dispatch
    end
  end
  
  attr_accessor :message, :halted_value
  
  def initialize(message)
    @message = message
  end
  
  def halt(val=nil)
    @halted = true
    @halted_value = val
  end

  def halted?
    @halted
  end

  # Iterate through all of the matchers, find the first one, and call the block on it.
  def dispatch
    self.class.routes.each do |route|
      # Break out of the loop if a match is found
      if match = route.call(self)
        return halted? ? halted_value : match
      end
    end
    return nil
  end
end