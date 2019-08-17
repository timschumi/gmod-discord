util.AddNetworkString("drawMute")

FILEPATH = "ttt_discord_bot.dat"
BOT_TOKEN = "<fill-in>"
GUILD_ID = "<fill-in>"

muted = {}

ids = {}
ids_raw = file.Read( FILEPATH, "DATA" )
if (ids_raw) then
	ids = util.JSONToTable(ids_raw)
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

function request(method, endpoint, callback, parameters)
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
		parameters = parameters,
                headers = {
                        ["Authorization"] = "Bot "..self.token,
                        ["User-Agent"] = "DiscordBot (https://github.com/timschumi/SmallLuaDiscord, v0)"
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
	end, {
		mute = "true"
	})
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
	end, {
		mute = "false"
	})
end

hook.Add("PlayerSay", "ttt_discord_bot_PlayerSay", function(ply,msg)
	if (string.sub(msg,1,9) != '!discord ') then return end
	id = string.sub(msg,10)

	request("GET", "/guilds/"..GUILD_ID.."/members/"..id, function(code, body, headers)
		body_json = util.JSONToTable(body)

		if (body_json.user.username) then
			ply:PrintMessage(HUD_PRINTTALK, "SteamID '"..ply:SteamID().."' successfully bound to Discord user '"..body_json.user.username.."'")
			ids[ply:SteamID()] = id
			saveIDs()
			return
		end

		log_con_err("Error while finding user:")
		log_con_err("code: "..code)
		log_con_err("guild: "..GUILD_ID)
		log_con_err("member: "..id)
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