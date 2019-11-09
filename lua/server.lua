util.AddNetworkString("drawMute")

FILEPATH = "ttt_discord_bot.dat"
cvar_guild = CreateConVar("discord_guild", "", FCVAR_ARCHIVE, "The guild/server ID that should be acted upon.")
cvar_token = CreateConVar("discord_token", "", FCVAR_ARCHIVE + FCVAR_DONTRECORD + FCVAR_PROTECTED + FCVAR_UNLOGGED + FCVAR_UNREGISTERED, "The Discord bot token that the plugin uses.")
cvar_enabled = CreateConVar("discord_enabled", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Whether the Discord bot is enabled at all.")
cvar_api = CreateConVar("discord_api", "https://discordapp.com/api", FCVAR_ARCHIVE, "The API server that the bot should use.")

muted = {}

ids = {}
ids_raw = file.Read( FILEPATH, "DATA" )
if (ids_raw) then
	ids = util.JSONToTable(ids_raw)
end

if pcall(require, "chttp") then
	HTTP = CHTTP
end

function saveIDs()
	file.Write( FILEPATH, util.TableToJSON(ids))
end

function log_con(text)
	print("[Discord] "..text)
end

function log_con_err(text)
	log_con("[ERROR] "..text)
end

function dc_disable()
	cvar_enabled:SetBool(false)
	log_con("Disabling requests to not get on the Discord developers' nerves!")
end

function request(method, endpoint, callback, body, contenttype)
	if cvar_guild:GetString() == "" then
		log_con_err("The guild has not been set!")
		return
	end
	if cvar_token:GetString() == "" then
		log_con_err("The bot token has not been set!")
		return
	end
	if !cvar_enabled:GetBool() then
		log_con_err("HTTP requests are disabled!")
		return
	end
	HTTP({
		failed = function(err)
			log_con_err("HTTP error during request")
			log_con_err("method: "..method)
			log_con_err("endpoint: '"..endpoint.."'")
			log_con_err("err: "..err)
		end,
		success = callback,
		url = cvar_api:GetString()..endpoint,
		method = method,
		body = body,
		["type"] = contenttype,
		headers = {
			["Authorization"] = "Bot "..cvar_token:GetString(),
			["User-Agent"] = "DiscordBot (https://github.com/timschumi/gmod-discord, v1.0)"
		}
	})
end

-- success/fail are callback functions that handle a search result.
-- success gets two arguments, the user ID as the first and `<username>#<discriminator>` as the second.
-- fail gets a single argument, the reason as a text.
function resolveUser(search, success, fail, after)
	endpoint = "/guilds/"..cvar_guild:GetString().."/members?limit=20"
	if after then
		endpoint = endpoint.."&after="..after
	end

	request("GET", endpoint, function(code, body, headers)
		if code == 403 then
			fail("I do not have access to the user list of the Discord server!")
			return
		end

		if code != 200 then
			fail("Got an HTTP error code that is neither 200, nor 403: "..code)
			return
		end

		response = util.JSONToTable(body)

		for _, entry in pairs(response) do
			last = entry.user.id
			discriminator = entry.user.username.."#"..entry.user.discriminator

			if search == entry.user.id or -- Snowflake-ID
			   search == discriminator or -- Full username
			   search == entry.user.username or -- "small" username
			   search == entry.nick then -- Nickname
				success(entry.user.id, discriminator)
				return
			end
		end

		if table.getn(response) == 20 then
			resolveUser(search, success, fail, last)
			return
		end

		fail("Could not find user in user list.")
	end)
end

function sendClientIconInfo(ply,mute)
	net.Start("drawMute")
	net.WriteBool(mute)
	net.Send(ply)
end

function isMuted(ply)
	return muted[ply] == true
end

function mute(val, ply)
	-- Sanitize val
	val = (val == true)

	-- Unmute all if we're unmuting and no player is given
	if (not val and not ply) then
		for ply,state in pairs(muted) do
			if state then mute(false, ply) end
		end
		return
	end

	-- Do we have a saved Discord ID?
	if (not ids[ply:SteamID()]) then
		return
	end

	-- Is the player already muted/unmuted?
	if (val == isMuted(ply)) then
		return
	end

	request("PATCH", "/guilds/"..cvar_guild:GetString().."/members/"..ids[ply:SteamID()], function(code, body, headers)
		if code == 204 then
			if val then
				ply:PrintMessage(HUD_PRINTCENTER, "You're muted in Discord!")
			else
				ply:PrintMessage(HUD_PRINTCENTER, "You're no longer muted in Discord!")
			end
			sendClientIconInfo(ply, val)
			muted[ply] = val
			return
		end

		response = util.JSONToTable(body)

		error = "Error while muting: "..code.."/"..response.code.." - "..response.message

		printChat(ply, Color(255, 70, 70), error)
		log_con_err(error.." ("..ply:GetName()..")")

		-- Don't activate the failsafe on the following errors
		if code == 400 and response.code == 40032 then -- Target user is not connected to voice.
			return
		end

		dc_disable()
	end, '{"mute": '..tostring(val)..'}', "application/json")
end

function sendHelp(ply)
	printChat(ply, "Say '!discord <ident>' in the chat to connect to Discord.")
	printChat(ply, "'ident' can be one of the following:")
	printChat(ply, "  - Snowflake-ID (right-click in user list > 'Copy ID' while in developer mode)")
	printChat(ply, "  - Full username with discriminator (e.g. 'timschumi#0319')")
	printChat(ply, "  - \"Small\" username (e.g. 'timschumi')")
	printChat(ply, "  - Guild-specific nickname")
end

hook.Add("PlayerSay", "ttt_discord_bot_PlayerSay", function(ply,msg)
	if (string.sub(msg,1,8) != '!discord') then return end
	id = string.sub(msg,10)

	if id == "" then
		sendHelp(ply)
		return ""
	end

	resolveUser(id, function(id, name)
		printChat(ply, Color(70, 255, 70), "Discord user '"..name.."' successfully bound to SteamID '"..ply:SteamID().."'")
		printChat(ply, Color(240, 240, 240), "If I chose the wrong user, please use an unique identifying option, like the full username or the Snowflake-ID.")
		ids[ply:SteamID()] = id
		saveIDs()
	end, function(reason)
		printChat(ply, Color(255, 70, 70), reason)
	end)

	return ""
end)

hook.Add("PlayerInitialSpawn", "ttt_discord_bot_PlayerInitialSpawn", function(ply)
	if (ids[ply:SteamID()]) then
		printChat(ply, "You are connected to Discord.")
	else
		printChat(ply, "You are not connected to Discord.")
		sendHelp(ply)
	end
end)

hook.Add("PlayerSpawn", "ttt_discord_bot_PlayerSpawn", function(ply)
  mute(false, ply)
end)
hook.Add("PlayerDisconnected", "ttt_discord_bot_PlayerDisconnected", function(ply)
  mute(false, ply)
end)
hook.Add("ShutDown","ttt_discord_bot_ShutDown", function()
  mute(false)
end)
hook.Add("TTTEndRound", "ttt_discord_bot_TTTEndRound", function()
	timer.Simple(0.1,function() mute(false) end)
end)
hook.Add("TTTBeginRound", "ttt_discord_bot_TTTBeginRound", function()--in case of round-restart via command
  mute(false)
end)
hook.Add("PostPlayerDeath", "ttt_discord_bot_PostPlayerDeath", function(ply)
	if (GetRoundState() == 3) then
		mute(true, ply)
	end
end)
