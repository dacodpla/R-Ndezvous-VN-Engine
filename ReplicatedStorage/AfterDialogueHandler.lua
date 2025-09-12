-- AfterDialogueHandler (server-side)
local MovementController = require(game.ReplicatedStorage:WaitForChild("MovementController"))
local StoryFlags = require(game.ReplicatedStorage:WaitForChild("StoryFlags"))
local Players = game:GetService("Players")

local AfterDialogue = {}

local function log(...)
	print("[AfterDialogue]", ...)
end

local function warnf(...)
	warn("[AfterDialogue]", ...)
end

-- Resolve a "target" which may be:
--  * an Instance (Model, Part, etc.)
--  * a Player instance
--  * a string name (search workspace recursively first, then Players)
--  * the literal string "player" which resolves to the current player from context
local function resolveTarget(field, player)
	if not field then return nil end

	if typeof(field) == "Instance" then
		return field
	end

	if type(field) == "string" then
		-- special alias
		if player and (field == "player" or field == "Player" or field == "me") then
			return player
		end

		-- try workspace (recursive)
		local inst = workspace:FindFirstChild(field, true)
		if inst then return inst end

		-- try player list
		local pl = Players:FindFirstChild(field)
		if pl then return pl end
	end

	return nil
end

local function safeSetAttribute(targetField, key, value, player)
	local target = resolveTarget(targetField, player)
	if not target then
		warnf("SetAttribute: target not found ->", tostring(targetField))
		return false
	end
	if type(key) ~= "string" then
		warnf("SetAttribute: missing/invalid key for", target.Name)
		return false
	end
	if not target.SetAttribute then
		warnf("SetAttribute: target does not support SetAttribute ->", target.Name)
		return false
	end

	local ok, err = pcall(function()
		target:SetAttribute(key, value)
	end)

	if not ok then
		warnf("SetAttribute failed for", target.Name, err)
		return false
	end

	log("SetAttribute:", target.Name, key, value)
	return true
end

local function safeDestroy(targetField, player)
	local target = resolveTarget(targetField, player)
	if not target then
		warnf("Destroy: target not found ->", tostring(targetField))
		return false
	end

	-- don't accidentally destroy player objects
	if typeof(target) == "Instance" and target:IsA("Player") then
		warnf("Destroy: refusing to destroy Player ->", target.Name)
		return false
	end

	if target.Parent then
		target:Destroy()
		log("Destroyed:", tostring(targetField))
		return true
	end

	warnf("Destroy: target has no parent (already destroyed?) ->", tostring(targetField))
	return false
end

-- Execute an array of instructions. Instructions support both keyed form and simple arrays:
-- e.g. { type="SetFlag", flag="X", value=true }  OR  { "SetFlag", "X", true }
function AfterDialogue.Execute(instructions, context)
	context = context or {}
	local player = context.player

	if not instructions or type(instructions) ~= "table" then
		warnf("Execute called with invalid instructions")
		return
	end

	for index, instr in ipairs(instructions) do
		local t = instr.type or instr[1] -- support both shapes

		-- SET / STORY FLAG
		if t == "SetFlag" or t == "SetStoryFlag" then
			local flagName = instr.flag or instr[2]
			local value = instr.value
			if value == nil then value = instr[3] end

			if not flagName then
				warnf("SetFlag missing flag name at index", index)
			else
				local ok, err = pcall(function()
					StoryFlags.Set(player, flagName, value)
				end)
				if not ok then warnf("StoryFlags.Set failed:", err) else log("SetFlag", flagName, value) end
			end

			-- FOLLOW PLAYER
		elseif t == "FollowPlayer" then
			local npcField = instr.npc or instr[2] or instr.target
			if not npcField then
				warnf("FollowPlayer missing npc at index", index)
			else
				local npc = resolveTarget(npcField, player)
				if not npc or not npc:IsA("Model") then
					warnf("FollowPlayer: npc not found or not a Model ->", tostring(npcField))
				else
					-- ensure state exists
					local state = MovementController.GetState(npc) or MovementController.CreateState(npc)
					local ok, err = pcall(MovementController.FollowPlayer, state, player)
					if not ok then warnf("FollowPlayer failed for", npc.Name, ":", err) else log("FollowPlayer:", npc.Name) end
				end
			end

			-- STOP FOLLOWING
		elseif t == "StopFollowing" or t == "StopFollow" then
			local npcField = instr.npc or instr[2] or instr.target
			if not npcField then
				warnf("StopFollowing missing npc at index", index)
			else
				local npc = resolveTarget(npcField, player)
				if not npc or not npc:IsA("Model") then
					warnf("StopFollowing: npc not found or not a Model ->", tostring(npcField))
				else
					local state = MovementController.GetState(npc)
					if state then
						local ok, err = pcall(MovementController.StopFollowing, state)
						if not ok then warnf("StopFollowing failed for", npc.Name, ":", err) else log("StopFollowing:", npc.Name) end
					else
						warnf("StopFollowing: no Movement state for", npc.Name)
					end
				end
			end

			-- SET ATTRIBUTE
		elseif t == "SetAttribute" then
			local targetField = instr.target or instr[2]
			local key = instr.key or instr[3]
			local value = instr.value or instr[4]
			safeSetAttribute(targetField, key, value, player)

			-- DESTROY
		elseif t == "Destroy" then
			local targetField = instr.target or instr[2]
			safeDestroy(targetField, player)

			-- CHANGE DIALOGUE NAME (sets DialogueName attribute)
		elseif t == "ChangeDialogue" then
			local npcField = instr.npc or instr[2]
			local newDialogue = instr.newDialogue or instr[3]
			if not npcField or not newDialogue then
				warnf("ChangeDialogue missing npc or newDialogue at index", index)
			else
				local npc = resolveTarget(npcField, player)
				if not npc or not npc.SetAttribute then
					warnf("ChangeDialogue: npc not found or can't set attribute ->", tostring(npcField))
				else
					local ok, err = pcall(function()
						npc:SetAttribute("DialogueName", newDialogue)
					end)
					if not ok then warnf("ChangeDialogue failed:", err) else log("ChangeDialogue:", npc.Name, "->", newDialogue) end
				end
			end

			-- Unknown
		else
			warnf("Unknown instruction type:", tostring(t))
		end
	end
end

return AfterDialogue
