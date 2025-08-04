local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local playing = {} -- Keeps track of which characters are already animating

local function getIdleAnim(character)
	local folder = ReplicatedStorage:WaitForChild("Animations"):FindFirstChild(character.Name)
	if not folder then return nil end

	local animName = character:GetAttribute("IdleAnimation")
	if not animName then return nil end

	return folder:FindFirstChild(animName)
end

local function playIdleLoop(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local isSpeaking = false
	if _G.ActiveDialogueSpeaker and typeof(_G.ActiveDialogueSpeaker) == "table" then
		isSpeaking = _G.ActiveDialogueSpeaker[character.Name] == true
	end

	-- 🛑 If the NPC is currently speaking, stop the idle anim
	if isSpeaking then
		if playing[character] and playing[character].IsPlaying then
			playing[character]:Stop()
		end
		return
	end

	-- Check for conflicts with other animations
	local playingTracks = animator:GetPlayingAnimationTracks()
	local otherAnimPlaying = false
	if #playingTracks > 0 then
		if playing[character] and playing[character].IsPlaying then
			if #playingTracks > 1 then
				otherAnimPlaying = true
			end
		else
			otherAnimPlaying = true
		end
	end

	if otherAnimPlaying then
		if playing[character] and playing[character].IsPlaying then
			playing[character]:Stop()
		end
		return
	end

	-- If no idle anim loaded yet
	if not playing[character] then
		local idleAnim = getIdleAnim(character)
		if not idleAnim then return end

		local track = animator:LoadAnimation(idleAnim)
		track.Looped = true
		playing[character] = track

		track.Stopped:Connect(function()
			playing[character] = nil
		end)
	end

	-- Play the idle animation
	if not playing[character].IsPlaying then
		playing[character]:Play()
	end
end

-- 🔁 Main update loop
RunService.RenderStepped:Connect(function()
	if _G.GameMode == "Roaming" or _G.GameMode == "Storytelling" then
		for _, model in ipairs(workspace:GetDescendants()) do
			if model:IsA("Model") and model:GetAttribute("IdleAnimation") and model:FindFirstChildOfClass("Humanoid") then
				playIdleLoop(model)
			end
		end
	else
		for char, track in playing do
			if track and track.IsPlaying then
				track:Stop()
			end
		end
		table.clear(playing)
	end
end)
