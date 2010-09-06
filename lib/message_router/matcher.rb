class MessageRouter
  class Matcher
    
    def initialize(*args, &block)
      @params, @block = normalize_params(*args), block
    end
    
    # Check if all the keys and expression values match the message
    def match(message)
      params.inject({}) do |memo, (key,expression)|
        break unless message.include?(key) # Get out of here if the key isn't even around
        
        case expression
        when Regexp # Grap the regexp captures
          if match = message[key].match(expression)
            memo[key] = match.captures
          end
        else # Capture the values, similar to how a regexp would be captured
          memo[key] = Array(message[key]) if message[key] == expression
        end
        
        memo[key] ? memo : break
      end
    end
    
    def call(router)
      if match = match(router.message)
        router.instance_exec(*match[self.class.default_param], &block)
      end
    end
    
    def self.default_param
      :body
    end
    
  private
    attr_reader :params, :block
  
    def normalize_params(*args)
      if args.size == 2
        args.last.merge(self.class.default_param => args.first)
      elsif args.size == 1 and args.first.is_a?(Hash)
        args.first
      elsif args.size == 1
        { self.class.default_param => args.first }
      end
    end
  end
end