-- ServerScriptService/AfterDialogueServer.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AfterEvent = ReplicatedStorage:WaitForChild("AfterDialogueEvent")
local StoryFlags = require(ReplicatedStorage:WaitForChild("StoryFlags"))
local MovementController = require(ReplicatedStorage:WaitForChild("MovementController"))

-- RemoteEvents to communicate w/ NPC controllers (create these in ReplicatedStorage)
local NPCFollowEvent = ReplicatedStorage:WaitForChild("NPCFollowEvent")
local NPCStopFollowEvent = ReplicatedStorage:WaitForChild("NPCStopFollowEvent")
local ChangeNPCDialogueEvent = ReplicatedStorage:WaitForChild("ChangeNPCDialogueEvent")

local function resolveTarget(name)
	return workspace:FindFirstChild(name)
end

local handlers = {}

handlers.SetFlag = function(instr, player)
	if not instr.flag then return end
	StoryFlags.Set(player, instr.flag, instr.value)
end

handlers.AddFlag = function(instr, player)
	-- numeric increment helper
	local key = instr.flag
	local amount = instr.value or 1
	local cur = StoryFlags.Get(player, key) or 0
	StoryFlags.Set(player, key, cur + amount)
end

handlers.SetAttribute = function(instr)
	local inst = resolveTarget(instr.target)
	if inst and instr.key then
		inst:SetAttribute(instr.key, instr.value)
	end
end

handlers.Destroy = function(instr)
	local inst = resolveTarget(instr.target)
	if inst then inst:Destroy() end
end

handlers.FollowPlayer = function(instr, player)
	local npc = workspace:FindFirstChild(instr.npc)
	if npc then
		local state = { model = npc, humanoid = npc:FindFirstChildOfClass("Humanoid") }
		MovementController.FollowPlayer(state, player)
	end
end

handlers.StopFollowing = function(instr, player)
	local npc = workspace:FindFirstChild(instr.npc)
	if npc then
		local state = { model = npc, humanoid = npc:FindFirstChildOfClass("Humanoid") }
		MovementController.StopFollowing(state)
	end
end


handlers.ChangeDialogue = function(instr)
	if instr.npc and instr.newDialogue then
		ChangeNPCDialogueEvent:FireAllClients(instr.npc, instr.newDialogue)
	end
end

AfterEvent.OnServerEvent:Connect(function(player, list)
	if type(list) ~= "table" then return end
	for _, instr in ipairs(list) do
		if instr and instr.type and handlers[instr.type] then
			local ok, err = pcall(handlers[instr.type], instr, player)
			if not ok then
				warn("AfterDialogue handler error:", err)
			end
		else
			warn("Unknown afterDialogue instruction:", instr and instr.type)
		end
	end
end)
