-- ModeManager (LocalScript in StarterPlayerScripts)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local vnGui = player:WaitForChild("PlayerGui"):WaitForChild("DialogueGui")
local CollectionService = game:GetService("CollectionService")
--local AUTO_START_DIALOGUE = "IntroDialogue" -- set to nil to disable

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if typeof(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("ProximityPrompt") then
		CollectionService:AddTag(descendant, "DialoguePrompt")
	end
end

-- Mode state
_G.GameMode = "Roaming"

_G.DialogueReady = true

local function setAllProximityPromptsEnabled(enabled)
	local CollectionService = game:GetService("CollectionService")
	for _, prompt in CollectionService:GetTagged("DialoguePrompt") do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = enabled
		end
	end
end

_G.EnterStoryMode = function(dialogueData)
	print("Switching to Storytelling Mode")
	_G.GameMode = "Storytelling"
	if _G.ZoomTo then
		_G.ZoomTo(40, 1) -- Zoom in smoothly to closer distance
	end


	-- Disable movement
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	-- Enable VN GUI
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("DialogueGui")
	gui.Enabled = true

	-- Disable all proximity prompts
	setAllProximityPromptsEnabled(false)

	-- Wait for dialogue system to be ready
	local maxWait = 5
	local waited = 0
	while not _G.DialogueReady and waited < maxWait do
		task.wait(0.1)
		waited += 0.1
	end
	
	if _G.playIdleAnimations then
		_G.playIdleAnimations()
	end

	if not _G.DialogueReady then
		warn("Dialogue system not ready")
		return
	end

	print("Dialogue system is ready")

	-- Start dialogue
	if _G.RunDialogue then
		if dialogueData.resetOnRepeat and dialogueData.start then
			_G.RunDialogue(deepCopy(dialogueData.start))
		elseif dialogueData.start then
			_G.RunDialogue(dialogueData.start)
		else
			_G.RunDialogue(deepCopy(dialogueData))
		end

	else
		warn("Dialogue function not found")
	end
end


local function enterRoamingMode()
	_G.GameMode = "Roaming"
	setAllProximityPromptsEnabled(true)
	if _G.ZoomTo then
		_G.ZoomTo(90, 1) -- Return to default zoom
	end


	-- Restore movement
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 0

	-- Hide Visual Novel GUI
	vnGui.Enabled = false
	
	for characterModel, originalTexture in pairs(_G.OriginalDialogueFaces or {}) do
		local head = characterModel:FindFirstChild("Head")
		if head then
			local decal = head:FindFirstChildWhichIsA("Decal")
			if decal then
				decal.Texture = originalTexture
			end
		end
	end

	_G.OriginalDialogueFaces = nil

	if _G.playIdleAnimations then
		_G.playIdleAnimations()
	end
end

	print("Switched to Roaming Mode")
	-- 🔁 Resume idle animations
-- Expose functions globally if needed elsewhere
--_G.EnterStoryMode = enterStorytellingMode
_G.EnterRoamingMode = enterRoamingMode

-- Default state on game start
enterRoamingMode()

if AUTO_START_DIALOGUE then
	task.defer(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local module = ReplicatedStorage:WaitForChild("DialogueModules"):FindFirstChild(AUTO_START_DIALOGUE)
		if module then
			local ok, dialogue = pcall(require, module)
			if ok and typeof(dialogue) == "table" then
				-- Wait until _G.RunDialogue is ready
				local maxWait = 5
				local waited = 0
				while not _G.RunDialogue and waited < maxWait do
					task.wait(0.1)
					waited += 0.1
				end

				if _G.RunDialogue then
					_G.EnterStoryMode(dialogue)
				else
					warn("[AutoStart] _G.RunDialogue still not found after waiting.")
				end
			else
				warn("[AutoStart] Failed to require dialogue:", dialogue)
			end
		else
			warn("[AutoStart] Dialogue module not found:", AUTO_START_DIALOGUE)
		end
	end)
end


