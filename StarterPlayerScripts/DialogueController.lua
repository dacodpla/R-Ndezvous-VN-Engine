local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Reference to characters in Workspace
local characters = {
	Alarm = {
		model = workspace:WaitForChild("Takumi bedroom"):WaitForChild("alarm")
	},
	Mirror = {
		model = workspace:WaitForChild("Takumi bedroom"):WaitForChild("mirror")
	},
	Books = {
		model = workspace:WaitForChild("Takumi bedroom"):WaitForChild("books")
	},
	Door = {
		model = workspace:WaitForChild("Takumi bedroom"):WaitForChild("Door")
	},
	Beanz = {
		model = workspace:WaitForChild("beanz")
	},
	Zlarc = {
		model = workspace:WaitForChild("Zlarc")
	},
	Ayaka = {
		model = workspace:WaitForChild("Ayaka")
	},
	Takumi = {
		model = workspace:WaitForChild(player.Name)
	},
}

-- Face images (can be Decal IDs or file names if using ImageLabel)
local facePresets = {
	happy = "rbxassetid://707206181",
	angry = "rbxassetid://21352013",
	sad = "rbxassetid://14812981",
	default = "rbxassetid://12928670597"
}

local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local CollectionService = game:GetService("CollectionService")

local MainCharacterName = "Takumi"
local gui = player:WaitForChild("PlayerGui"):WaitForChild("DialogueGui")
local frame = gui:WaitForChild("DialogueFrame")
local nameLabel = frame:WaitForChild("NameLabel")
local dialogueText = frame:WaitForChild("DialogueText")
local clickArea = frame:WaitForChild("DialogueClickArea")
local typeSoundFolder = ReplicatedStorage:WaitForChild("TypeSounds")
local animFolder = ReplicatedStorage:WaitForChild("Animations")
local FacePresets = ReplicatedStorage:WaitForChild("FacePresets")

local activeDialogueTracks = {}
local cachedTracks = {}
local originalRotations = {}
local originalFaces = {}
local originalHeads = {}
local SPEAKER_SCAN_RADIUS = 100

local BGMHandler = require(ReplicatedStorage:WaitForChild("BGMHandler"))
BGMHandler.PlayPersistent("Main")

-- 🔊 Play a short typing sound (one-shot)
local function playTypeSound(soundName)
	if not soundName then return end
	local template = typeSoundFolder:FindFirstChild(soundName)
	if not template then
		warn("Type sound not found:", soundName)
		return
	end

	local sound = template:Clone()
	sound.Parent = SoundService
	sound.Volume = 0.3
	sound:Play()
	Debris:AddItem(sound, 2)
end

local function typeText(text, speed, soundId, effect)
	print("EFFECT RECEIVED:", effect)
	dialogueText.Text = ""
	dialogueText.RichText = true

	local shake = effect == "shake"
	local isTyping = true

	-- Start shake coroutine if needed
	local basePosition = dialogueText.Position

	if string.lower(effect or "") == "shake" then
		coroutine.wrap(function()
			while isTyping do
				local offsetX = math.random(-3, 3)
				local offsetY = math.random(-3, 3)

				dialogueText.Position = UDim2.new(
					basePosition.X.Scale,
					basePosition.X.Offset + offsetX,
					basePosition.Y.Scale,
					basePosition.Y.Offset + offsetY
				)

				task.wait(0.03)
			end

			-- Reset after shake
			dialogueText.Position = basePosition
		end)()
	end

	-- Typewriter loop
	for i = 1, #text do
		local char = text:sub(i, i)
		dialogueText.Text = dialogueText.Text .. char
		if char ~= " " then
			playTypeSound(soundId)
		end
		task.wait(speed)
	end

	isTyping = false -- stop the shake
end

local function setFace(characterModel, faceName)
	local head = characterModel:FindFirstChild("Head")
	if not head then
		warn("No head found on character:", characterModel.Name)
		return
	end

	local existingDecal = head:FindFirstChildWhichIsA("Decal")
	if not existingDecal then
		warn("No decal found on head of", characterModel.Name)
		return
	end

	-- 🌟 Save original face texture (only once)
	if not originalFaces[characterModel] then
		originalFaces[characterModel] = existingDecal.Texture
	end

	local preset = FacePresets:FindFirstChild(faceName or "default")
	if preset and preset:IsA("Decal") then
		existingDecal.Texture = preset.Texture
		print("[FaceChange] Set", characterModel.Name .. "'s face to", faceName)
	else
		warn("[FaceChange] Face preset not found for:", faceName)
	end
end

-- 🌍 Share for ModeManager reset
_G.OriginalDialogueFaces = originalFaces
local function setHead(characterModel, headName)
	if not characterModel or not characterModel:IsA("Model") then return end

	local humanoid = characterModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("No Humanoid found in", characterModel.Name)
		return
	end

	local head = characterModel:FindFirstChild("Head")
	if not head then
		warn("No Head found in", characterModel.Name)
		return
	end

	-- Ensure FaceCenterAttachment exists
	if not head:FindFirstChild("FaceCenterAttachment") then
		local faceAttach = Instance.new("Attachment")
		faceAttach.Name = "FaceCenterAttachment"
		faceAttach.Position = Vector3.new(0, 0, 0.6)
		faceAttach.Parent = head
	end

	-- Store original dynamic head
	if not originalHeads[characterModel] then
		for _, acc in ipairs(characterModel:GetChildren()) do
			if acc:IsA("Accessory") and acc:FindFirstChild("Handle") then
				if acc.Handle:FindFirstChild("FaceCenterAttachment") then
					originalHeads[characterModel] = acc:Clone()
					acc:Destroy()
				end
			end
		end
	else
		-- Remove current head
		for _, acc in ipairs(characterModel:GetChildren()) do
			if acc:IsA("Accessory") and acc:FindFirstChild("Handle") then
				if acc.Handle:FindFirstChild("FaceCenterAttachment") then
					acc:Destroy()
				end
			end
		end
	end

	-- Load new head
	local headFolder = ReplicatedStorage:FindFirstChild("DynamicHeads")
	if not headFolder then
		warn("DynamicHeads folder not found.")
		return
	end

	local newHead = headFolder:FindFirstChild(headName or "default")
	if not newHead or not newHead:IsA("Accessory") then
		warn("Dynamic head not found:", headName)
		return
	end

	local clone = newHead:Clone()
	local handle = clone:FindFirstChild("Handle")

	if not handle or not handle:FindFirstChild("FaceCenterAttachment") then
		warn("Cloned head missing Handle or FaceCenterAttachment")
		return
	end

	-- 🔧 Set ManualWeld if needed (fallback for AddAccessory bug)
	local attachmentOnHead = head:FindFirstChild("FaceCenterAttachment")
	local attachmentOnAccessory = handle:FindFirstChild("FaceCenterAttachment")

	if attachmentOnHead and attachmentOnAccessory then
		-- Remove existing welds
		for _, child in ipairs(handle:GetChildren()) do
			if child:IsA("Weld") then
				child:Destroy()
			end
		end

		local weld = Instance.new("Weld")
		weld.Name = "DynamicHeadWeld"
		weld.Part0 = handle
		weld.Part1 = head
		weld.C0 = attachmentOnAccessory.CFrame
		weld.C1 = attachmentOnHead.CFrame
		weld.Parent = handle
	end

	-- Parent it directly to model and weld manually (avoid AddAccessory issues)
	handle.Anchored = false
	handle.CanCollide = false
	clone.Parent = characterModel

	print("[setHead] Successfully applied dynamic head:", headName, "to", characterModel.Name)
end


local function restoreHeads()
	for characterModel, headAccessory in pairs(originalHeads) do
		if characterModel and headAccessory and characterModel:IsDescendantOf(workspace) then
			-- Remove any current dynamic head
			for _, acc in ipairs(characterModel:GetChildren()) do
				if acc:IsA("Accessory") and acc:FindFirstChild("Handle") then
					if acc.Handle:FindFirstChild("FaceCenterAttachment") then
						acc:Destroy()
					end
				end
			end

			local humanoid = characterModel:FindFirstChildOfClass("Humanoid")
			if humanoid then
				pcall(function()
					humanoid:AddAccessory(headAccessory:Clone())
				end)
			end
		end
	end

	table.clear(originalHeads)
end

_G.RestoreDynamicHeads = restoreHeads


local function getAnimationId(characterName, animName)
	-- Remap player's model name (e.g. "beanzonyon") to "Takumi"
	for name, data in pairs(characters) do
		if data.model and data.model.Name == characterName and name == "Takumi" then
			characterName = "Takumi"
			break
		end
	end

	local animFolder = ReplicatedStorage:WaitForChild("Animations"):FindFirstChild(characterName)
	if not animFolder then
		warn("Animation folder not found for", characterName)
		return nil
	end

	local anim = animFolder:FindFirstChild(animName)
	if not anim then
		warn("Animation", animName, "not found in", characterName)
		return nil
	end

	return anim.AnimationId
end

local function preloadAllAnimations()
	local animationsToPreload = {}

	for _, characterFolder in pairs(animFolder:GetChildren()) do
		for _, anim in pairs(characterFolder:GetChildren()) do
			if anim:IsA("Animation") then
				table.insert(animationsToPreload, anim)
			end
		end
	end

	if #animationsToPreload > 0 then
		print("[DialogueController] Preloading", #animationsToPreload, "animations...")
		local success, err = pcall(function()
			ContentProvider:PreloadAsync(animationsToPreload)
		end)
		if success then
			print("[DialogueController] All animations preloaded successfully.")
		else
			warn("[DialogueController] Animation preloading failed:", err)
		end
	else
		warn("[DialogueController] No animations found to preload.")
	end
end

local function preloadAnimation(characterName, characterModel, animName)
	cachedTracks[characterName] = cachedTracks[characterName] or {}
	if cachedTracks[characterName][animName] then return cachedTracks[characterName][animName] end

	local animId = getAnimationId(characterName, animName)
	if not animId then return nil end

	local humanoid = characterModel:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return nil end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action

	cachedTracks[characterName][animName] = track
	return track
end

local function getAnimationFolderName(speaker)
	if speaker == player.Name then
		return "Takumi"
	else
		return speaker
	end
end


local function playAnimation(characterModel, animName)
	if not animName then return end

	local characterName = characterModel.Name
	local humanoid = characterModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("No Humanoid found in", characterModel.Name)
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn("No Animator found in", characterModel.Name)
		return
	end

	-- Check cache first
	cachedTracks[characterName] = cachedTracks[characterName] or {}
	local track = cachedTracks[characterName][animName]

	if not track then
		local animId = getAnimationId(characterName, animName)
		if not animId then
			warn("Animation ID not found for", characterName, animName)
			return
		end

		local animation = Instance.new("Animation")
		animation.AnimationId = animId

		track = animator:LoadAnimation(animation)
		if not track then
			warn("Failed to load animation", animName, "for", characterName)
			return
		end

		track.Priority = Enum.AnimationPriority.Action
		cachedTracks[characterName][animName] = track
	end

	-- Stop all previous animations

	for _, otherTrack in ipairs(animator:GetPlayingAnimationTracks()) do
		local isPersistent = CollectionService:HasTag(otherTrack, "PersistentAnimation")

		-- ❗ Special rule for Takumi: stop everything (even persistent)
		local isTakumi = (characterName == player.Name or characterName == "Takumi")

		if isTakumi or not isPersistent then
			otherTrack:Stop()
		end
	end


	track:Play(0) -- Snap instantly
	activeDialogueTracks[characterName] = track
	return track
end

local function playIdleAnimations()
	for name, data in pairs(characters) do
		local humanoid = data.model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				-- Stop all previous animations to prevent stacking
				local CollectionService = game:GetService("CollectionService")

				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if not CollectionService:HasTag(track, "PersistentAnimation") then
						track:Stop()
					end
				end

			end
		end

		if data.defaultAnimation then
			local idleAnimId = getAnimationId(name, data.defaultAnimation)
			if idleAnimId then
				local anim = Instance.new("Animation")
				anim.AnimationId = idleAnimId

				local animator = data.model:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
				if animator then
					local track = animator:LoadAnimation(anim)
					track.Priority = Enum.AnimationPriority.Idle
					track:Play()
				end
			end
		end
	end
end

-- 🖱️ Wait for click or spacebar input
local function waitForInput()
	local proceed = false

	-- 👆 Capture click
	local clickConnection = clickArea.MouseButton1Click:Connect(function()
		print("Click received")
		proceed = true
	end)

	-- ⌨️ Capture spacebar press
	local keyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.Space then
			print("Spacebar received")
			proceed = true
		end
	end)

	-- Wait for either input
	repeat task.wait() until proceed

	-- 🔌 Disconnect listeners
	clickConnection:Disconnect()
	keyConnection:Disconnect()
end


-- ▶️ Run the full dialogue list
local function runDialogue(dialogueData)
	if not dialogueData or typeof(dialogueData) ~= "table" then
		warn("[DialogueController] Invalid dialogueData")
		return
	end

	local globalOptions = {}
	if dialogueData.disableFacePlayer ~= nil then
		globalOptions.disableFacePlayer = dialogueData.disableFacePlayer
	end

	--	

	local i = 1
	while i <= #dialogueData do
		local line = dialogueData[i]
		local player = Players.LocalPlayer

		-- 🛑 TRANSITION
		if line.transition and _G.PlayBlackTransition then
			_G.PlayBlackTransition(line.transition)
			task.wait(0.6)
			i += 1
			continue
		end

		-- 🚪 TELEPORT
		if line.teleport then
			local data = line.teleport
			local char = player.Character or player.CharacterAdded:Wait()

			task.delay(0.5, function()
				if data.position and typeof(data.position) == "Vector3" then
					char:PivotTo(CFrame.new(data.position))
				elseif data.target and typeof(data.target) == "string" then
					local folder = ReplicatedStorage:FindFirstChild("TeleportLocations")
					local target = folder and folder:FindFirstChild(data.target)
					if target and target:IsA("BasePart") then
						char:PivotTo(target.CFrame)
					end
				end
			end)

			i += 1
			continue
		end

		-- 💬 TEXT + SFX/ANIM
		if line.text and line.speaker then
			-- 🧠 Find closest character model matching speaker name
			local function findClosestCharacter(name, originPos, maxDist)
				local closest = nil
				local shortestDistance = math.huge

				for _, model in ipairs(workspace:GetDescendants()) do
					if model:IsA("Model") and model.Name == name and model.PrimaryPart then
						local dist = (model.PrimaryPart.Position - originPos).Magnitude
						if dist < maxDist and dist < shortestDistance then
							shortestDistance = dist
							closest = model
						end
					end
				end

				return closest
			end

			-- ?? Find character model based on speaker name
			local charModel
			if line.speaker == MainCharacterName then
				charModel = player.Character
			else
				local origin = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position or Vector3.zero
				local fallbackModel = nil
				local shortestDistance = math.huge

				-- First: check if characters[speaker] exists and is nearby
				local tableEntry = characters[line.speaker]
				if tableEntry and tableEntry.model and tableEntry.model:IsDescendantOf(workspace) and tableEntry.model.PrimaryPart then
					local dist = (tableEntry.model.PrimaryPart.Position - origin).Magnitude
					if dist < SPEAKER_SCAN_RADIUS then
						charModel = tableEntry.model
					end
				end

				-- If not valid or too far, do full scan of workspace
				if not charModel then
					for _, model in ipairs(workspace:GetDescendants()) do
						if model:IsA("Model") and model.Name == line.speaker and model.PrimaryPart then
							local dist = (model.PrimaryPart.Position - origin).Magnitude
							if dist < SPEAKER_SCAN_RADIUS and dist < shortestDistance then
								shortestDistance = dist
								fallbackModel = model
							end
						end
					end
					charModel = fallbackModel
				end
			end



			if charModel then
				_G.CurrentSpeakerModel = charModel


				if line.speaker and not originalRotations[line.speaker] then
					originalRotations[line.speaker] = charModel:GetPrimaryPartCFrame()
				end

				-- 🔁 Face NPC toward player and vice versa and more
				if charModel ~= player.Character then
					local npcRoot = charModel.PrimaryPart
					local playerRoot = player.Character and player.Character.PrimaryPart

					-- Find the correct lookAt target if specified
					local targetToFace = nil

					if line.lookAt then
						task.defer(function()
							local npcRoot = charModel.PrimaryPart
							if not npcRoot then
								warn("[LookAt] Speaker has no PrimaryPart:", charModel.Name)
								return
							end

							if typeof(line.lookAt) == "string" then
								local closestTarget = nil
								local shortestDist = math.huge

								for _, obj in ipairs(workspace:GetDescendants()) do
									if obj:IsA("Model") and obj.Name == line.lookAt and obj.PrimaryPart then
										local dist = (obj.PrimaryPart.Position - npcRoot.Position).Magnitude
										if dist < 100 and dist < shortestDist then
											shortestDist = dist
											closestTarget = obj
										end
									end
								end

								if closestTarget then
									local targetPos = closestTarget.PrimaryPart.Position
									local dir = (targetPos - npcRoot.Position).Unit
									local lookCFrame = CFrame.new(npcRoot.Position, npcRoot.Position + Vector3.new(dir.X, 0, dir.Z))
									charModel:SetPrimaryPartCFrame(lookCFrame)
								else
									warn("[LookAt] No nearby target found for:", line.lookAt)
								end

							elseif typeof(line.lookAt) == "Vector3" then
								-- Treat as Orientation (Euler angles in degrees)
								local orientation = line.lookAt
								local yawCFrame = CFrame.Angles(0, math.rad(orientation.Y), 0)
								charModel:SetPrimaryPartCFrame(CFrame.new(npcRoot.Position) * yawCFrame)
								print("[LookAt] Applied orientation to", charModel.Name, orientation)
							else
								warn("[LookAt] Invalid lookAt value:", line.lookAt)
							end
						end)
					end


					-- Default to facing player if no target
					if not targetToFace and playerRoot then
						targetToFace = playerRoot
					end

					-- NPC faces target
					local npcHRP = charModel:FindFirstChild("HumanoidRootPart")
					if npcHRP and targetToFace then
						local dir = (targetToFace.Position - npcHRP.Position).Unit
						local lookCFrame = CFrame.new(npcHRP.Position, npcHRP.Position + Vector3.new(dir.X, 0, dir.Z))
						charModel:SetPrimaryPartCFrame(lookCFrame)
					end

					-- Player always faces NPC (if both are present)
					if playerRoot and npcRoot then
						local dir = (npcRoot.Position - playerRoot.Position).Unit
						local look = CFrame.new(playerRoot.Position, playerRoot.Position + Vector3.new(dir.X, 0, dir.Z))
						player.Character:SetPrimaryPartCFrame(look)
					end
				end

				-- 📱 CHOICES
				-- Handle choice system
				if line.choices then
					local frame = gui:WaitForChild("ChoicesFrame")
					local template = frame:WaitForChild("ChoiceButtonTemplate")

					-- Hide dialogue click area while showing choices
					clickArea.Visible = false

					-- Clean up existing buttons
					for _, child in ipairs(frame:GetChildren()) do
						if child:IsA("TextButton") and child ~= template then
							child:Destroy()
						end
					end

					-- Make sure layout exists
					local layout = frame:FindFirstChildOfClass("UIListLayout")
					if not layout then
						layout = Instance.new("UIListLayout")
						layout.SortOrder = Enum.SortOrder.LayoutOrder
						layout.Padding = UDim.new(0, 8)
						layout.Parent = frame
					end

					frame.Visible = true
					gui.Enabled = true

					local selectedBranch = nil

					for index, choiceData in ipairs(line.choices) do
						local btn = template:Clone()
						btn.Text = choiceData.choice or "[No Text]"
						btn.Visible = true
						btn.Name = "Choice_" .. index
						btn.Size = UDim2.new(1, -16, 0, 50)
						btn.LayoutOrder = index
						btn.Parent = frame

						btn.MouseButton1Click:Connect(function()
							selectedBranch = choiceData
						end)
					end

					repeat task.wait() until selectedBranch

					frame.Visible = false
					clickArea.Visible = true

					for _, child in ipairs(frame:GetChildren()) do
						if child:IsA("TextButton") and child ~= template then
							child:Destroy()
						end
					end

					--- Replace the current choice line with the branch (in-place)
					table.remove(dialogueData, i)

					-- Insert next branch first (in reverse order)
					for j = #selectedBranch.next, 1, -1 do
						table.insert(dialogueData, i, selectedBranch.next[j])
					end

					-- Insert the answer (goes before next)
					if selectedBranch.answer then
						table.insert(dialogueData, i, selectedBranch.answer)
					end

					continue
				end



				if line.face then setFace(charModel, line.face) end
				if line.animation then playAnimation(charModel, line.animation, line.speaker) end
				if line.dynamicHead then
					setHead(charModel, line.dynamicHead)
				end

				-- Optional: playSFX if you add it
				if line.sfx then
					local sfx = ReplicatedStorage:WaitForChild("SFX"):FindFirstChild(line.sfx)
					if sfx then
						local sound = sfx:Clone()
						sound.Parent = SoundService
						sound:Play()
						Debris:AddItem(sound, sound.TimeLength + 1)
					end
				end

				-- Set name and type text
				local displayName = (line.speaker == player.Name) and MainCharacterName or line.speaker
				nameLabel.Text = displayName
				typeText(line.text, line.speed or 0.03, line.typeSound, line.effect)
				waitForInput()
			else
				warn("Unknown speaker:", line.speaker)
			end

			i += 1
			continue
		end

		-- fallback increment
		i += 1


		-- Typewriter
		typeText(line.text, line.speed or 0.03, line.typeSound, line.effect)
		waitForInput()
	end

	-- After all lines
	require(ReplicatedStorage:WaitForChild("BGMHandler")).RestorePersistent()
	_G.CurrentSpeakerModel = nil

	if _G.EnterRoamingMode then
		for name, cframe in pairs(originalRotations) do
			local charData = characters[name]
			if charData and charData.model and charData.model ~= player.Character then
				charData.model:SetPrimaryPartCFrame(cframe)
			end
		end
		originalRotations = {}
		_G.EnterRoamingMode()
		if _G.RestoreDynamicHeads then
			_G.RestoreDynamicHeads()
		end
	end
end

-- Set globals
_G.RunDialogue = runDialogue
_G.playIdleAnimations = playIdleAnimations

function stopAllAnimations()
	for _, data in pairs(characters) do
		local humanoid = data.model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local CollectionService = game:GetService("CollectionService")
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if not CollectionService:HasTag(track, "PersistentAnimation") then
						track:Stop()
					end
				end
			end
		end
	end
end


_G.StopWorldIdleAnimations = stopAllAnimations

_G.DialogueReady = true
preloadAllAnimations()
_G.DialogueWillContinue = false

print("[DialogueController] Dialogue system is ready!")
