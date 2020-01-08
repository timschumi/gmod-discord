util.AddNetworkString("drawMute")

cvar_guild = CreateConVar("discord_guild", "", FCVAR_ARCHIVE, "The guild/server ID that should be acted upon.")
cvar_token = CreateConVar("discord_token", "", FCVAR_ARCHIVE + FCVAR_DONTRECORD + FCVAR_PROTECTED + FCVAR_UNLOGGED + FCVAR_UNREGISTERED, "The Discord bot token that the plugin uses.")
cvar_enabled = CreateConVar("discord_enabled", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Whether the Discord bot is enabled at all.")
cvar_api = CreateConVar("discord_api", "https://discordapp.com/api", FCVAR_ARCHIVE, "The API server that the bot should use.")

muted = {}

ids = KeyValStore:new("discord.dat")

function log_con(text)
	print("[Discord] "..text)
end

function log_con_err(text)
	log_con("[ERROR] "..text)
end

if pcall(require, "steamhttp") then
	log_con("Using STEAMHTTP implementation.")
	HTTP = STEAMHTTP
elseif pcall(require, "chttp") then
	log_con("Using CHTTP implementation.")
	HTTP = CHTTP
else
	log_con("Using default HTTP implementation.")
end

function dc_disable()
	cvar_enabled:SetBool(false)
	log_con("Disabling requests to not get on the Discord developers' nerves!")
end

function request(method, endpoint, callback, body)
	if cvar_guild:GetString() == "" then
		log_con_err("The guild has not been set!")
		return
	end
	if cvar_token:GetString() == "" then
		log_con_err("The bot token has not been set!")
		return
	end
	frequest(method, endpoint, callback, body)
end

function frequest(method, endpoint, callback, body)
	if !cvar_enabled:GetBool() then
		log_con_err("HTTP requests are disabled!")
		return
	end
	req = {
		failed = function(err)
			log_con_err("HTTP error during request")
			log_con_err("method: "..method)
			log_con_err("url: '"..cvar_api:GetString()..endpoint.."'")
			log_con_err("endpoint: '"..endpoint.."'")
			log_con_err("err: "..err)
		end,
		success = callback,
		url = cvar_api:GetString()..endpoint,
		method = method,
		body = body,
		useragent = "timschumi/gmod-discord",
		headers = {
			["Authorization"] = "Bot "..cvar_token:GetString(),
			["User-Agent"] = "DiscordBot (https://github.com/timschumi/gmod-discord, v1.0)"
		}
	}

	if (body) then
		req["type"] = "application/json"
	end

	HTTP(req)
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
	if (not ids:get(ply:SteamID())) then
		return
	end

	-- Is the player already muted/unmuted?
	if (val == isMuted(ply)) then
		return
	end

	request("PATCH", "/guilds/"..cvar_guild:GetString().."/members/"..ids:get(ply:SteamID()), function(code, body, headers)
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
	end, '{"mute": '..tostring(val)..'}')
end

function sendHelp(ply)
	printChat(ply, "Say '!discord <ident>' in the chat to connect to Discord.")
	printChat(ply, "'ident' can be one of the following:")
	printChat(ply, "  - Snowflake-ID (right-click in user list > 'Copy ID' while in developer mode)")
	printChat(ply, "  - Full username with discriminator (e.g. 'timschumi#0319')")
	printChat(ply, "  - \"Small\" username (e.g. 'timschumi')")
	printChat(ply, "  - Guild-specific nickname")
end

hook.Add("PlayerSay", "discord_PlayerSay", function(ply,msg)
	if (string.sub(msg,1,8) != '!discord') then return end
	id = string.sub(msg,10)

	if id == "" then
		sendHelp(ply)
		return ""
	end

	resolveUser(id, function(id, name)
		printChat(ply, Color(70, 255, 70), "Discord user '"..name.."' successfully bound to SteamID '"..ply:SteamID().."'")
		printChat(ply, Color(240, 240, 240), "If I chose the wrong user, please use an unique identifying option, like the full username or the Snowflake-ID.")
		ids:set(ply:SteamID(), id)
	end, function(reason)
		printChat(ply, Color(255, 70, 70), reason)
	end)

	return ""
end)

hook.Add("PlayerInitialSpawn", "discord_PlayerInitialSpawn", function(ply)
	if (ids:get(ply:SteamID())) then
		printChat(ply, "You are connected to Discord.")
	else
		printChat(ply, "You are not connected to Discord.")
		sendHelp(ply)
	end
end)

-- General mute/unmute hooks
hook.Add("PlayerSpawn", "discord_PlayerSpawn", function(ply)
	-- Don't unmute if we joined spectator deathmatch
	if ply:GetNWBool("SpecDM_Enabled", false) then
		return
	end

	mute(false, ply)
end)

hook.Add("PlayerDisconnected", "discord_PlayerDisconnected", function(ply)
	mute(false, ply)
end)

hook.Add("ShutDown","discord_ShutDown", function()
	mute(false)
end)

hook.Add("PostPlayerDeath", "discord_PostPlayerDeath", function(ply)
	if (GetRoundState() == 3) then
		mute(true, ply)
	end
end)

-- Trouble in Terrorist Town mute/unmute hooks
hook.Add("TTTEndRound", "discord_TTTEndRound", function()
	timer.Simple(0.1,function() mute(false) end)
end)

hook.Add("TTTBeginRound", "discord_TTTBeginRound", function()--in case of round-restart via command
	mute(false)
end)


cvars.AddChangeCallback("discord_api", function(name, old, new)
	frequest("GET", "/gateway", function(code, body, headers)
		if code == 200 then
			log_con("API URL is valid.")
		else
			log_con_err("API URL is invalid.")
		end
	end)
end)

cvars.AddChangeCallback("discord_token", function(name, old, new)
	frequest("GET", "/gateway/bot", function(code, body, headers)
		if code == 200 then
			log_con("Bot token is valid.")
		else
			log_con_err("Bot token is invalid.")
			log_con_err("Make sure that you copied the \"Token\", not the \"Client ID\" or the \"Client Secret\".")
		end
	end)
end)

cvars.AddChangeCallback("discord_guild", function(name, old, new)
	frequest("GET", "/guilds/"..new, function(code, body, headers)
		if code == 200 then
			log_con("Guild ID is valid and accessible.")
		else
			log_con_err("Guild ID is invalid (or could not be accessed).")
		end
	end)
end)
