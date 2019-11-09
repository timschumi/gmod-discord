AddCSLuaFile()
AddCSLuaFile("client.lua")

resource.AddFile("materials/mute-icon.png")

if CLIENT then
	include("client.lua")
end

if SERVER then
	include("server.lua")
end
