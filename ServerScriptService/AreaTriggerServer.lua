-- ServerScriptService/AreaTriggerServer.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local remote = ReplicatedStorage:WaitForChild("AreaTriggerRemote")

local function resolveTargetName(name)
	if not name or type(name) ~= "string" then return nil end
	-- try workspace recursive
	local inst = workspace:FindFirstChild(name, true)
	if inst then return inst end
	-- try player list
	local pl = Players:FindFirstChild(name)
	if pl then return pl end
	return nil
end

remote.OnServerEvent:Connect(function(player, payload)
	-- payload expected: { newDialogue = string, target = string or nil, targetTag = string or nil }
	if type(payload) ~= "table" then
		warn("[AreaTriggerServer] bad payload from", player.Name)
		return
	end

	local newDialogue = payload.newDialogue
	if type(newDialogue) ~= "string" or newDialogue == "" then
		warn("[AreaTriggerServer] invalid newDialogue from", player.Name)
		return
	end

	-- Handle targetTag (multiple)
	if payload.targetTag and type(payload.targetTag) == "string" and payload.targetTag ~= "" then
		local tag = payload.targetTag
		local tagged = CollectionService:GetTagged(tag)
		if #tagged == 0 then
			warn("[AreaTriggerServer] no instances found with tag:", tag)
			return
		end
		for _, inst in ipairs(tagged) do
			if inst and inst.SetAttribute then
				local ok, err = pcall(function()
					inst:SetAttribute("DialogueName", newDialogue)
				end)
				if not ok then warn("[AreaTriggerServer] failed SetAttribute for", tostring(inst), err) end
			end
		end
		print("[AreaTriggerServer] Set DialogueName for tag", tag, "=>", newDialogue, "requested by", player.Name)
		return
	end

	-- Handle single target
	if payload.target and type(payload.target) == "string" then
		local inst = resolveTargetName(payload.target)
		if not inst then
			warn("[AreaTriggerServer] target not found:", tostring(payload.target))
			return
		end
		if not inst.SetAttribute then
			warn("[AreaTriggerServer] target does not support SetAttribute:", tostring(inst))
			return
		end

		local ok, err = pcall(function()
			inst:SetAttribute("DialogueName", newDialogue)
		end)
		if not ok then
			warn("[AreaTriggerServer] failed to SetAttribute:", tostring(inst), err)
			return
		end
		print("[AreaTriggerServer] Set DialogueName for", inst.Name, "=>", newDialogue, "requested by", player.Name)
		return
	end

	warn("[AreaTriggerServer] no target supplied in payload from", player.Name)
end)
