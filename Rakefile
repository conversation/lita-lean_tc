$LOAD_PATH << 'lib'

Bundler.setup
Bundler.require

require 'trello'
require 'highline'

BUG = "[bug]"
MAINTENANCE = "[maint]"
TECH = "[tech]"
FEATURE = "[feature]"

task :set_types do
  client = Trello::Client.new(
    developer_public_key: ENV["TRELLO_PUBLIC_KEY"],
    member_token: ENV["TRELLO_MEMBER_TOKEN"]
  )
  board = client.find(:boards, ENV['TRELLO_BOARD_ID'])
  cards = board.cards
  cards.select { |card|
    !card.name.include?(BUG) &&
      !card.name.include?(MAINTENANCE) &&
      !card.name.include?(TECH) &&
      !card.name.include?(FEATURE)
  }.each { |card|
    puts "Missing card type on: #{card.name}"
    puts
    new_type = select_type
    card.name = "#{new_type} #{card.name}"
    card.save
  }
end

def select_type
  cli = HighLine.new
  selection = nil
  cli.choose do |menu|
    menu.prompt = "Card Type?"
    menu.choice(:bug) { selection = BUG }
    menu.choice(:maintenance) { selection = MAINTENANCE }
    menu.choice(:tech) { selection = TECH }
    menu.choice(:feature) { selection = FEATURE }
  end
  return selection
end
