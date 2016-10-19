module Lita
  # Returns cards that have been in Review column for more than two days
  class FeatureRequests

    SEVEN_DAYS = (60*60*168)

    def initialize(trello_client)
      @trello_client = trello_client
    end

    def to_msg(board_id)
      board = @trello_client.find(:boards, board_id)
      board.cards.select{ |card|
        card.actions.last.date > seven_days_in_seconds
      }.map{ |card|
        "#{card.name}, #{card.short_url}, #{card.list.name}"
      }.join("\n")
    end

    private

    def seven_days_in_seconds
      ::Time.now - SEVEN_DAYS
    end

  end
end
