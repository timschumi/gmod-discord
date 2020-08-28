net.Receive("printChat", function()
	local items = {}

	local id = net.ReadString()
	while id ~= "e" do
		if id == "s" then
			table.insert(items, net.ReadString())
		elseif id == "t" then
			table.insert(items, net.ReadTable())
		end
		id = net.ReadString()
	end

	chat.AddText(unpack(items))
end)
