require "message_router/version"

class MessageRouter

  autoload :Context,  'message_router/context'
  autoload :Matcher,  'message_router/matcher'
  autoload :Mount,    'message_router/mount'

  class << self
    def match(*args, &block)
      route Matcher.new(*args, &block)
    end

    def context(proc, &block)
      route Context.new(proc, &block)
    end

    def mount(mounted_router_klass)
      route Mount.new(mounted_router_klass)
    end

    def routes
      @routes ||= []
    end

    def route(proc)
      routes.push proc
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
    !!@halted
  end

  # Iterate through all of the matchers, find the first one, and call the block on it.
  def dispatch
    self.class.routes.each do |route|
      # Break out of the loop if a match is found
      if match = route.call(self)
        return match
      elsif halted?
        return halted_value
      end
    end
    return nil # If nothing is matched, we get here and we should return a nil
  end
end