local StoryFlags = {}
StoryFlags._data = {} -- keys: userId -> { flagName = true }

-- Ensure table exists
local function ensure(player)
	local id = player and player.UserId or 0
	if not StoryFlags._data[id] then
		StoryFlags._data[id] = {}
	end
	return StoryFlags._data[id]
end

function StoryFlags.Set(player, flag, value)
	assert(player and player.UserId, "StoryFlags.Set: player required")
	local t = ensure(player)
	t[flag] = value
	return true
end

function StoryFlags.Get(player, flag)
	assert(player and player.UserId, "StoryFlags.Get: player required")
	local t = ensure(player)
	return t[flag]
end

function StoryFlags.Has(player, flag)
	return StoryFlags.Get(player, flag) and true or false
end

function StoryFlags.Clear(player, flag)
	assert(player and player.UserId, "StoryFlags.Clear: player required")
	local t = ensure(player)
	t[flag] = nil
end

function StoryFlags.ClearAll(player)
	assert(player and player.UserId, "StoryFlags.ClearAll: player required")
	StoryFlags._data[player.UserId] = {}
end

-- Optional: expose a shallow copy for read-only sync to client
function StoryFlags.GetAll(player)
	local t = ensure(player)
	local copy = {}
	for k,v in pairs(t) do copy[k] = v end
	return copy
end

return StoryFlags