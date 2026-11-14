# Changelog

## 0.7.0
- Requests tab: while you or your group are listed in the group finder, whispers from people who aren't friends, guild members or favorites are collected in their own tab instead of under Direct messages.
- Each request shows the player's class, level and latest message, with Invite, look-up and dismiss buttons. Click a request to open the conversation.
- Level comes from the whisper ("70 mage", "lvl 45"), from their group finder application, or from the Level? button (a /who look-up).
- Star a request to keep the person (they move to Direct messages); Clear all removes the rest.
- `/tg recruit` or the tick in the Requests view collects whispers there at any time; a setting turns the automatic collecting off.
- Colour themes: Brass (the original), Orange, Horde red, Alliance blue, Arcane, Fel green and Steel. Choose in Settings > Window or with `/tg theme <name>`.

## 0.6.0
- Direct messages are grouped into Favorites, Friends and Others. Star a conversation to pin it to Favorites; Friends are Battle.net friends, your friends list and guild members; Others can be folded away or closed all at once.
- Delivery feedback: "player offline / not found", away, busy and ignored replies now show in the conversation.
- Forget contact: right-click someone in New message (or a conversation) to remove them.
- Shift-click items, quests and other links into Telegnome's message box.
- Key bindings (Options > Keybindings > AddOns): open/close Telegnome, open the newest unread message.
- Group chats: an Online button lists who is in the group right now, and grey lines show who joins and leaves.
- Alert words for followed channels: a message containing one pops up even without the Pop-up tick.
- A see-through window turns solid under the mouse or while typing (optional).
- Enter puts the cursor in Telegnome while its window is open on a conversation; Enter again on the empty box opens the game's chat (optional).
- Settings > Your data explains what is saved and where, shows how much is saved, and can delete all messages.
- Whispers to people on your own realm are addressed by their bare name, with one automatic retry as Name-Realm if the game can't find them.
- Rename group chats (right-click the group, or the Rename button).
- Group codes are shared as `Telegnome code: ...`. When someone sends one in any chat (whisper, party, guild...), Telegnome remembers it and fills it in when you click + New group.
- New invite codes are seeded from the date and time and end in a 3-digit number. Old codes keep working.
- Do not disturb: no pop-ups or sounds, optional auto-reply with your own message. Toggle with `/tg dnd` or Ctrl-click the notifier or minimap button.
- Clearer Settings button (labelled, with a wrench icon).
- Per-channel Pop-up checkbox for followed channels (replaces the single global setting).
- Clear history for a single conversation without closing it.
- Settings panel scrolls.
- Window opacity slider (Settings > Window, or `/tg opacity 30-100`) to make the main window see-through. Default is fully opaque.
- "Only in Telegnome": one setting (or `/tg only`) keeps whispers, Battle.net whispers and followed channels out of the main chat. Group chats always stay in Telegnome.
- Sound reworked: works whether or not whispers are hidden, plays even with game sound effects off, choice of Chime / Whisper / Ping with a Test button, also for group chats and followed channels with Pop-up on. Off by default (also switched off once when upgrading).
- Your chat channels: a list of every channel the character is in (Blizzard, custom, Telegnome groups) with how many of the 10 slots are used and Leave buttons. Open it from Settings, the Group chats panel or `/tg mychannels`.
- Telegnome group channels without a matching group (e.g. made on another computer) show up under Group chats as "Unknown group" so they can be renamed, given their code, or left.

## 0.5.0
- Followed channels tab: mirror Guild, Officer, Party, Raid, Instance, Say, Yell and joined channels (General, Trade, custom), with replies.
- Option to hide followed channels from the main chat; separate pop-up setting (off by default).
- Notifier can grow to the left or right.

## 0.4.0
- Group chats: private, password-protected channels joined with invite codes.
- Invite friends by whisper with a clickable Join link.
- Tabs for Direct messages and Group chats.

## 0.3.0
- Classic look: dialog border, bronze panels, gold text, brass cogs.
- New icon.
- Notifier: on-screen missed-messages counter that grows to show new messages.
- Settings panel: who triggers notifications, counter options, sound, minimap button.

## 0.2.0
- Remembered contacts and a New message picker.
- Minimap button with unread badge.
- Pop-up notifications.
- Right-click player menu.

## 0.1.0
- First version: whispers and Battle.net whispers in a messenger window with saved history and replies.
