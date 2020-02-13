require 'json'
require 'logger'
require_relative 'app/slack_bot'

def mail_handler(lambda_event:, lambda_context:, logger:)
  @slack_bot ||= SlackBot::Core.new()

  if true
    @slack_bot.router.handle(lambda_event: lambda_event, lambda_context: lambda_context, logger: logger)
  else
    logger.error("api key is invalid!")
    { statusCode: 400, body: 'apikey is invalid or not exist' }
  end
end

def lambda_handler(event:, context:)
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG
  @call_count ||= 0
  @call_count += 1
  logger.debug("Eevent: #{event}")
  logger.debug("CallCount: #{@call_count}")

  if event['Records']
    event['Records'].each do |record|
      if record['eventSource'] == 'aws:ses'
        mail_handler(lambda_event: record['ses'], lambda_context: context, logger: logger)
      end
    end
  end
end
