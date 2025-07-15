local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local characters = {
	workspace:WaitForChild("beanz"),
	workspace:WaitForChild("Zlarc")
}

local idleAnimations = {
	["beanz"] = "IdleRetro2",
	["Zlarc"] = "IdleRetro2",
}

local playing = {} -- keeps track of which characters are already animating

local function getIdleAnim(character)
	local folder = ReplicatedStorage:WaitForChild("Animations"):FindFirstChild(character.Name)
	if not folder then return nil end

	local animName = idleAnimations[character.Name]
	if not animName then return nil end

	return folder:FindFirstChild(animName)
end

local function playIdleLoop(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	-- If it's the NPC's turn to speak, the dialogue script has full control.
	-- We must ensure our idle animation is stopped.
	if _G.CurrentSpeakerModel and _G.CurrentSpeakerModel == character then
		if playing[character] and playing[character].IsPlaying then
			playing[character]:Stop()
		end
		return -- Yield control
	end

	-- Check if any other animation is being played by another script (e.g., a 'listening' animation).
	local playingTracks = animator:GetPlayingAnimationTracks()
	local otherAnimPlaying = false
	if #playingTracks > 0 then
		if playing[character] and playing[character].IsPlaying then
			-- If our idle track is playing, another one must have started for this to be true.
			if #playingTracks > 1 then
				otherAnimPlaying = true
			end
		else
			-- Our idle track isn't playing, but something else is.
			otherAnimPlaying = true
		end
	end

	if otherAnimPlaying then
		-- Another animation is active, so we must stop our idle animation to prevent conflict.
		if playing[character] and playing[character].IsPlaying then
			playing[character]:Stop()
		end
		return -- Yield control
	end

	-- If we reach here, it means no other animations are playing and the NPC isn't speaking.
	-- This is the condition to play our idle animation.

	-- Load the animation if it's not loaded yet.
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

	-- Play the animation if it's not already playing.
	if not playing[character].IsPlaying then
		playing[character]:Play()
	end
end


RunService.RenderStepped:Connect(function()
	if _G.GameMode == "Roaming" or _G.GameMode == "Storytelling" then
		for _, char in characters do
			playIdleLoop(char)
		end
	else
		-- Stop all idle animations when not in Roaming or Storytelling mode
		for char, track in playing do
			if track and track.IsPlaying then
				track:Stop()
			end
		end
		table.clear(playing)
	end
end)

