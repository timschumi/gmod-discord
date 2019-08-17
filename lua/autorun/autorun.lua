addCSLuaFile()
addCSLuaFile("shared.lua")
addCSLuaFile("client.lua")

include("shared.lua")

if CLIENT then
	include("client.lua")
end

if SERVER then
	include("server.lua")
end
