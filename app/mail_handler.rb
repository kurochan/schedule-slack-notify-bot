require 'mail'

module SlackBot
  class MailHandler

    MARKER_TITLE = "\n[タイトル]\n"
    MARKER_SCHEDULE = "\n[期間]\n"
    MARKER_PLACE = "\n[施設]\n"
    MARKER_IS_PUBLIC = "\n[非公開]\n"

    class Schedule
      attr_reader :title_text, :schedule_url, :schedule_text, :place_text, :is_public
      def initialize(title_text, schedule_url, schedule_text, place_text, is_public)
        @title_text = title_text
        @schedule_url = schedule_url
        @schedule_text = schedule_text
        @place_text = place_text
        @is_public = is_public
      end
    end

    def initialize()
    end

    def handle(context:)
      message_id = context.lambda_event['mail']['messageId']
      s3_bucket = context.config.mail.s3.bucket
      s3_key = "#{context.config.mail.s3.path}/#{message_id}"
      context.logger.debug("message_object: s3://#{s3_bucket}/#{s3_key}")

      message = context.s3.get_object({bucket: s3_bucket, key: s3_key}).body.string
      mail = Mail.read_from_string(message)

      mail_text = ""
      if mail.multipart?
        charset = mail.text_part.content_type_parameters[:charset]
        mail_text = mail.text_part.body.to_s.force_encoding(charset).encode("UTF-8").gsub("\r", "")
      else
        charset = mail.content_type_parameters[:charset]
        mail_text = mail.body.decoded.force_encoding(charset).encode("UTF-8").gsub("\r", "")
      end
      schedule = parse_schedule(mail_text)
      user_id = context.config.slack.user

      if schedule.is_public
        summary = "#{schedule.title_text}|#{schedule.place_text}|#{schedule.schedule_text}"

        blocks = generate_block_public(user_id, schedule, true)
        context.client.chat_postMessage(channel: context.config.slack.channel_id_private, text: summary, blocks: blocks, as_user: true) if context.config.slack.post_to_private

        blocks = generate_block_public(user_id, schedule, false)
        context.client.chat_postMessage(channel: context.config.slack.channel_id_public, text: summary, blocks: blocks, as_user: true) if context.config.slack.post_to_public
      else
        blocks = generate_block_private(user_id, schedule, false)
        context.client.chat_postMessage(channel: context.config.slack.channel_id_public, text: "非公開予定があります", blocks: blocks, as_user: true) if context.config.slack.post_to_public

        summary = "#{schedule.title_text}|#{schedule.place_text}|#{schedule.schedule_text}"

        blocks = generate_block_public(user_id, schedule, true)
        context.client.chat_postMessage(channel: context.config.slack.channel_id_private, text: summary, blocks: blocks, as_user: true) if context.config.slack.post_to_private

        blocks = generate_block_public(user_id, schedule, false)
        context.client.chat_postEphemeral(channel: context.config.slack.channel_id_public, text: summary, blocks: blocks, as_user: true, user: context.config.slack.user) if context.config.slack.post_to_public
      end
    end

    def parse_schedule(mail_text)
      title_index = mail_text.index(MARKER_TITLE)
      title_fragment_text = mail_text[title_index + MARKER_TITLE.length .. -1]
      title_end_index = title_fragment_text.index("\n")
      title_text = title_fragment_text[0 .. title_end_index - 1]

      schedule_url_fragment_text = title_fragment_text[title_end_index + 1 .. -1]
      schedule_url_end_index = schedule_url_fragment_text.index("\n")
      schedule_url = schedule_url_fragment_text[0 .. schedule_url_end_index - 1]

      schedule_index = mail_text.index(MARKER_SCHEDULE)
      schedule_fragment_text = mail_text[schedule_index + MARKER_SCHEDULE.length .. -1]
      schedule_end_index = schedule_fragment_text.index("\n")
      schedule_text = schedule_fragment_text[0 .. schedule_end_index - 1]

      place_index = mail_text.index(MARKER_PLACE)
      place_fragment_text = mail_text[place_index + MARKER_PLACE.length .. -1]
      place_end_index = place_fragment_text.index("\n")
      place_text = place_end_index == 0 ? "" : place_fragment_text[0 .. place_end_index - 1]

      is_public_index = mail_text.index(MARKER_IS_PUBLIC)
      is_public_fragment_text = mail_text[is_public_index + MARKER_IS_PUBLIC.length .. -1]
      is_public_end_index = is_public_fragment_text.index("\n")
      is_public_text = is_public_fragment_text[0 .. is_public_end_index - 1]
      is_public = is_public_text == "公開" && mail_text.scan(MARKER_IS_PUBLIC).length == 1

      Schedule.new(title_text, schedule_url, schedule_text, place_text, is_public)
    end

    def generate_block_public(user_id, schedule, with_mention)
      summary_text = with_mention ? "<@#{user_id}> 予定通知:" : "予定通知:"
      [
        {
          "type" => "section",
          "text" => {
            "type" => "mrkdwn",
            "text" => summary_text
          }
        },
        {
          "type" => "divider"
        },
        {
          "type" => "section",
          "text" => {
            "type" => "mrkdwn",
            "text" => "*予定:* *<#{schedule.schedule_url}|#{schedule.title_text}>*\n*時間:* #{schedule.schedule_text}\n*場所:* #{schedule.place_text}"
          },
          "accessory" => {
            "type" => "image",
            "image_url" => "https://api.slack.com/img/blocks/bkb_template_images/notifications.png",
            "alt_text" => "calendar thumbnail"
          }
        }
      ]
    end

    def generate_block_private(user_id, schedule, with_mention)
      summary_text = with_mention ? "<@#{user_id}> 予定通知:" : "予定通知:"
      [
        {
          "type" => "section",
          "text" => {
            "type" => "mrkdwn",
            "text" => summary_text
          }
        },
        {
          "type" => "divider"
        },
        {
          "type" => "section",
          "text" => {
            "type" => "mrkdwn",
            "text" => "*非公開:* *<#{schedule.schedule_url}|予定詳細>*\n*時間:* #{schedule.schedule_text}"
          },
          "accessory" => {
            "type" => "image",
            "image_url" => "https://api.slack.com/img/blocks/bkb_template_images/notifications.png",
            "alt_text" => "calendar thumbnail"
          }
        }
      ]
    end
  end
end
