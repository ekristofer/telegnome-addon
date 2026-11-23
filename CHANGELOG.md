# Changelog

## 0.9.2
- **Open for business**, in a new **Business** tab, for crafters, sellers and recruiters. Write your ad right there (shift-click your profession or an item to add the link), choose where it goes (Trade, Say, Guild...) and how long to stay open (15 minutes to 2 hours, or until you stop it), then press Start and Post. While it's open, whispers from people you don't know are collected in the tab as cards, with their own quick replies and decline message (Settings > Requests & Business). It tells you when it closes and how many whispers are waiting. Listing in the group finder pauses it, with a pop-up, and it opens again when you stop listing. Also `/tg business [minutes|off]`; the tab can be hidden in Settings.
- **Saved ads:** the Saved ads button next to the ad saves it for another time (up to 15), puts a saved one back in the box, or deletes one.
- While you're open for business, the on-screen counter shows a gold coin and the minutes left (grey while paused). Its tooltip says how long is left.
- Telegnome opens where you left it: on the tab and conversation you had open, or on the Requests or Business overview if that's where you were. Closing Settings also goes back to that overview.
- The Business tab's list buttons (how long, saved ads, where the ad goes) have a down arrow.
- **Filtered channels:** Channels tab > + Follow channel > **Filtered channels**: pick a channel, type words (e.g. `enchant, ench`) and click Add - no need to follow the whole channel. Or right-click a followed channel > New filtered copy.... You get a separate conversation like "Trade [Enchant]" that keeps only the messages with those words, and pops up when one comes in. Make as many as you like ("Trade [Enchant]", "Trade [Boost]"...), with or without following the whole channel. Change the words later from the same menu. Matching ignores upper and lower case; the name keeps your spelling ("Trade [LFW]"). Rename a filtered channel from its right-click menu, e.g. to just "LFW" - the menu still says it's Trade [LFW].
- Alert words per channel: right-click a followed channel > Alert words for this channel... (the words in Settings still count everywhere).
- Matching words are picked out in gold in channel messages.
- **New mail:** a pop-up when mail arrives, and when you log in with unread mail, saying who sent it ("New mail from Thrall and Stormwind Auction House (2)"). Change the text or turn it off in the new Settings > Notifications. The game names the latest three senders only; open a mailbox to read the mail.
- Right-click menus: Mute is now a tick box like the other settings. People and group chats have **Pop-up notifications and sound** (on unless you turn it off); followed channels keep their Pop-up notifications tick and get **Mute everything (alert words too)**.
- **Decline all in the Business tab has its own message**, separate from the one-person Decline: "Sorry, I'm done for now." Change it in Settings > Requests & Business, or leave it empty to clear the list without a message. Requests still sends its decline message for both. Fixed: in the Business tab, the Decline all pop-up showed the Requests decline message.
- Settings > Chats: hovering the greyed-out **Group chats (always)** tick now explains why it can't be turned off.
- **Settings, reorganised:** six pages instead of nine - Notifications (pop-ups, sound, combat, Do not disturb, group chats, mail), Look (window, counter, minimap), Chats, Requests & Business, Your data and Help - each with headings. A **search box** at the top finds any setting by a word (sound, archive, decline...) and takes you to it. The cog opens on the page for the tab you're on: from Business you get the Business replies, from Groups the group chat settings.
- **Requests and Business don't clash any more:** only one collects at a time, and the one started last wins. Listing in the group finder or Collect now pauses Business (it comes back when they stop), and starting Business pauses Collect now (it comes back when Business closes). A pop-up says what happened.
- **Help for every tab:** a **?** next to the Settings cog explains the tab you're on, and an empty tab shows the same text instead of a blank page. Settings > Help has all of it in one place.
- **Who's online in a group:** the button at the top of a group chat now says how many members are online ("3 online") and opens a list: a green dot for who's online, a grey dot for members seen before. Click a name to whisper them. The "X joined / left" lines are now off by default, so the chat is just messages (turn them back on in Settings > Notifications).
- **Group finder eye on the counter:** while Requests is collecting (listed in the group finder, or Collect now), the on-screen counter shows the group finder's eye, next to the Business coin.
- **The Requests tab is always there**, greyed out while it isn't collecting (hover it to see why). It starts by itself when you list in the group finder, and a new **Collect now** button collects at any time (the same as `/tg recruit`). Business is greyed out too while it's closed. Hide the Requests tab in Settings > Requests & Business to get the old behaviour.
- **Group chat invites pop up:** when someone sends you a group chat code, a pop-up says who invited you to which group. Click it and the join panel opens with the code and name filled in, so you only press Join.
- **Dungeon and raid chat pops up:** Party or Raid chat followed just for a dungeon or raid now has pop-up notifications on. New setting in Settings > Chats to turn them off (it still counts unread messages). A chat you already follow keeps its own settings.
- `/tg test stranger`: a whisper from a made-up player you don't know, handled like a real one, so you can try Open for business and Requests without waiting for someone to whisper you. Replies and invites to them stay on your computer.
- Fixed: Who's online in a group chat split names with a space in them (first and last name) into separate names. Whole names are now listed in alphabetical order.
- `/tg demo`: the window stays solid while the sample conversations are shown, whatever your opacity setting, so screenshots come out clean. Your opacity is back as soon as the demo is off.

## 0.9.1
- New setting, Settings > Notifications > In combat: **Show everything** (pop-ups and sounds as usual), **Summary afterwards** (one pop-up when the fight is over - the default, as before) or **Only the count** (no pop-ups or summary; the notifier, minimap button and badges still count up).

## 0.9.0

All your chats in one place
- **All tab:** a new first tab with everything in one list: Pinned, Direct messages (split into Friends and Others), Channels and Group chats. Group chats show a two-people icon and channels a #. The Direct, Channels and Groups tabs stay as filters. New installs start on All, and Telegnome opens on the tab you used last.
- **Pin anything:** the star works on group chats and channels too ("Favorites" is now "Pinned"). Reorder Pinned by dragging a conversation onto another, or with Move up / Move down in its right-click menu.
- **Archive:** a folded section at the bottom of the All and Direct tabs. Direct messages with nothing new for a week go there by themselves (Settings > Chat: choose the number of days, or turn it off), and you can archive one from its right-click menu. A new message brings it straight back. Close all on the Archive header closes every archived conversation; the people stay in New message.
- Every section folds with a click on its header. Right-click a header or a tab for Mark all as read and sorting.
- Sort the list by most recent, name or unread first: Settings > Window, right-click a section header, or `/tg sort`.
- A thin scroll indicator shows at the edge of the list when not everything fits.
- Tabs are ordered All, Direct, Channels, Groups (then Requests).

Followed channels
- The game's own chat colours (Guild green, Party blue, Raid orange...), also if you've changed them in the game.
- Right-click one to choose "Count unread messages" (a red badge that adds to the totals) and "Show in the All tab". Party, Raid and Instance count by default; other channels show a quiet dot instead of a number.

Dungeons, raids and combat
- Entering a dungeon offers to follow Party chat, a raid Raid chat (with Instance chat), until you leave. It's pinned while you're inside, with an "Entered ..." line where the run starts. Ask, Always or Never in Settings > Chat; `/tg follow-instance` does it by hand. If you pin it while inside, it stays followed when you leave.
- In combat, pop-ups and sounds wait until the fight is over, then one pop-up says what came in (Settings > Notifications).

Requests
- The row at the top shows a class icon and a count for each class that's waiting (the class comes with the first whisper). Click one to show only that class. Each request has its class icon by the name.
- Anyone you invite counts as Invited, however you invite them (Telegnome's button, the game's menu or /invite), and anyone in your group as In group. Decline all never sends them the decline message.
- Quick replies can use {name}, {class} and {level}, filled in for the person you answer.
- Item level is no longer shown. Level words and the level cap follow WoW Forever's classic classes.

People
- Search: the magnifier next to + New message (or `/tg search <text>`) finds messages in all conversations. "Search in this conversation" is in the ... menu. Click a result to open the conversation at that message.
- Notes: "Add note..." in a person's menu. The note shows under their name and on their request card.
- Recently grouped with: people you grouped with in the last week sort under Friends, and their whispers don't go to Requests. Can be turned off in Settings > Chat.
- On login, a line in chat tells you when unread messages are waiting (Settings > Notifications).

Fixes
- Right-clicking a Battle.net friend who is offline opens Telegnome's menu when the game's own menu doesn't appear.
- After closing a conversation or switching tabs, Telegnome opens the one at the top of the list, never one hidden in a folded section.

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
