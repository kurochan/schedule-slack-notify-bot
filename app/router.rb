require 'aws-sdk-s3'
require 'hashie'
require 'slack-ruby-client'
require_relative 'models/context'
require_relative 'mail_handler'

module SlackBot
  class Router

    CONFIG_RELATIVE_PATH = '../../conf/config.yml'

    def initialize()
      config_path = File.expand_path(CONFIG_RELATIVE_PATH, __FILE__)
      @config_all = Hashie::Mash.load(config_path)
    end

    def handle(lambda_event:, lambda_context:, logger:)

      logger.debug("lambda_event: #{lambda_event}")
      context = create_context(lambda_event, lambda_context, logger)
      mail_hander = SlackBot::MailHandler.new.handle(context: context)
    end

    def create_context(lambda_event, lambda_context, logger)

      s3 = Aws::S3::Client.new(region: @config_all.mail.s3.region)
      client = Slack::Web::Client.new(token: @config_all.slack.access_token)

      SlackBot::Model::Context.new(
        logger: logger,
        config: @config_all,
        lambda_event: lambda_event,
        lambda_context: lambda_context,
        s3: s3, 
        client: client
      )
    end
    private :create_context
  end
end
