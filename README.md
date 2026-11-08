<p align="center">
  <img src="docs/icon.png" width="128" alt="Telegnome icon">
</p>

<h1 align="center">Telegnome</h1>
<p align="center"><i>Gnomish Universal Messenger</i> - a World of Warcraft: Forever addon</p>

Telegnome moves your private messages out of the busy main chat and into a messenger-style window. Whispers and Battle.net messages each get their own conversation, and you can also run private group chats and follow channels like Guild or Party.

## Features

- **Direct messages**: every whisper and Battle.net whisper gets its own conversation with saved history. Reply from the window.
- **Group chats**: private, password-protected group chats you join with a friendly invite code like `sprocket-whistle-gizmo-42`.
- **Followed channels**: mirror Guild, Officer, Party, Raid, Instance, Say, Yell or any joined channel (General, Trade, custom) into their own tab.
- **Notifier**: a small on-screen cog shows how many messages you've missed. It grows to show new messages, then shrinks back.
- **Minimap button** with an unread badge.
- **Right-click a name** for the game's normal player menu (invite, add friend, ignore...).
- **New message** picker with your Battle.net friends, friends list and everyone you've talked to.
- Optional: hide whispers and followed channels from the main chat entirely.
- Classic look, with brass cogs.

## Installation

1. Download the latest `Telegnome-vX.Y.Z.zip` from the [Releases](../../releases) page.
   (Or use **Code > Download ZIP** on this page.)
2. Unzip it and copy the **`Telegnome`** folder into:
   ```
   World of Warcraft/_classic_beta_/Interface/AddOns/
   ```
   You should end up with `.../AddOns/Telegnome/Telegnome.toc`.
3. Start the game (or type `/reload`) and make sure Telegnome is ticked in the AddOns list.

> Forever installs to `_classic_beta_` (Battle.net may call it "Classic" or "Classic Beta").

## Using it

Open Telegnome with the minimap button, the addons button by the minimap, or `/tg`.

| Command | What it does |
|---|---|
| `/tg` | Open or close the window |
| `/tg new` | Start a new conversation |
| `/tg group <name>` | Create a group chat |
| `/tg join <code>` | Join a group chat |
| `/tg channels` | Choose followed channels |
| `/tg config` | Settings |
| `/tg hide` | Hide whispers from the main chat |
| `/tg test` | Add a fake incoming whisper |
| `/tg help` | List all commands |

**Minimap button:** left-click opens, right-click starts a new message, Shift-click opens settings, drag to move.

**Notifier:** click to open the conversation, right-click to mark all as read, Shift-drag to move. In Settings you can choose who triggers it (everyone, friends & guild, friends only), whether it grows left or right, or turn it off.

### Group chats

A group chat is a hidden, password-protected custom chat channel. Telegnome gives each group an invite code and turns it into the real channel name and password with a hash, so nobody has to see or type them and random players can't wander in.

1. **Create**: Group chats tab > **+ New group** > name it > Create. The code pops up ready to copy (Ctrl+C).
2. **Invite**: right-click the group name > Invite > pick a friend. They get a whisper with the code, which shows a clickable **[Join]** link in their Telegnome.
3. **Join**: **+ New group** > paste the code > Join, or `/tg join <code>`.

Everyone in the group needs Telegnome.

### Followed channels

Followed channels tab > **+ Follow channel** > tick what you want. Messages are copied into the tab and you can reply from there. Followed channels don't count towards the missed-messages counter, and their pop-ups are off by default.

## Known limits

- During combat or boss encounters the game may hide chat text from addons. Those messages stay in the main chat.
- Group chat members need to be able to join the same chat channels - usually the same realm (group) and faction.
- The game allows 10 chat channels per character (General, Trade etc. count). Each group chat uses one.
- A Battle.net friend whispering from their game character gets a separate character conversation.

## Saved data

History (last 200 messages per conversation), contacts, groups and settings are saved account-wide in
`WTF/Account/<account>/SavedVariables/Telegnome.lua`. Delete that file to reset Telegnome.

## For developers

```
Telegnome/               the addon folder (this is what goes into AddOns)
  Telegnome.toc          load order and metadata
  Core/Core.lua          saved data, whisper events, sending, chat filters, slash commands
  Core/Style.lua         shared classic-style widgets (panels, buttons, cogs)
  UI/UI.lua              main window, tabs, conversation view
  UI/Picker.lua          "New message" contact picker
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
