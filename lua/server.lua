util.AddNetworkString("drawMute")

FILEPATH = "ttt_discord_bot.dat"
BOT_TOKEN = "<fill-in>"
GUILD_ID = "<fill-in>"
DC_DISABLED = false

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
	DC_DISABLED = true
	log_con("Disabling requests to not get on the Discord developers' nerves!")
end

function request(method, endpoint, callback, body, contenttype)
	if DC_DISABLED then
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
		url = "https://discordapp.com/api"..endpoint,
		method = method,
		body = body,
		["type"] = contenttype,
		headers = {
			["Authorization"] = "Bot "..BOT_TOKEN,
			["User-Agent"] = "DiscordBot (https://github.com/timschumi/gmod-discord, v1.0)"
		}
	})
end

function sendClientIconInfo(ply,mute)
	net.Start("drawMute")
	net.WriteBool(mute)
	net.Send(ply)
end

function isMuted(ply)
	return muted[ply]
end

function mute(ply)
	if (not ids[ply:SteamID()]) then
		return
	end

	if (isMuted(ply)) then
		return
	end

	request("PATCH", "/guilds/"..GUILD_ID.."/members/"..ids[ply:SteamID()], function(code, body, headers)
		if code == 204 then
			ply:PrintMessage(HUD_PRINTCENTER, "You're muted in Discord!")
			sendClientIconInfo(ply, true)
			muted[ply] = true
			return
		end

		log_con_err("Error while muting:")
		log_con_err("code: "..code)
		log_con_err("guild: "..GUILD_ID)
		log_con_err("member: "..ids[ply:SteamID()])
		log_con_err("body start--")
		log_con_err(body)
		log_con_err("body end--")
		dc_disable()
	end, '{"mute": true}', "application/json")
end

function unmute(ply)
	if (not ply) then
		for ply,val in pairs(muted) do
			if val then unmute(ply) end
		end
		return
	end

	if (not ids[ply:SteamID()]) then
		return
	end

	if (not isMuted(ply)) then
		return
	end

	request("PATCH", "/guilds/"..GUILD_ID.."/members/"..ids[ply:SteamID()], function(code, body, headers)
		if code == 204 then
			ply:PrintMessage(HUD_PRINTCENTER, "You're no longer muted in Discord!")
			sendClientIconInfo(ply, false)
			muted[ply] = false
			return
		end

		log_con_err("Error while unmuting:")
		log_con_err("code: "..code)
		log_con_err("guild: "..GUILD_ID)
		log_con_err("member: "..ids[ply:SteamID()])
		log_con_err("--body")
		log_con_err(body)
		log_con_err("--body")
		dc_disable()
	end, '{"mute": false}', "application/json")
end

hook.Add("PlayerSay", "ttt_discord_bot_PlayerSay", function(ply,msg)
	if (string.sub(msg,1,9) != '!discord ') then return end
	id = string.sub(msg,10)

	request("GET", "/guilds/"..GUILD_ID.."/members/"..id, function(code, body, headers)
		if code == 404 then
			ply:PrintMessage(HUD_PRINTTALK, "Discord user with ID '"..id.."' does not exist on Discord guild with ID '"..GUILD_ID.."' (Or I don't have access to the user list on that server)")
			return
		end

		if code != 200 then
			log_con_err("Non-200 (and non-404) status code while finding users:")
			log_con_err("code: "..code)
			log_con_err("guild: "..GUILD_ID)
			log_con_err("member: "..id)
			log_con_err("--body")
			log_con_err(body)
			log_con_err("--body")
			dc_disable()
			return
		end

		body_json = util.JSONToTable(body)

		if not body_json or not body_json.user or not body_json.user.username then
			log_con_err("Couldn't find username field (or couldn't read JSON) while finding users:")
			log_con_err("code: "..code)
			log_con_err("guild: "..GUILD_ID)
			log_con_err("member: "..id)
			log_con_err("--body")
			log_con_err(body)
			log_con_err("--body")
			dc_disable()
			return
		end

		ply:PrintMessage(HUD_PRINTTALK, "SteamID '"..ply:SteamID().."' successfully bound to Discord user '"..body_json.user.username.."'")
		ids[ply:SteamID()] = id
		saveIDs()
	end)

	return ""
end)

hook.Add("PlayerInitialSpawn", "ttt_discord_bot_PlayerInitialSpawn", function(ply)
	if (ids[ply:SteamID()]) then
		ply:PrintMessage(HUD_PRINTTALK,"You are connected with Discord.")
	else
		ply:PrintMessage(HUD_PRINTTALK,"You are not connected with Discord. Write '!discord DISCORD-ID' in the chat. E.g. '!discord 296323983819669514'")
	end
end)

hook.Add("PlayerSpawn", "ttt_discord_bot_PlayerSpawn", function(ply)
  unmute(ply)
end)
hook.Add("PlayerDisconnected", "ttt_discord_bot_PlayerDisconnected", function(ply)
  unmute(ply)
end)
hook.Add("ShutDown","ttt_discord_bot_ShutDown", function()
  unmute()
end)
hook.Add("TTTEndRound", "ttt_discord_bot_TTTEndRound", function()
	timer.Simple(0.1,function() unmute() end)
end)
hook.Add("TTTBeginRound", "ttt_discord_bot_TTTBeginRound", function()--in case of round-restart via command
  unmute()
end)
hook.Add("PostPlayerDeath", "ttt_discord_bot_PostPlayerDeath", function(ply)
	if (GetRoundState() == 3) then
		mute(ply)
	end
end)
