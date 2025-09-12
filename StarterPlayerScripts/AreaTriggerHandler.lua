-- LocalScript (client)
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

local TRIGGER_TAG = "DialogueTrigger"
local TRIGGER_RADIUS = 5

local wasInside = {}
local triggered = {}

local remote = ReplicatedStorage:WaitForChild("AreaTriggerRemote")

local function tryFireDialogue(moduleName)
	if not moduleName then return end
	local dialogueFolder = ReplicatedStorage:FindFirstChild("DialogueModules")
	if not dialogueFolder then
		warn("[AreaTrigger] DialogueModules folder not found.")
		return
	end
	local module = dialogueFolder:FindFirstChild(moduleName)
	if module and module:IsA("ModuleScript") then
		local ok, dialogueData = pcall(require, module)
		if not ok then
			warn("[AreaTrigger] Error requiring dialogue module:", moduleName, dialogueData)
			return
		end
		if typeof(_G.EnterStoryMode) == "function" then
			_G.EnterStoryMode(dialogueData)
		else
			warn("[AreaTrigger] _G.EnterStoryMode not defined.")
		end
	else
		warn("[AreaTrigger] Dialogue module not found:", moduleName)
	end
end

RunService.RenderStepped:Connect(function()
	for _, trigger in ipairs(CollectionService:GetTagged(TRIGGER_TAG)) do
		if not (trigger and trigger:IsA("BasePart") and trigger:IsDescendantOf(workspace)) then
			continue
		end

		local distance = (root.Position - trigger.Position).Magnitude
		local isInside = distance <= TRIGGER_RADIUS

		-- read attributes
		local dialogueName = trigger:GetAttribute("DialogueName")
		local canRepeat = trigger:GetAttribute("CanRepeat")
		-- optional new attributes:
		-- ChangeDialogue (string) = name of new dialogue module to apply on target(s)
		-- Target (string) = name of a single target in workspace (Model name)
		-- TargetTag (string) = tag (CollectionService) to target multiple models
		local changeDialogue = trigger:GetAttribute("ChangeDialogue")
		local targetName = trigger:GetAttribute("Target")
		local targetTag = trigger:GetAttribute("TargetTag")

		-- Reset wasInside if player moved out of the trigger
		if not isInside then
			wasInside[trigger] = false
			continue
		end

		-- Only trigger when just entered
		if isInside and not wasInside[trigger] then
			wasInside[trigger] = true

			if not canRepeat and triggered[trigger] then
				continue
			end

			-- If the trigger requests changing dialogue on some NPC(s), ask the server to do it.
			if changeDialogue and (targetName or targetTag) then
				-- payload: { newDialogue = string, target = string or nil, targetTag = string or nil }
				local payload = { newDialogue = changeDialogue, target = targetName, targetTag = targetTag }
				-- fire to server (server will validate)
				remote:FireServer(payload)
			end

			-- If the trigger also has DialogueName, start the dialogue locally as before
			if dialogueName then
				print("[AreaTrigger] Player triggered dialogue:", dialogueName)
				triggered[trigger] = true
				tryFireDialogue(dialogueName)
			else
				-- optional: no dialogue module but changeDialogue existed: fine, server already handled the change
				if not changeDialogue then
					warn("[AreaTrigger] Trigger part missing DialogueName attribute and ChangeDialogue:", trigger.Name)
				end
			end
		end
	end
end)
