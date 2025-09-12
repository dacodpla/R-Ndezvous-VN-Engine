-- ModeManager (LocalScript in StarterPlayerScripts)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local vnGui = player:WaitForChild("PlayerGui"):WaitForChild("DialogueGui")

-- Roblox PlayerModule controls
local PlayerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()

--local AUTO_START_DIALOGUE = ""

-- Mode state
_G.GameMode = "Roaming"
_G.DialogueReady = true

-- Utils
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

-- Register prompts under DialoguePrompt tag
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("ProximityPrompt") then
		CollectionService:AddTag(descendant, "DialoguePrompt")
	end
end

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function setPlayerControls(enabled)
	local playerModule = player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
	if playerModule then
		local controlModule = require(playerModule:WaitForChild("ControlModule"))
		if enabled then
			controlModule:Enable()
		else
			controlModule:Disable()
		end
	end
end

_G.DisableControls = function()
	setPlayerControls(false)
end

_G.EnableControls = function()
	setPlayerControls(true)
end

local function setAllProximityPromptsEnabled(enabled)
	for _, prompt in CollectionService:GetTagged("DialoguePrompt") do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = enabled
		end
	end
end

local function playPlayerIdle()
	local anims = ReplicatedStorage:FindFirstChild("Animations")
	if not anims then return end

	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local playerName = _G.MainCharacterName or player.Name
	local animFolder = anims:FindFirstChild(playerName)
	if not animFolder then return end

	local idleAnim = animFolder:FindFirstChild("Idle") or animFolder:FindFirstChild("IdleRetro2")
	if not idleAnim then return end

	local track = animator:LoadAnimation(idleAnim)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Idle
	track:Play()
end

-- STORY MODE
_G.EnterStoryMode = function(dialogueData, npcName)
	print("Switching to Storytelling Mode")
	_G.GameMode = "Storytelling"

	-- Zoom camera in
	if _G.ZoomTo then
		_G.ZoomTo(40, 1)
	end

	-- Disable WASD + Jump
	_G.DisableControls()

	-- Enable VN GUI safely
	if vnGui then
		vnGui.Enabled = true
		-- clear old leftover text
		local dialogueText = vnGui:FindFirstChild("DialogueText", true)
		if dialogueText then
			dialogueText.Text = ""
		end
	end

	-- Disable all proximity prompts
	setAllProximityPromptsEnabled(false)

	-- Tell server NPC should pause patrol
	if npcName then
		ReplicatedStorage:WaitForChild("DialogueEvent"):FireServer("Start", npcName)

		-- ?? Pause the NPC’s movement locally
		local MovementController = require(ReplicatedStorage:WaitForChild("MovementController"))
		local npcModel = workspace:FindFirstChild(npcName)
		if npcModel then
			MovementController.PauseMovement(npcModel)
		end
	end

	-- Wait for DialogueController
	local maxWait, waited = 5, 0
	while not _G.DialogueReady and waited < maxWait do
		task.wait(0.1)
		waited += 0.1
	end
	if not _G.DialogueReady then
		warn("Dialogue system not ready")
		return
	end

	-- Start dialogue
	if _G.RunDialogue then
		if dialogueData.resetOnRepeat and dialogueData.start then
			_G.RunDialogue(deepCopy(dialogueData.start), npcName)
		elseif dialogueData.start then
			_G.RunDialogue(dialogueData.start, npcName)
		else
			_G.RunDialogue(deepCopy(dialogueData), npcName)
		end
	else
		warn("Dialogue function not found")
	end
end

-- ROAMING MODE
local function enterRoamingMode()
	print("Switching back to Roaming Mode")
	_G.GameMode = "Roaming"

	-- Restore camera
	if _G.ZoomTo then
		_G.ZoomTo(90, 1)
	end

	-- Re-enable WASD
	_G.EnableControls()

	-- Restore humanoid properties
	humanoid.WalkSpeed = 8
	humanoid.JumpPower = 50

	-- Hide VN GUI
	if vnGui then
		vnGui.Enabled = false
		-- clear old text so it doesn’t stick
		local dialogueText = vnGui:FindFirstChild("DialogueText", true)
		if dialogueText then
			dialogueText.Text = ""
		end
	end

	-- Restore NPC faces if modified
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

	-- Re-enable prompts
	setAllProximityPromptsEnabled(true)

	-- Resume animations
	if _G.playIdleAnimations then
		_G.playIdleAnimations()
	end
	playPlayerIdle()
end

_G.EnterRoamingMode = enterRoamingMode

-- Auto fallback: dialogue controller should call EnterRoamingMode when done
if _G.OnDialogueFinished then
	_G.OnDialogueFinished:Connect(function(npcName)
		if npcName then
			ReplicatedStorage:WaitForChild("DialogueEvent"):FireServer("End", npcName)
		end
		_G.EnterRoamingMode()
	end)
end

-- Default start
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


