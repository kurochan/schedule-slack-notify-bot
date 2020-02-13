module SlackBot
  module Model
    class Context

      attr_reader :logger, :config, :lambda_event, :lambda_context, :s3, :client

      def initialize(logger:, config:, lambda_event:, lambda_context:, s3:, client:)
        @logger = logger
        @config = config
        @lambda_event = lambda_event
        @lambda_context = lambda_context
        @s3 = s3
        @client = client
      end
    end
  end
end
