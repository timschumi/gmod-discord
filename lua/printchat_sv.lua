util.AddNetworkString("printChat")

function printChat(ply, ...)
	net.Start("printChat")

	for i,v in ipairs{...} do
		if type(v) == "string" then
			net.WriteString("s")
			net.WriteString(v)
		elseif type(v) == "table" then
			net.WriteString("t")
			net.WriteTable(v)
		end
	end

	if ply == nil then
		net.Broadcast()
	else
		net.Send(ply)
	end
end

function printChatAll(...)
	printChat(nil, ...)
end