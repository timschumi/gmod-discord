net.Receive("printChat", function()
	local items = {}

	while net.BytesLeft() ~= 0 do
		local id = net.ReadString()
		if id == "s" then
			table.insert(items, net.ReadString())
		elseif id == "t" then
			table.insert(items, net.ReadTable())
		end
	end

	chat.AddText(unpack(items))
end)
