class MessageRouter
  class Context
    def initialize(context_proc, &block)
      @block = block
      @context_proc = normalize_context_proc(context_proc)
    end
    
    def call(router)
      if args = context_proc.call(router)
        klass = Class.new(router.class)
        klass.instance_exec(*args, &block)
        klass.dispatch(router.message)
      end
    end
    
  private
    attr_reader :block, :context_proc
    
    def normalize_context_proc(proc)
      proc.is_a?(Proc) ? proc : Proc.new{|instance| instance.send(proc) }
    end
  end
end