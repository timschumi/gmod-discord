AddCSLuaFile()
resource.AddFile("materials/mute-icon.png")
if (CLIENT) then

	local drawMute = false
	local muteIcon = Material("materials/mute-icon.png")

	net.Receive("drawMute",function()
		drawMute = net.ReadBool()
	end)

	hook.Add( "HUDPaint", "ttt_discord_bot_HUDPaint", function()
		if (!drawMute) then return end
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(muteIcon)
		surface.DrawTexturedRect(0, 0, 128, 128)
	end )


	return
end
util.AddNetworkString("drawMute")

HOST = '<fill-in>'
PORT = 37405
FILEPATH = "ttt_discord_bot.dat"
TRIES = 3
SERVER_ID="<fill-in>"

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

function GET(req,params,cb,tries)
	http.Fetch("http://"..HOST..":"..PORT..req,function(res)
		cb(util.JSONToTable(res))
	end,function(err)
		log_con_err("Request to bot failed. Error: "..err)
		if (!tries) then tries = TRIES end
		if (tries != 0) then GET(req,params,cb, tries-1) end
	end,{req=req,params=util.TableToJSON(params)})
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
	if (ids[ply:SteamID()]) then
		if (!isMuted(ply)) then
			GET("/mute/"..SERVER_ID.."/"..ids[ply:SteamID()].."/1",{},function(res)
				if (res) then
					if (res.success) then
						ply:PrintMessage(HUD_PRINTCENTER,"You're muted in discord!")
						sendClientIconInfo(ply,true)
						muted[ply] = true
					end
					if (res.error) then
						log_con_err("Mute error: "..res.error)
					end
				end

			end)
		end
	end
end

function unmute(ply)
	if (ply) then
		if (ids[ply:SteamID()]) then
			if (isMuted(ply)) then
				GET("/mute/"..SERVER_ID.."/"..ids[ply:SteamID()].."/0", {},function(res)
					if (res.success) then
						ply:PrintMessage(HUD_PRINTCENTER,"You're no longer muted in discord!")
						sendClientIconInfo(ply,false)
						muted[ply] = false
					end
					if (res.error) then
						log_con_err("Unmuting error: "..res.error)
					end
				end)
			end
		end
	else
		for ply,val in pairs(muted) do
			if val then unmute(ply) end
		end
	end
end

hook.Add("PlayerSay", "ttt_discord_bot_PlayerSay", function(ply,msg)
  if (string.sub(msg,1,9) != '!discord ') then return end
  tag = string.sub(msg,10)
  tag_utf8 = ""
  
  for p, c in utf8.codes(tag) do
	tag_utf8 = string.Trim(tag_utf8.." "..c)
  end
	GET("/connect/"..SERVER_ID.."/"..tag,{tag=tag_utf8},function(res)
                if (res.error ~= nil) then
                    ply:PrintMessage(HUD_PRINTTALK,"Error: "..res.error)
                end
		if (res.tag && res.id) then
			ply:PrintMessage(HUD_PRINTTALK,"Discord tag '"..res.tag.."' successfully boundet to SteamID '"..ply:SteamID().."'") --lie! actually the discord id is bound! ;)
			ids[ply:SteamID()] = res.id
			saveIDs()
		end
	end)
	return ""
end)

hook.Add("PlayerInitialSpawn", "ttt_discord_bot_PlayerInitialSpawn", function(ply)
	if (ids[ply:SteamID()]) then
		ply:PrintMessage(HUD_PRINTTALK,"You are connected with discord.")
	else
		ply:PrintMessage(HUD_PRINTTALK,"You are not connected with discord. Write '!discord DISCORDTAG' in the chat. E.g. '!discord marcel.js#4402'")
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
