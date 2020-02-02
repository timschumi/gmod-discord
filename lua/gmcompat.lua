-- gmcompat.lua
--
-- Gamemode abstraction API for Garry's Mod

local gmcompat = {}

-- Returns 1 if the round is still on
-- Returns 0 otherwise (or -1 if unsupported)
function gmcompat.roundState()
	if gmod.GetGamemode() == nil then
		ErrorNoHalt("[gmcompat] Gamemode isn't initialized yet!")
		return -1
	end

	if gmod.GetGamemode().Name == "Trouble in Terrorist Town" or
	   gmod.GetGamemode().Name == "TTT2 (Advanced Update)" then
		-- Round state 3 => Game is running
		return ((GetRoundState() == 3) and 1 or 0)
	end

	if gmod.GetGamemode().Name == "Murder" then
		-- Round state 1 => Game is running
		return ((gmod.GetGamemode():GetRound() == 1) and 1 or 0)
	end

	-- Round state could not be determined
	ErrorNoHalt("[gmcompat] roundState: Could not determine gamemode.")
	return -1
end

function gmcompat.roundStartHook()
	if gmod.GetGamemode() == nil then
		ErrorNoHalt("[gmcompat] Gamemode isn't initialized yet!")
		return nil
	end

	if gmod.GetGamemode().Name == "Trouble in Terrorist Town" or
	   gmod.GetGamemode().Name == "TTT2 (Advanced Update)" then
		return "TTTBeginRound"
	end

	if gmod.GetGamemode().Name == "Murder" then
		return "OnStartRound"
	end

	-- Hook name could not be determined
	ErrorNoHalt("[gmcompat] roundStartHook: Could not determine gamemode.")
	return nil
end

function gmcompat.roundEndHook()
	if gmod.GetGamemode() == nil then
		ErrorNoHalt("[gmcompat] Gamemode isn't initialized yet!")
		return nil
	end

	if gmod.GetGamemode().Name == "Trouble in Terrorist Town" or
	   gmod.GetGamemode().Name == "TTT2 (Advanced Update)" then
		return "TTTEndRound"
	end

	if gmod.GetGamemode().Name == "Murder" then
		return "OnEndRound"
	end

	-- Hook name could not be determined
	ErrorNoHalt("[gmcompat] roundEndHook: Could not determine gamemode.")
	return nil
end

-- `target` is the type of hook that should be added (either `start` or `end`)
-- `prefix` is the unique hook name prefix that should be used
-- `func` is the function that should be executed
function gmcompat.hook(target, prefix, func)
	local hookname

	if target == "start" then
		hookname = gmcompat.roundStartHook()
	elseif target == "end" then
		hookname = gmcompat.roundEndHook()
	else
		ErrorNoHalt("[gmcompat] hook: Unknown hook type used: "..target)
		return
	end

	if hookname == nil then
		print("[gmcompat] hook: Could not find hook; the actual error has probably been logged above.")
		return
	end

	hook.Add(hookname, prefix..hookname, func)
end

return gmcompat
