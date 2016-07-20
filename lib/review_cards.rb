module Lita
  # Returns cards that have been in Review column for more than two days
  class ReviewCards

    TWO_DAYS = (60*60*48)

    def initialize(trello_client)
      @trello_client = trello_client
    end

    def to_msg(board_id)
      board = @trello_client.find(:boards, board_id)
      old_cards = detect_review(board)
      if !old_cards.empty?
        message = "These cards have been in review for TOO DAMN LONG!\n\n"
        message += old_cards.map do |card|
          "#{card.name}, #{card.url}"
        end.join("\n")
      end
    end

    private

    def detect_review(board)
      list = board.lists.detect{|list| list.name.starts_with?('Review') }
      list.cards.select { |card|
        card_old?(card)
      }
    end

    def card_old?(card)
      action = card.actions.select { |action|
        action.data.key?('listAfter')
      }.select {|action|
        action.data['listAfter']['name'].starts_with?('Review')
      }.sort_by{ |action|
        action.date
      }.last
      if action.nil?
        false
      else
        action.date < ::Time.now - TWO_DAYS
      end
    end
  end
end
