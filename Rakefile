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
    labels = card.labels.map(&:name)
    puts
    puts "****************************************************************"
    puts "#{card.name} [#{labels.join(", ")}]"
    new_type = select_type
    card.name = "#{new_type} #{card.name}"
    card.save
  }
end

task :breakdown do
  client = Trello::Client.new(
    developer_public_key: ENV["TRELLO_PUBLIC_KEY"],
    member_token: ENV["TRELLO_MEMBER_TOKEN"]
  )
  board = client.find(:boards, ENV['TRELLO_BOARD_ID'])
  lists = board.lists
  lists.each do |list|
    puts list.name
    stats = list_stats(list)
    puts "- #{stats.inspect}"
  end
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
