net.Receive("printChat", function()
	local items = {}

	for _ = 1, net.ReadUInt(16) do
		items[#items + 1] = net.ReadType()
	end

	chat.AddText(unpack(items))
end)
