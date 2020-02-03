AddCSLuaFile()
AddCSLuaFile("printchat_cl.lua")
AddCSLuaFile("discord_cl.lua")

resource.AddFile("materials/mute-icon.png")

if CLIENT then
	include("printchat_cl.lua")
	include("discord_cl.lua")
end

if SERVER then
hook.Add("Initialize", "discord_Initialize", function()
	include("printchat_sv.lua")
	include("discord_sv.lua")
end)
end
