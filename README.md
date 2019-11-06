# TTT Discord Bot

This is a Discord bot for the TTT gamemode in Garry's Mod that directly interfaces with the Discord API.
It automatically mutes players when they die in-game and unmutes them when revived.

The plugin doesn't work fully standalone right now, since direct HTTP accesses to the Discord API from
the GMod User-Agent are disallowed. You will either need an utility that proxies requests with a
custom User-Agent or through a custom HTTP library that allows for changing the User-Agent
(for example the [CHTTP project](https://github.com/timschumi/gmod-chttp), which will be used automatically
if it's installed).

## Caveats

* Since the Discord developers aren't particularly fond of GMod interfacing with the Discord API, I built in a failsafe to not get on their nerves. It will shut
  down all HTTP requests if an unexpected error is encountered.

* This plugin does not have a channel filter. It will mute/unmute people no matter which channel they are in (as long as they are on the Garry's Mod server).
  This could be restricted by allowing the bot permissions by-channel, but a "permission denied" error can cause the failsafe to activate.

* The bot does not have player verification. A player can put in the Tag of any User on the server when connecting his Steam account.

## Setup (server-side)

1. Copy the files from this repository into a new Folder in `garrysmod/addons/`.

2. Create an Application with an attached Bot user in the [Discord Developer Portal](https://discordapp.com/developers/applications) and fill in the Client Secret into the `discord_token` variable in the console.

3. Invite the Bot to your server and allow it to mute players (either globally or per-channel).

4. Copy the [Guild ID](https://support.discordapp.com/hc/en-us/articles/206346498) and fill it into the `discord_guild` variable in the console.

## Setup (client-side)

The only thing that the player has to do is to bind his Discord user to his Steam ID.
This is done by entering `!discord <ident>` into the Garry's Mod chat.

`ident` can be one of the following:

- Snowflake-ID (obtained by right-clicking yourself in the user list and pressing "Copy ID" while in Developer Mode)
- Full username with discriminator (e.g. `timschumi#0319`)
- "Small" username (e.g. `timschumi`)
- Guild-specific nickname

The plugin will choose the first match that it encounters. If the correct one isn't chosen while using
a nickname or "small" username, please use a more uniquely identifying option, like the full username
with discriminator or the Snowflake-ID.

## Credits
**marceltransier** for the [original plugin/bot combo](https://github.com/marceltransier/ttt_discord_bot) that this is based on.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
