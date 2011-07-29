class MessageRouter
  # Mount routers inside of routers.
  class Mount
    def initialize(mounted_router_klass)
      @mounted_router_klass = mounted_router_klass
    end

    def call(router)
      mounted_router = mounted_router_klass.new(router.message)
      response = mounted_router.dispatch
      # If the mounted router was halted, halt this router and pass through the response
      mounted_router.halted? ? router.halt(response) : response
    end

  private
    attr_reader :mounted_router_klass
  end
end