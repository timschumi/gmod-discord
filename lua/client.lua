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
