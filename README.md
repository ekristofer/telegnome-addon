<p align="center">
  <img src="docs/icon.png" width="128" alt="Telegnome icon">
</p>

<h1 align="center">Telegnome</h1>
<p align="center"><i>Gnomish Universal Messenger</i> - a World of Warcraft: Forever addon</p>

Telegnome moves your private messages out of the busy main chat and into a messenger-style window. Whispers and Battle.net messages each get their own conversation, and you can also run private group chats and follow channels like Guild or Party.

## Features

- **Direct messages**: every whisper and Battle.net whisper gets its own conversation with saved history. Reply from the window. Friends and strangers are kept apart, so a flood of strangers never buries your friends.
- **Chats**: everything in one list - Pinned, Friends, Group chats, Channels and Others (people you don't know). **+ New chat** starts a direct message, a group chat or a channel. Pin anything with the star.
- **Lobby**: whispers from people you don't know, collected as cards in one tab with two sides - **LFM** (while you're listed in the group finder: class, level and an Invite button, plus **Auto-invite** on a keyword) and **Business** (answers to your ad).
- **Invite pop-up**: when a friend whispers "inv", one click on the pop-up invites them.
- **Search**: find any saved message, in all conversations or in one.
- **Notes**: a short private note per person, shown under their name.
- **Recently grouped with**: people you grouped with in the last week sort under Friends.
- **Group chats**: private, password-protected group chats you join with a friendly invite code like `sprocket-whistle-gizmo-427`.
- **Followed channels**: mirror Guild, Officer, Party, Raid, Instance, Say, Yell or any joined channel (General, Trade, custom) into their own conversations.
- **Notifier**: a small on-screen cog shows how many messages you've missed. It grows to show new messages, then shrinks back.
- **Minimap button** with an unread badge.
- **Right-click a name** for the game's normal player menu (invite, add friend, ignore...).
- **New chat** player search with filters: people you talked to recently, your group, friends, people you grouped with and your guild.
- **Do not disturb** with an optional auto-reply message.
- **Only in Telegnome**: optionally keep whispers, Battle.net whispers and followed channels out of the main chat (group chats always are).
- Sound for new messages, with a choice of sounds.
- Adjustable window opacity, so you can keep it open over the game. It turns solid when you hover or type.
- Delivery feedback in the conversation (offline, away, ignoring you), shift-click links, key bindings, alert words for followed channels.
- The game's own window frame, with brass cogs - and a colour theme for everything inside it (Brass, Orange, Horde red, Alliance blue, Arcane, Fel green, Steel).
- Chat bubbles, or compact one-line messages if you prefer the game's look.

## Installation

1. Download the latest `Telegnome-vX.Y.Z.zip` from the [Releases](../../releases) page.
   (Or use **Code > Download ZIP** on this page.)
2. Unzip it and copy the **`Telegnome`** folder into:
   ```
   World of Warcraft/_forever_/Interface/AddOns/
   ```
   You should end up with `.../AddOns/Telegnome/Telegnome.toc`.
3. Start the game (or type `/reload`) and make sure Telegnome is ticked in the AddOns list.

> WoW Forever uses the `_forever_` folder.

## Using it

Open Telegnome with the minimap button, the addons button by the minimap, or `/tg`.

| Command | What it does |
|---|---|
| `/tg` | Open or close the window |
| `/tg new` | Start a new conversation |
| `/tg group <name>` | Create a group chat |
| `/tg join <code>` | Join a group chat |
| `/tg test stranger` | A pretend whisper from a stranger, to try the Lobby tab (LFM and Business) |
| `/tg channels` | Choose followed channels |
| `/tg opacity <30-100>` | Main window opacity |
| `/tg theme <name>` | Colour theme: brass, orange, horde, alliance, arcane, fel, steel |
| `/tg config` | Settings |
| `/tg mychannels` | Every chat channel you're in, with Leave buttons |
| `/tg search <text>` | Search your saved messages |
| `/tg sort recent\|name\|unread` | How the conversation list is sorted |
| `/tg follow-instance` | Follow Party or Raid chat until you leave the dungeon or raid |
| `/tg lobby` | Open the Lobby tab (also `/tg queue`) |
| `/tg lfm` | Collect now: strangers' whispers go to Lobby > LFM even when you're not listed (also `/tg recruit`) |
| `/tg dnd` | Toggle Do not disturb |
| `/tg only` | Keep whispers, Battle.net whispers and followed channels out of the main chat |
| `/tg hide` | Hide just whispers from the main chat |
| `/tg test` | Add a fake incoming whisper |
| `/tg demo chat\|lfm\|business` | Sample conversations for screenshots (your own are put aside); `/tg demo off` ends it |
| `/tg whatsnew` | Show the "Welcome to Telegnome 1.0" card again |
| `/tg help` | List all commands |

**Enter key:** while the Telegnome window is open on a conversation, Enter puts the cursor in Telegnome's message box. Press Enter again on the empty box to get the game's own chat. (Can be switched off in Settings > Chats.)

**Minimap button:** left-click opens, right-click starts a new message, Shift-click opens settings, Ctrl-click toggles Do not disturb, drag to move.

**Notifier:** click to open the conversation, right-click to mark all as read, Shift-drag to move. In Settings you can choose who triggers it (everyone, friends & guild, friends only), whether it grows left or right, or turn it off.

### Chats

Telegnome has two tabs: **Chats** and **Lobby**. Chats holds every conversation in one list, in sections:

- **Pinned**: anything you star or drag onto it - a person, a group chat or a channel - plus a dungeon's chat while you're inside. Drag a pinned conversation onto another to reorder, or use Move up / Move down in its right-click menu.
- **Friends**: Battle.net friends, your friends list, guild members and people you were in a group with in the last week - sorted in automatically.
- **Group chats** (two-people icon) and **Channels** (**#**).
- **Others**: people you don't know, with unread ones first. **Close all** (hover the header) closes every conversation in it and forgets those contacts.
- **More channels**: followed channels you've set not to show under Channels (right-click a channel). Folded by default.
- **Archive**: direct messages with nothing new for a while move here by themselves - after 7 days for friends and 1 day for Others (Settings > Chats; or turn it off). Right-click a conversation to archive it yourself. A new message brings it straight back. Group chats and channels are never archived.

Each section shows today's conversations, up to 5 (Settings > Chats; 0 shows everything), plus anything unread or open. Older ones wait behind **Show N earlier** and then show as one line each. Click a header to fold it. Right-click a header to mark it as read, sort it, move the section up or down, or **Show only this section** - every other section hides until you click **Show all**. You can also drag a section header onto another section to put them in your own order (Pinned stays on top, Archive at the bottom). Right-click the Chats tab to mark everything as read.

**+ New chat** opens a page with three choices: **Direct message** (search for any player or friend right there, or type a character name and press Enter), **Group chat** (create one, or join with a code) and **Channel** (Follow a channel, Filtered channels or Your chat channels, each its own page). Every page has a **< Back** button. Hovering a section header shows a small **+** that goes straight there.

Right-click someone in the Direct message search and choose **Forget contact** to take them off that list. Telegnome opens on the tab and conversation you used last.

### Search and notes

- The magnifier next to **+ New chat** searches every saved message (or type `/tg search <text>`). Click a result to open the conversation at that message. Searches you found something with are listed as **Recent searches** next time.
- **Search in this conversation** and **Add note...** are in the **...** menu next to a person's name. Notes are private and show under the name and on their request card.

### Help

The **?** next to the Settings cog explains the tab you're on. A tab with nothing in it shows the same help, so it explains itself the first time you open it. Settings > Help has all of it in one place.

### Lobby: LFM and Business

The **Lobby** tab collects whispers from people who aren't friends, guild members or favorites as cards, so they don't flood Chats. It has two sides, switched at the top: **LFM** for your group finder listing and **Business** for your ad. Each side shows a green dot while it collects (grey when not, yellow while paused) and how many are waiting. Only one side collects at a time, and the one started last wins: listing in the group finder or Collect now pauses Business, and starting Business pauses Collect now; the paused one comes back by itself. The dot on the Lobby tab is green while something collects; hover it to see what's going on. You can hide it in Settings > Lobby; then it only shows up while something collects or requests are waiting.

#### LFM

List yourself or your group in the group finder (alone, or as the leader) and LFM starts by itself. To collect without being listed, for example while recruiting in a chat channel, click **Collect now** (or `/tg lfm`). **Collect whispers** at the top is ticked by default while you're listed; untick it to pause.

- Each request shows the player's class, level and latest message.
- The row at the top shows a class icon and a count for each class that's waiting - the class comes with the first whisper. Click an icon to show only that class, or All to see everyone. Each request has its class icon by the name.
- Quick replies can use `{name}`, `{class}` and `{level}`, which are filled in for the person you answer.
- **Invite** invites them to your group; **x** dismisses the request; clicking the row opens the conversation.
- The level is read from the whisper ("70 mage", "lvl 45") or from their group finder application. **Check** looks the player up, also when a level looks wrong; the game only answers every few seconds, so the button counts down until you can ask again.
- Click the star in a request's conversation to keep that person - they move to Pinned in Chats.
- **Decline all** sends your decline message to everyone still on the list and takes them off it. People you invited or who are in your group stay.
- **Clear all** removes the remaining requests.
- **Auto-invite**: write a keyword, pick how long (5 minutes by default, up to an hour) and press **Start**. Anyone who whispers just that word ("123", "123!") is invited straight away, once each. It stops by itself when the time is up or your group is full (a party counts as full at 5 - convert to a raid for more), skips people you declined, and a /reload stops it. You need to be able to invite: not in a group, or its leader or an assistant.

#### Business

For crafters, sellers and guild ads. Write your ad at the top (click in the box and shift-click your profession or an item to add the link), choose where it goes (Trade, Say, Guild or any channel you're in) and how long to stay open (15, 30, 60 or 120 minutes, or **Until I stop it**). The **Saved ads** button next to the ad keeps ads for another time (up to 15): save the one in the box, put a saved one back, or delete one. Press **Start**, then **Post** - the game needs a click for every post, so the ad never repeats on its own. While it's open, whispers from people you don't know land here as cards with Invite and Reply; the replies, decline and Decline all messages are in **Settings > Lobby**. It tells you when it closes and how many whispers are waiting. Also `/tg business [minutes|off]`.

### Group chats

A group chat is a hidden, password-protected custom chat channel. Telegnome gives each group an invite code and turns it into the real channel name and password with a hash, so nobody has to see or type them and random players can't wander in.

1. **Create**: **+ New chat** > Group chat (or the **+** on the Group chats header) > name it > Create. A line like `Telegnome code: sprocket-whistle-gizmo-427` pops up ready to copy (Ctrl+C).
2. **Share**: paste it in a whisper, party, guild or any other chat. Or right-click the group name > Invite > pick a friend to whisper it for you.
3. **Join**: your friend's Telegnome picks up the code and shows a pop-up ("Thrall invited you to \"Raid team\". Click to join."). Clicking it opens the join panel with everything filled in - just press Join. Without the pop-up, **+ New group** is filled in the same way. (Typing or pasting the code, or `/tg join <code>`, also works.)
4. **Rename**: right-click the group > Rename group, or use the Rename button.

Everyone in the group needs Telegnome. The **N online** button at the top of a group opens a list of its members: a green dot for who's online now, a grey dot for members seen before who aren't. Click a name to whisper them. (The old "X joined / left" lines are off by default; turn them back on in Settings > Notifications.)

**Your chat channels** (Settings, the Group chats panel or `/tg mychannels`) lists every channel your character is in - General, Trade, custom channels and group chats - shows how many of the game's 10 slots are used, and lets you leave any of them. If Telegnome finds one of its group channels it has no record of, it's listed under Group chats as "Unknown group": rename it, enter its code (right-click), or leave it.

### Followed channels

Right-click a followed channel for two options: **Count unread messages** gives it a red badge that adds to the totals (on for Party, Raid and Instance; other channels show a quiet dot instead), and **Show under Channels** (off: it moves to More channels).

**+ New chat** > Channel > Follow a channel (or the **+** on the Channels header) > tick what you want. Messages are copied into their own conversation and you can reply from there. Followed channels don't count towards the missed-messages counter. Each channel has its own **Pop-up** tick (off by default). **Alert words** (Settings > Notifications) make a message pop up anyway when it contains one of your words, e.g. `LFM, tank`. A channel can also have its own alert words (right-click it > Alert words for this channel...).

**Filtered copies:** Followed channels > **Filtered channels** page: choose a channel, type words, e.g. `enchant, ench`, and click **Add** (or right-click a followed channel > **New filtered copy...**). You get a separate conversation, "Trade [Enchant]", that keeps only the messages with those words and pops up when one arrives. Make as many as you like, with or without following the whole channel; the matching words are picked out in gold.

### Mail

When mail arrives (or you log in with unread mail), a pop-up says who sent it, e.g. "New mail from Thrall and Stormwind Auction House (2)". Settings > Notifications turns it off or changes the text; `{from}` is filled in with the senders. The game only names the latest three senders and only lets addons read mail at a mailbox, so it's a notification, not a conversation.

### Dungeons, raids and combat

When you enter a dungeon, Telegnome offers to follow Party chat until you leave; in a raid, Raid chat. Instance chat (used by group finder groups) is followed too. While you're inside it's pinned at the top of Chats, with an "Entered ..." line where the run starts. Choose **Ask**, **Always follow** or **Never** in Settings > Chats, or type `/tg follow-instance`. A chat followed just for the run has pop-up notifications on (untick **Pop-up notifications for the dungeon or raid chat** in Settings > Chats to only count messages); a chat you already follow keeps its own settings.

In combat, pop-ups and sounds wait until the fight is over; then one pop-up says what came in. Settings > Notifications > In combat has two other choices: **Show everything** (pop-ups and sounds as usual) or **Only the count** (no pop-ups or summary; the notifier, minimap button and badges still count up).

### Invite pop-up

When someone whispers just "inv", "inv pls", "invite me?" or similar, the pop-up says they want an invite, and clicking it invites them. Settings > Notifications: **Friends & guild** (default), **Everyone** or **Off**. It only shows when you can invite.

### Do not disturb

Settings > Notifications (or `/tg dnd`, or Ctrl-click the notifier). No pop-ups or sounds; messages still arrive and are counted. Optionally auto-reply to whispers with your own text (prefixed `[Auto-reply]`, once per person per 30 minutes).

### Key bindings and links

Under the game's **Options > Keybindings > AddOns > Telegnome** you can set keys for opening Telegnome and for jumping to the newest unread message. Shift-click an item, quest or achievement while typing in Telegnome to add its link to your message.

### Clearing history

In a conversation, **Clear history** (in the **...** menu next to the name, or right-click the conversation) empties it but keeps the conversation. The × on a conversation closes it and removes its history.

## Known limits

- During combat or boss encounters the game may hide chat text from addons. Those whispers and followed-channel messages stay in the main chat; group chat messages sent in that moment can be missed, because group channels never show in the main chat.
- Codes posted in say, yell or public channels are picked up quietly (no chat line) and never replace a code a friend sent you in the last hour.
- Group chat members need to be able to join the same chat channels - usually the same realm (group) and faction.
- The game allows 10 chat channels per character (General, Trade etc. count). Each group chat uses one.
- A Battle.net friend whispering from their game character gets a separate character conversation.

## Your data and privacy

Telegnome keeps everything on your own computer. Nothing is sent to anyone or uploaded anywhere - the addon only talks to the game's normal chat.

**What is saved**

- Your conversations: the last 200 messages of each whisper, Battle.net whisper, group chat and followed channel.
- The people you've talked to (name, class, whether they're a favorite), so they show up in New message.
- Your group chats: their names and invite codes.
- Which channels you follow, and your settings.

**Where**

One file, shared by all characters on the account:

```
World of Warcraft/_forever_/WTF/Account/<account>/SavedVariables/Telegnome.lua
```

It's a plain text file - anyone with access to your computer can read it, like the game's own chat logs.

**Removing it**

- One conversation's messages: **Clear history** in that conversation's **...** menu.
- A person: right-click them in **+ New chat** > Direct message > **Forget contact**.
- All messages at once: **Settings > Your data > Delete all messages**.
- Everything, settings included: delete the file above while the game is closed.

Settings > Your data shows the same summary in-game, with how much is saved right now.

## For developers

```
Telegnome/               the addon folder (this is what goes into AddOns)
  Telegnome.toc          load order and metadata
  Bindings.xml           key bindings
  Core/Core.lua          saved data, whisper events, sending, chat filters, slash commands
  Core/Style.lua         shared classic-style widgets (panels, buttons, cogs)
  UI/Messages.lua        the message area (bubbles, compact lines, dates)
  UI/UI.lua              main window, tabs, conversation list and header
  UI/Picker.lua          the Direct message player search
  UI/ChannelList.lua     "Your chat channels" list
  UI/Search.lua          message search
  UI/Settings.lua        settings panel
  UI/Notifier.lua        on-screen counter / notification
  UI/Minimap.lua         minimap button
  UI/Help.lua            the ? help card for each tab
  UI/NewChat.lua         the New chat page
  Features/Groups.lua    group chats (invite codes, hashing, channels)
  Features/Channels.lua  followed channels
  Features/Requests.lua  Lobby tab (LFM and Business cards)
  Features/Social.lua    recently grouped with, notes, reply blanks, login summary
  Features/Instances.lua dungeon and raid chat, quiet in combat
  Media/                 icon and cog textures (.tga)
docs/                    images for this README
```

**Releasing:** bump `## Version` in `Telegnome/Telegnome.toc`, add a line to `CHANGELOG.md`, then push a matching tag (for example `v0.5.0`). The GitHub Action checks that the tag matches the TOC version, zips the `Telegnome` folder and attaches it to a new release.

## License

[MIT](LICENSE)
