-- AfterDialogueHandler (server-side)
local MovementController = require(game.ReplicatedStorage:WaitForChild("MovementController"))
local StoryFlags = require(game.ReplicatedStorage:WaitForChild("StoryFlags"))

local AfterDialogue = {}

local function setAttribute(targetName, key, value)
	local target = workspace:FindFirstChild(targetName)
	if target and target.SetAttribute then
		target:SetAttribute(key, value)
		return true
	end
	warn("[AfterDialogue] SetAttribute target not found:", targetName)
	return false
end

local function destroyTarget(name)
	local obj = workspace:FindFirstChild(name)
	if obj then
		obj:Destroy()
		return true
	end
	warn("[AfterDialogue] Destroy target not found:", name)
	return false
end

function AfterDialogue.Execute(instructions, context)
	context = context or {}
	local player = context.player

	if not instructions or type(instructions) ~= "table" then return end

	for _, instr in ipairs(instructions) do
		local t = instr.type or instr[1] -- allow simple arrays
		if t == "SetFlag" or t == "SetStoryFlag" then
			StoryFlags.Set(player, instr.flag, instr.value)
			print("[AfterDialogue] SetFlag", instr.flag, instr.value)
		elseif t == "FollowPlayer" then
			local npcName = instr.npc
			local npc = workspace:FindFirstChild(npcName)
			if npc then
				local state = MovementController.GetState(npc) or MovementController.CreateState(npc)
				MovementController.FollowPlayer(state, player)
				print("[AfterDialogue] FollowPlayer:", npcName)
			end
		elseif t == "StopFollowing" or t == "StopFollow" then
			local npc = workspace:FindFirstChild(instr.npc)
			if npc then
				local state = MovementController.GetState(npc)
				if state then MovementController.StopFollowing(state) end
			end
		elseif t == "SetAttribute" then
			setAttribute(instr.target, instr.key, instr.value)
		elseif t == "Destroy" then
			destroyTarget(instr.target)
		elseif t == "ChangeDialogue" then
			local npc = workspace:FindFirstChild(instr.npc)
			if npc then npc:SetAttribute("DialogueName", instr.newDialogue) end
		else
			warn("[AfterDialogue] Unknown instruction type:", tostring(t))
		end
	end
end

return AfterDialogue
