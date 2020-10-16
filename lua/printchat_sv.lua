util.AddNetworkString("printChat")

local plymeta = FindMetaTable("Player")
if not plymeta then
	ErrorNoHalt("[printchat] Could not find the `Player` metatable. Huh.\n")
	return
end

function plymeta:printChat(...)
	net.Start("printChat")

	local items = {...}

	-- Transfer the number of items
	net.WriteUInt(#items, 16)

	-- Transfer the actual items
	for i = 1, #items do
		net.WriteType(items[i])
	end

	net.Send(self)
end