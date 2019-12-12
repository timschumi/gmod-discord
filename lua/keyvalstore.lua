KeyValStore = {
	data = {},
	file = nil
}

function KeyValStore:new(filename)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.file = filename
	data_raw = file.Read(filename, "DATA")
	if (data_raw) then
		o.data = util.JSONToTable(data_raw)
	end

	return o
end

function KeyValStore:get(key)
	return self.data[key]
end

function KeyValStore:set(key, value)
	self.data[key] = value
	file.Write(self.file, util.TableToJSON(self.data))
end
