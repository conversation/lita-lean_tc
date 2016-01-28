# tc-lean

Some code for maintaining an grooming the trello boards we use to track development at TC.

## Usage

Tasks are triggered using rake.

TODO: instructions for discovering the required key, token and board ID

### Setting a card type for all cards on a board

Loops over all cards on a board. Any that are missing a card-type tag (bug, feature, etc)
will prompt the user to choose a type:

    TRELLO_BOARD_ID=xxx TRELLO_PUBLIC_KEY=yyy TRELLO_MEMBER_TOKEN=zzz bundle exec rake set_types

### Display the breakdown of card types on a board

Loops over all lists on a board and prints the count of each card-type it holds:

    TRELLO_BOARD_ID=xxx TRELLO_PUBLIC_KEY=yyy TRELLO_MEMBER_TOKEN=zzz bundle exec rake breakdown

### Count the total number of cards on a board

    TRELLO_BOARD_ID=xxx TRELLO_PUBLIC_KEY=yyy TRELLO_MEMBER_TOKEN=zzz bundle exec rake count_cards
