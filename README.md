<p align="center">
  <img src="docs/icon.png" width="128" alt="Telegnome icon">
</p>

<h1 align="center">Telegnome</h1>
<p align="center"><i>Gnomish Universal Messenger</i> - a World of Warcraft: Forever addon</p>

Telegnome moves your private messages out of the busy main chat and into a messenger-style window. Whispers and Battle.net messages each get their own conversation, and you can also run private group chats and follow channels like Guild or Party.

## Features

- **Direct messages**: every whisper and Battle.net whisper gets its own conversation with saved history. Reply from the window. The list is grouped into **Favorites**, **Friends** and **Others**, so a flood of strangers never buries your friends.
- **Group chats**: private, password-protected group chats you join with a friendly invite code like `sprocket-whistle-gizmo-427`.
- **Followed channels**: mirror Guild, Officer, Party, Raid, Instance, Say, Yell or any joined channel (General, Trade, custom) into their own tab.
- **Notifier**: a small on-screen cog shows how many messages you've missed. It grows to show new messages, then shrinks back.
- **Minimap button** with an unread badge.
- **Right-click a name** for the game's normal player menu (invite, add friend, ignore...).
- **New message** picker with your Battle.net friends, friends list and everyone you've talked to.
- **Do not disturb** with an optional auto-reply message.
- **Only in Telegnome**: optionally keep whispers, Battle.net whispers and followed channels out of the main chat (group chats always are).
- Sound for new messages, with a choice of sounds.
- Adjustable window opacity, so you can keep it open over the game. It turns solid when you hover or type.
- Delivery feedback in the conversation (offline, away, ignoring you), shift-click links, key bindings, alert words for followed channels.
- Classic look, with brass cogs.

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
| `/tg channels` | Choose followed channels |
| `/tg opacity <30-100>` | Main window opacity |
| `/tg config` | Settings |
| `/tg mychannels` | Every chat channel you're in, with Leave buttons |
| `/tg dnd` | Toggle Do not disturb |
| `/tg only` | Keep whispers, Battle.net whispers and followed channels out of the main chat |
| `/tg hide` | Hide just whispers from the main chat |
| `/tg test` | Add a fake incoming whisper |
| `/tg help` | List all commands |

**Enter key:** while the Telegnome window is open on a conversation, Enter puts the cursor in Telegnome's message box. Press Enter again on the empty box to get the game's own chat. (Can be switched off in Settings > Chat.)

**Minimap button:** left-click opens, right-click starts a new message, Shift-click opens settings, Ctrl-click toggles Do not disturb, drag to move.

**Notifier:** click to open the conversation, right-click to mark all as read, Shift-drag to move. In Settings you can choose who triggers it (everyone, friends & guild, friends only), whether it grows left or right, or turn it off.

### Favorites, Friends and Others

The Direct messages list has three sections, newest conversation first in each:

- **Favorites**: click the star next to a conversation's name (or right-click > Add to favorites). Always on top.
- **Friends**: Battle.net friends, your friends list and guild members - sorted in automatically.
- **Others**: everyone else. Click the header to fold the section away; **Close all** closes every conversation in it and forgets those contacts.

Right-click someone in **+ New message** and choose **Forget contact** to take them off that list.

### Group chats

A group chat is a hidden, password-protected custom chat channel. Telegnome gives each group an invite code and turns it into the real channel name and password with a hash, so nobody has to see or type them and random players can't wander in.

1. **Create**: Group chats tab > **+ New group** > name it > Create. A line like `Telegnome code: sprocket-whistle-gizmo-427` pops up ready to copy (Ctrl+C).
2. **Share**: paste it in a whisper, party, guild or any other chat. Or right-click the group name > Invite > pick a friend to whisper it for you.
3. **Join**: your friend's Telegnome picks up the code. They click **+ New group** and it's already filled in - just press Join. (Typing or pasting the code, or `/tg join <code>`, also works.)
4. **Rename**: right-click the group > Rename group, or use the Rename button.

Everyone in the group needs Telegnome. The **Online** button lists who is in the group right now, and grey lines show when someone joins (comes online) or leaves.

**Your chat channels** (Settings, the Group chats panel or `/tg mychannels`) lists every channel your character is in - General, Trade, custom channels and group chats - shows how many of the game's 10 slots are used, and lets you leave any of them. If Telegnome finds one of its group channels it has no record of, it's listed under Group chats as "Unknown group": rename it, enter its code (right-click), or leave it.

### Followed channels

Followed channels tab > **+ Follow channel** > tick what you want. Messages are copied into the tab and you can reply from there. Followed channels don't count towards the missed-messages counter. Each channel has its own **Pop-up** tick (off by default). **Alert words** (Settings > Notifications) make a message pop up anyway when it contains one of your words, e.g. `LFM, tank`.

### Do not disturb

Settings > Do not disturb (or `/tg dnd`, or Ctrl-click the notifier). No pop-ups or sounds; messages still arrive and are counted. Optionally auto-reply to whispers with your own text (prefixed `[Auto-reply]`, once per person per 30 minutes).

### Key bindings and links

Under the game's **Options > Keybindings > AddOns > Telegnome** you can set keys for opening Telegnome and for jumping to the newest unread message. Shift-click an item, quest or achievement while typing in Telegnome to add its link to your message.

### Clearing history

In a conversation, **Clear history** empties it but keeps the conversation. The × on a conversation closes it and removes its history.

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

- One conversation's messages: **Clear history** in that conversation.
- A person: right-click them in **+ New message** > **Forget contact**.
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
  UI/UI.lua              main window, tabs, conversation view
  UI/Picker.lua          "New message" contact picker
  UI/ChannelList.lua     "Your chat channels" list
  UI/Settings.lua        settings panel
  UI/Notifier.lua        on-screen counter / notification
  UI/Minimap.lua         minimap button
  Features/Groups.lua    group chats (invite codes, hashing, channels)
  Features/Channels.lua  followed channels
  Media/                 icon and cog textures (.tga)
docs/                    images for this README
```

**Releasing:** bump `## Version` in `Telegnome/Telegnome.toc`, add a line to `CHANGELOG.md`, then push a matching tag (for example `v0.5.0`). The GitHub Action checks that the tag matches the TOC version, zips the `Telegnome` folder and attaches it to a new release.

## License

[MIT](LICENSE)
