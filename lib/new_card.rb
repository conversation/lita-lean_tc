module Lita
  # Returns cards that are in the Confirmed column
  class NewCard

    def initialize(trello_client)
      @trello_client = trello_client
    end

    def display_confirmed_msg(board_id)
      board = @trello_client.find(:boards, board_id)
      confirmed_cards = detect_confirmed(board)
      message = "Confirmed cards:\n"
      message += confirmed_cards.map do |card|
        "#{card.name}, #{card.url}"
      end.join("\n")
    end

    private

    def detect_confirmed(board)
      list = board.lists.detect{|list| list.name.starts_with?('Confirmed')}
      list.cards
    end

  end
end
