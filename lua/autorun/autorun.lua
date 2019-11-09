AddCSLuaFile()
AddCSLuaFile("printchat_cl.lua")
AddCSLuaFile("client.lua")

resource.AddFile("materials/mute-icon.png")

if CLIENT then
	include("printchat_cl.lua")
	include("client.lua")
end

if SERVER then
	include("printchat_sv.lua")
	include("server.lua")
end
