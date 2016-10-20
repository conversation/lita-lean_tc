require "lita"
require 'trello'
require 'lita-timing'
require 'review_cards'
require 'new_card'
require 'feature_requests'

module Lita
  module Handlers
    class Lean < Handler
      RESPONSE_TIMEOUT = 300 # seconds

      BUG = "[bug]"
      MAINTENANCE = "[maint]"
      TECH = "[tech]"
      FEATURE = "[feature]"

      CONTENT = "[content]"
      DATA = "[data]"
      COMMERCIAL = "[commercial]"

      TIMER_INTERVAL = 60

      config :trello_public_key
      config :trello_member_token
      config :development_board_id
      config :feature_board_id
      config :old_review_cards_channel
      config :list_id

      on :loaded, :start_timer
      on :buildkite_build_finished, :build_finished

      route(/\Alean count ([a-zA-Z0-9]+)\Z/i, :count, command: true, help: { "lean count [board id]" => "Count cards on the nominated trello board"})
      route(/\Alean breakdown ([a-zA-Z0-9]+)\Z/i, :breakdown, command: true, help: { "lean breakdown [board id]" => "Breakdown of card types on the nominated trello board"})
      route(/\Alean set-types ([a-zA-Z0-9]+)\Z/i, :set_types, command: true, help: { "lean set-types [board id]" => "Begin looping through cards without a type on the nominated trello board"})
      route(/\Alean set-streams ([a-zA-Z0-9]+)\Z/i, :set_streams, command: true, help: { "lean set-streams [board id]" => "Begin looping through cards without a stream on the nominated trello board"})
      route(/\Alean confirmed-cards\Z/i, :list_cards, command: true, help: { "lean confirmed-cards" => "List all cards in the confirmed column" })
      route(/\Alean list-feature-requests\Z/i, :list_feature_request, command: true, help: { "lean list-feature-requests" => "List all cards on the Feature Request board" })
      route(/\A([bmtf])\Z/i, :type, command: false)
      route(/\A([cdo])\Z/i, :stream, command: false)

      def start_timer(payload)
        start_review_timer
        start_feature_timer
      end

      # Returns cards listed in Confirmed on the Development board
      def list_cards(response)
        msg = NewCard.new(trello_client, config.list_id).display_confirmed_msg(config.development_board_id)
        response.reply("#{msg}")
      end

      # Creates a card with specified value in the Confirmed column on
      # the Development board when the tc-i18n-hygiene build fails
      def create_confirmed
        new_card = NewCard.new(trello_client, config.list_id).create_new_card
        response = "#{new_card.name}, #{new_card.url}"
        robot.send_message(target, response)
      end

      def build_finished(payload)
        event = payload[:event]

        if event.pipeline_name == "tc-i18n-hygiene" && !event.passed?
          create_confirmed
        end
      end

      # Lists all cards on the feature request wall
      def list_feature_request(response)
        msg = FeatureRequests.new(trello_client).all_feature_request(config.feature_board_id)
        response.reply("#{msg}")
      end

      # Returns a count of cards on a Trello board, broken down by
      # the card type
      #
      def breakdown(response)
        board_id = response.args.last
        board = trello_client.find(:boards, board_id)
        board.lists.each do |list|
          stats = list_stats(list)
          response.reply("#{list.name}: #{stats.inspect}")
        end
      end

      # Returns a simple count of cards on a Trello board
      #
      def count(response)
        board_id = response.args.last
        board = trello_client.find(:boards, board_id)
        response.reply("#{board.cards.size} cards on #{board.name}")
      end

      # Set the current channel into Q&A mode, allowing users to loop through
      # the cards on a Trello board and choose a card type
      def set_types(response)
        board_id = response.args.last
        board = trello_client.find(:boards, board_id)
        response.reply("Starting Set Types session for board: #{board.name}")
        response.reply("Note: You have #{RESPONSE_TIMEOUT} seconds between questions to reply")
        select_next_typeless_card_from_board(response, board)
      end

      # Set the current channel into Q&A mode, allowing users to loop through
      # the cards on a Trello board and choose a card stream
      def set_streams(response)
        board_id = response.args.last
        board = trello_client.find(:boards, board_id)
        response.reply("Starting Set Streams session for board: #{board.name}")
        response.reply("Note: You have #{RESPONSE_TIMEOUT} seconds between questions to reply")
        select_next_streamless_card_from_board(response, board)
      end

      # Set the type for a single Trello card. To reach this command, first
      # use the "set-types" command to put a channel into active mode.
      def type(response)
        room_name = response.message.source.room.to_s
        board_id = redis.get("#{room_name}-board-id")
        card_id = redis.get("#{room_name}-card-id")
        board = trello_client.find(:boards, board_id)
        card = trello_client.find(:cards, card_id)
        new_type = case response.message.body
                   when "b", "B" then BUG
                   when "m", "M" then MAINTENANCE
                   when "t", "T" then TECH
                   else
                     FEATURE
                   end
        card.name = "#{new_type} #{card.name}"
        card.save
        select_next_typeless_card_from_board(response, board)
      end

      # Set the stream for a single Trello card. To reach this command, first
      # use the "set-streams" command to put a channel into active mode.
      def stream(response)
        room_name = response.message.source.room.to_s
        board_id = redis.get("#{room_name}-board-id")
        card_id = redis.get("#{room_name}-card-id")
        board = trello_client.find(:boards, board_id)
        card = trello_client.find(:cards, card_id)
        new_stream = case response.message.body
                     when "c", "C" then CONTENT
                     when "d", "D" then DATA
                     else
                       COMMERCIAL
                     end
        card.name = "#{new_stream} #{card.name}"
        card.save
        select_next_streamless_card_from_board(response, board)
      end

      private

      def start_review_timer
        every_with_logged_errors(TIMER_INTERVAL) do |timer|
          daily_at("23:00", [:sunday, :monday, :tuesday, :wednesday, :thursday], "review-column-activity") do
            msg = ReviewCards.new(trello_client).to_msg(config.development_board_id)
            robot.send_message(target, msg) if msg
          end
        end
      end

      def start_feature_timer
        every_with_logged_errors(TIMER_INTERVAL) do |timer|
          daily_at("23:00", [:sunday], "feature-request-activity") do
            msg = FeatureRequests.new(trello_client).to_msg(config.feature_board_id)
            robot.send_message(target, msg) if msg
          end
        end
      end

      def every_with_logged_errors(interval, &block)
        logged_errors do
          every(interval, &block)
        end
      end

      def logged_errors(&block)
        yield
      rescue Exception => e
        puts "Error in timer loop: #{e.inspect}"
      end

      def daily_at(time, day, name, &block)
        Lita::Timing::Scheduled.new(name, redis).daily_at(time, day, &block)
      end

      def target
        Source.new(room: Lita::Room.find_by_name(config.old_review_cards_channel) || "general")
      end

      def select_next_typeless_card_from_board(response, board)
        room_name = response.message.source.room.to_s
        card = detect_card_with_no_type(board)
        if card
          set_state(room_name, board.id, card.id)
          response.reply(card_to_string(card))
          response.reply("[b]ug [m]aintenance [t]ech [f]eature")
        else
          reset_state(room_name)
          response.reply("All cards have been classified")
        end
      end

      def select_next_streamless_card_from_board(response, board)
        room_name = response.message.source.room.to_s
        card = detect_card_with_no_stream(board)
        if card
          set_state(room_name, board.id, card.id)
          response.reply(card_to_string(card))
          response.reply("[c]ontent [d]ata c[o]mmercial")
        else
          reset_state(room_name)
          response.reply("All cards have been classified")
        end
      end

      def set_state(room_name, board_id, card_id)
        redis.set("#{room_name}-board-id", board_id, ex: RESPONSE_TIMEOUT)
        redis.set("#{room_name}-card-id", card_id, ex: RESPONSE_TIMEOUT)
      end

      def reset_state(room_name)
        redis.del("#{room_name}-board-id")
        redis.del("#{room_name}-card-id")
      end

      def card_to_string(card)
        labels = card.labels.map(&:name)
        "#{card.name} [#{labels.join(", ")}] [#{card.url}]"
      end

      def detect_card_with_no_type(board)
        cards = board.cards
        cards.detect { |card|
          !card.name.include?(BUG) &&
            !card.name.include?(MAINTENANCE) &&
            !card.name.include?(TECH) &&
            !card.name.include?(FEATURE)
        }
      end

      def detect_card_with_no_stream(board)
        cards = board.cards
        cards.detect { |card|
          !card.name.include?(CONTENT) &&
            !card.name.include?(DATA) &&
            !card.name.include?(COMMERCIAL)
        }
      end

      def list_stats(list)
        cards = list.cards
        result = {}
        result[:total] = cards.size
        result[:feature] = cards.map(&:name).select {|name| name.include?(FEATURE) }.size
        result[:bug] = cards.map(&:name).select {|name| name.include?(BUG) }.size
        result[:maintenance] = cards.map(&:name).select {|name| name.include?(MAINTENANCE) }.size
        result[:tech] = cards.map(&:name).select {|name| name.include?(TECH) }.size
        result[:unknown_type] = cards.map(&:name).select {|name|
          !name.include?(FEATURE) &&
            !name.include?(BUG) &&
            !name.include?(MAINTENANCE) &&
            !name.include?(TECH)
        }.size
        result[:content] = cards.map(&:name).select {|name| name.include?(CONTENT) }.size
        result[:data] = cards.map(&:name).select {|name| name.include?(DATA) }.size
        result[:commercial] = cards.map(&:name).select {|name| name.include?(COMMERCIAL) }.size
        result[:unknown_stream] = cards.map(&:name).select {|name|
          !name.include?(CONTENT) &&
            !name.include?(DATA) &&
            !name.include?(COMMERCIAL)
        }.size
        result
      end

      def trello_client
        @client ||= Trello::Client.new(
          developer_public_key: config.trello_public_key,
          member_token: config.trello_member_token
        )
      end

      Lita.register_handler(self)
    end
  end
end
