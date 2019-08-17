AddCSLuaFile()
AddCSLuaFile("shared.lua")
AddCSLuaFile("client.lua")

include("shared.lua")

if CLIENT then
	include("client.lua")
end

if SERVER then
	include("server.lua")
end
