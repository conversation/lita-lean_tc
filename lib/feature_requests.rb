module Lita
# A class for dealing with the feature request board on trello
  class FeatureRequests

    SEVEN_DAYS = (60*60*24*7)

    def initialize(trello_client)
      @trello_client = trello_client
    end

    # Select cards created within the previous seven days
    #
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
