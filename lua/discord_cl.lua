local drawMute = false
local muteIcon = Material("materials/mute-icon.png")

net.Receive("drawMute",function()
	drawMute = net.ReadBool()
end)

hook.Add( "HUDPaint", "discord_HUDPaint", function()
	if (not drawMute) then return end
	if (muteIcon:IsError()) then return end
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(muteIcon)
	surface.DrawTexturedRect(0, 0, 128, 128)
end )
