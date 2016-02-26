require "lita"
require 'trello'

module Lita
  module Handlers
    class Lean < Handler
      RESPONSE_TIMEOUT = 300 # seconds

      BUG = "[bug]"
      MAINTENANCE = "[maint]"
      TECH = "[tech]"
      FEATURE = "[feature]"

      config :trello_public_key
      config :trello_member_token

      route(/\Alean count ([a-zA-Z0-9]+)\Z/i, :count, command: true, help: { "lean count [board id]" => "Count cards on the nominated trello board"})
      route(/\Alean breakdown ([a-zA-Z0-9]+)\Z/i, :breakdown, command: true, help: { "lean breakdown [board id]" => "Breakdown of card types on the nominated trello board"})
      route(/\Alean set-types ([a-zA-Z0-9]+)\Z/i, :set_types, command: true, help: { "lean set-types [board id]" => "Begin looping through cards without a type on the nominated trello board"})
      route(/\A([bmtf])\Z/i, :type, command: false)

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
        select_next_card_from_board(response, board)
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
        select_next_card_from_board(response, board)
      end

      private

      def select_next_card_from_board(response, board)
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

      def list_stats(list)
        cards = list.cards
        result = {}
        result[:total] = cards.size
        result[:feature] = cards.map(&:name).select {|name| name.include?(FEATURE) }.size
        result[:bug] = cards.map(&:name).select {|name| name.include?(BUG) }.size
        result[:maintenance] = cards.map(&:name).select {|name| name.include?(MAINTENANCE) }.size
        result[:tech] = cards.map(&:name).select {|name| name.include?(TECH) }.size
        result[:unknown] = cards.map(&:name).select {|name|
          !name.include?(FEATURE) &&
            !name.include?(BUG) &&
            !name.include?(MAINTENANCE) &&
            !name.include?(TECH)
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
