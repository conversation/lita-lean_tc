# lita-lean\_tc

A lita plugin for maintaining and grooming the trello boards we use to track development at TC.

## Usage

Add this gem to your lita installation by including the following line in your Gemfile:

    gem "lita-lean_tc", git: "http://github.com/conversation/lita-lean_tc.git"

Then, edit your lita\_config.rb to include the following two lines:

    config.handlers.lean.trello_public_key = ENV["TRELLO_PUBLIC_KEY"] || "trello-key"
    config.handlers.lean.trello_member_token = ENV["TRELLO_MEMBER_TOKEN"] || "trello-token"

To find the value for TRELLO\_PUBLIC\_KEY, visit the following URL and grab the
value under "Developer API Keys":

    https://trello.com/app-key

To find the value for TRELLO\_MEMBER\_TOKEN, replace TRELLO\_PUBLIC\_KEY in the following
URL with the value from above, visit it and click "Allow":

    https://trello.com/1/authorize?expiration=never&name=Ruby%20Trello&response_type=token&scope=read%2Cwrite%2Caccount&key=TRELLO_PUBLIC_KEY

### Chat commands

The following commands are available via the lita bot.

#### Set Card Types

Loops over all cards on a board. Any that are missing a card-type tag (bug, feature, etc)
will prompt the channel to choose a type:

    lita lean set-types <trello board id>

#### Display the breakdown of card types on a board

Loops over all lists on a board and prints the count of each card-type it holds:

    lita lean breakdown <trello board id>

### Count the total number of cards on a board

    lita lean count <trello board id>

### List the cards that have sat in Review column for more than two days

    lita lean review <trello board id>

### List cards currently in the Confirmed column on the development board

    lita lean confirmed-cards

### Response to TCBOT when tc-i18n-hygiene check fails

This will create a code directly on the Confirmed column on the development board
