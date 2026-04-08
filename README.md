# Chronicle - your work journal

Get it out of your head. Chronicle is a lightweight journal for logging
achievements and pinning your current goals — so when review time comes, you
already have the receipts.


# Track your accomplishments

The core of Chronicle is the list of entries. Think of this like a journal;
when something happens that you don't want to forget, this is the place to put
it. Entries are lightweight: a title, some content, and some tags. Searchable
and filterable when you want to find out what got done.


# Quickly see your current goals

Chronicle supports a single pinned entry. The idea behind this is to have a
simple list of the things you want to get done this week. When a new week
starts, create a new list with your next set of priorities and the old list
becomes a normal entry that can serve as a reference for additional context at
that time. But of course you're free to use the pinned entry however you like.
⌘-D opens a separate pane to show the currently pinned entry.


# Filter and export

When you want to see a slice of your work (like at annual review time) you can
filter entries by text, date, and tags. You can export the filtered list as
JSON or plain text so that your favorite AI can provide insight.


## Access from anywhere

When signed into iCloud, your entries are available across iOS and macOS.


## URL scheme support

There are a few URL endpoints that Chronicle supports:

- `chronicle://open`: opens the app. Can use the `?pinned` query parameter to select
  the pinned entry.
- `chronicle://new`: creates a new entry. Can be pre-filled with `?title` and
  `?content` query parameters.
- `chronicle://entry`: opens the app and finds an entry with the given `?title`; if
  there is not one it will be created. An optional `?tag` query is available,
  the tag will be added to the new or existing entry.

The "entry" endpoint can be used to have a daily scratch pad that's easy to
find. The following AppleScript script will create/open today's scratch pad:

```
set today to current date
set y to year of today as string
set m to text -2 thru -1 of ("0" & (month of today as integer as string))
set d to text -2 thru -1 of ("0" & (day of today as string))

set dateStr to y & "-" & m & "-" & d
set entryURL to "chronicle://entry?tag=scratch&title=Scratch " & dateStr

open location entryURL
```

Run that with your favorite application launcher for a quick scratch pad that
can be archived with your other entries.


## Development

Built with XCode 26.3, supporting macOS and iOS at the same versions.
