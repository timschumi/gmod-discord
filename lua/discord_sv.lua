if not pcall(include, "gmcompat.lua") or gmcompat == nil then
	ErrorNoHalt("[discord] [ERROR] The `gmcompat` library is not present or could not be loaded.\n")
	print("[discord] [ERROR] Please make sure that you are subscribed to the addon and/or added it to your server collection:")
	print("[discord] [ERROR] https://steamcommunity.com/workshop/filedetails/?id=2063714458")
	return
end

util.AddNetworkString("drawMute")

local cvar_guild = CreateConVar("discord_guild", "", FCVAR_ARCHIVE, "The guild/server ID that should be acted upon.")
local cvar_token = CreateConVar("discord_token", "", FCVAR_ARCHIVE + FCVAR_DONTRECORD + FCVAR_PROTECTED + FCVAR_UNLOGGED + FCVAR_UNREGISTERED, "The Discord bot token that the plugin uses.")
local cvar_enabled = CreateConVar("discord_enabled", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Whether the Discord bot is enabled at all.")
local cvar_api = CreateConVar("discord_api", "https://discordapp.com/api", FCVAR_ARCHIVE, "The API server that the bot should use.")

local muted = {}

local KeyValStore = include("keyvalstore.lua")

local ids = KeyValStore:new("discord.dat")

local function log(msg)
	print("[discord] "..msg)
end

local function err(msg)
	ErrorNoHalt("[discord] [ERROR] "..msg.."\n")
end

if pcall(require, "steamhttp") then
	log("Using STEAMHTTP implementation.")
	discordHTTP = STEAMHTTP
elseif pcall(require, "chttp") then
	log("Using CHTTP implementation.")
	discordHTTP = CHTTP
else
	log("Using default HTTP implementation.")
	discordHTTP = HTTP

	if cvar_api:GetString() == "https://discordapp.com/api" then
		err("Using the default HTTP implementation and API server. This is probably not what you want!")
	end
end

function request(method, endpoint, callback, body)
	if cvar_guild:GetString() == "" then
		err("The guild has not been set!")
		return
	end
	if cvar_token:GetString() == "" then
		err("The bot token has not been set!")
		return
	end
	frequest(method, endpoint, callback, body)
end

function frequest(method, endpoint, callback, body)
	if !cvar_enabled:GetBool() then
		err("HTTP requests are disabled!")
		return
	end
	req = {
		failed = function(err)
			err("HTTP: "..err)
			log("method: "..method)
			log("url: '"..cvar_api:GetString()..endpoint.."'")
			log("endpoint: '"..endpoint.."'")
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

	discordHTTP(req)
end

-- success/fail are callback functions that handle a search result.
-- success gets two arguments, the user ID as the first and `<username>#<discriminator>` as the second.
-- fail gets a single argument, the reason as a text.
function resolveUser(search, success, fail, after)
	endpoint = "/guilds/"..cvar_guild:GetString().."/members?limit=1000"
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

		if table.getn(response) == 1000 then
			local limit_remaining, limit_reset, delay

			-- Sanitize limit
			limit_remaining = headers["X-RateLimit-Remaining"] or headers["x-ratelimit-remaining"]
			if limit_remaining ~= nil then limit_remaining = tonumber(limit_remaining) end

			-- Sanitize reset
			limit_reset = headers["X-RateLimit-Reset"] or headers["x-ratelimit-reset"]
			if limit_reset ~= nil then limit_reset = tonumber(limit_reset) end

			delay = (limit_remaining == 0 and limit_reset - os.time() or 0)
			timer.Simple(delay, function() resolveUser(search, success, fail, last) end)
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

function mute(val, ply)
	-- Sanitize val
	val = (val == true)

	-- Unmute all if we're unmuting and no player is given
	if (not val and not ply) then
		unmute_count = 0
		for ply,state in pairs(muted) do
			if not state then
				continue
			end

			if not IsValid(ply) then
				muted[ply] = nil
				continue
			end

			mute(false, ply)
			unmute_count = unmute_count + 1

			-- Abort and continue in 10s if we sent 10 requests
			-- If a person dies on round end, there is a chance that
			-- this person is quick-toggled. We'll go safe by only
			-- unmuting 9 people at a time.
			if unmute_count == 9 then
				timer.Simple(10, function() mute(false) end)
				return
			end
		end
		return
	end

	-- Do we have a saved Discord ID?
	if (not ids:get(ply:SteamID())) then
		return
	end

	-- Is the player already muted/unmuted?
	if (val == (muted[ply] == true)) then
		return
	end

	muted[ply] = val
	request("PATCH", "/guilds/"..cvar_guild:GetString().."/members/"..ids:get(ply:SteamID()), function(code, body, headers)
		if code == 204 then
			if val then
				ply:PrintMessage(HUD_PRINTCENTER, "You're muted in Discord!")
			else
				ply:PrintMessage(HUD_PRINTCENTER, "You're no longer muted in Discord!")
			end
			sendClientIconInfo(ply, val)
			return
		end

		muted[ply] = not val
		response = util.JSONToTable(body)

		message = "Error while muting: "..code.."/"..response.code.." - "..response.message

		printChat(ply, Color(255, 70, 70), message)
		err(message.." ("..ply:GetName()..")")

		-- Don't activate the failsafe on the following errors
		if code == 400 and response.code == 40032 then -- Target user is not connected to voice.
			return
		end

		cvar_enabled:SetBool(false)
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
	local id = string.sub(msg,10)

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
timer.Simple(0.2, function()
	if (gmcompat.roundState() == 1) then
		mute(true, ply)
	end
end)
end)

gmcompat.hook("start", "discord_", function()
	mute(false)
end)

gmcompat.hook("end", "discord_", function()
	mute(false)
end)


cvars.AddChangeCallback("discord_api", function(name, old, new)
	frequest("GET", "/gateway", function(code, body, headers)
		if code == 200 then
			log("API URL is valid.")
		else
			log("API URL is invalid.")
		end
	end)
end)

cvars.AddChangeCallback("discord_token", function(name, old, new)
	frequest("GET", "/gateway/bot", function(code, body, headers)
		if code == 200 then
			log("Bot token is valid.")
		else
			log("Bot token is invalid.")
			log("Make sure that you copied the \"Token\", not the \"Client ID\" or the \"Client Secret\".")
		end
	end)
end)

cvars.AddChangeCallback("discord_guild", function(name, old, new)
	frequest("GET", "/guilds/"..new, function(code, body, headers)
		if code == 200 then
			log("Guild ID is valid and accessible.")
		else
			log("Guild ID is invalid (or could not be accessed).")
		end
	end)
end)
