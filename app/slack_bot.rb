require_relative 'router'

module SlackBot
  class Core
    attr_reader :router

    def initialize(router: nil)
      @router = router || Router.new()
    end
  end
end
