# Changelog

## 0.8.1
- New setting (Settings > Chat): "Keep typing after sending a message". On by default; untick it and the message box lets go after each message, like the game's chat.
- Slaay mode: the rainbow stripe no longer runs through the tab names.

## 0.8.0

A new look
- Unread messages show as small badges on the tabs, the sections and each conversation, instead of red numbers. The count is no longer repeated in the window's title.
- The window uses the game's own frame: the metal border, the title bar and the red close button, with Telegnome's cog in the round medallion. Settings is the cog at the right end of the tab row. The tagline is in the cog's tooltip.
- Tabs are boxed like the game's own, lit when you're on them, with the unread badge inside.
- The list shows two lines per conversation: the name with the time of the newest message, and a preview of it with the unread badge. Online dots are round and every name lines up.
- Favorites, Friends and Others have quieter headers with an arrow to fold them. "Close all" appears when you point at the Others header.
- The conversation shows the name large with the realm (and level and class when known) small underneath. The star stays; Clear history moved into the new ... menu next to it, which also has mute and close.
- Every message has its own bubble: yours on the right in a warmer colour, theirs on the left. The first in a run carries the name and time, the following ones sit close underneath; point at any bubble to see when it was sent. Days are separated by a small centred date.
- The message box says who you're writing to while it's empty.
- Requests uses the whole window: each request is a card with the level in a badge, the class in its colour and Invite as the one highlighted button. Clear all and Decline all are at the bottom, and a thin bar on the right shows when there are more requests than fit.
- Compact chat (Settings > Window): one line per message, without bubbles, for those who prefer the old look.
- Settings has its categories on the left (Notifications, Do not disturb, Window, Chat, Requests, Your data) and shows one at a time.
- Panels and buttons inside the window have thin borders in the theme colour. The window's own border stays the game's gold in every theme, and the notifier has the game's tooltip border.
- The window is a little larger by default (smallest size 700 x 490).

Fixes
- With a see-through window, the conversation and the list no longer show through Settings, Requests and the other panels.
- + New message could fail to open since 0.7.0 (an error the game hides by default). It opens again.


## 0.7.2
- Followed Party, Raid and Instance chat: joining a new group adds a "New group" line, so you can see where the current group starts. A new option in the Followed channels panel empties those conversations instead.
- Requests: after a Check, the line under the title shows the result and how long until the next check is possible.

## 0.7.1
- Followed channels: the Pop-up ticks for "Your channels" no longer stick out past the window's edge; that column now follows the window's width.
- The main window is a little wider by default (and its smallest size is a little wider too).
- Your chat channels: the "Telegnome group" label is no longer covered by the Open button.
- Clicking a tab closes Settings (and any other open panel) and shows that tab.
- The Settings title uses the same cog as the other panels.
- The wrench on the Settings button has more room from the button's edge.

## 0.7.0

Requests tab
- While you're listed in the group finder (alone, or as your group's leader), whispers from people who aren't friends, guild members or favorites are collected in a new Requests tab instead of piling up under Direct messages. A pop-up tells you when it starts.
- Each request shows the player's name, level, class and latest message. People who applied through the group finder also show their role and item level.
- Invite invites them to your group, x dismisses the request, and clicking the row opens the conversation.
- Reply offers one-click answers, and Decline sends your decline message and dismisses the request. Edit the texts in Settings > Requests.
- The level is read from the whisper ("70 mage", "lvl 45") or from their group finder application. Check looks the player up, also when a level looks wrong, and counts down until the game will answer again.
- Decline all sends your decline message to everyone still waiting and takes them off the list. People you invited or who are in your group stay.
- Star a request to keep the person (they move to Direct messages). Clear all removes the rest.
- "Collect whispers" in the Requests view is ticked by default; untick it to pause. `/tg recruit` collects at any time, listed or not.

Also new
- Colour themes: Brass (the original), Orange, Horde red, Alliance blue, Arcane, Fel green and Steel. Choose in Settings > Window or with `/tg theme <name>`.
- Mute a conversation, group or followed channel (right-click): no pop-ups or sound, messages still arrive.
- Message text size: small, normal or large (Settings > Window).

Fixes
- The unread count on the Others header is no longer hidden behind the Close all button.
- Section headers use plain + and - signs instead of red buttons.

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
