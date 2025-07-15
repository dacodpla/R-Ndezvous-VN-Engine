-- BGMHandler.lua
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BGMFolder = ReplicatedStorage:WaitForChild("BGM")

local BGMHandler = {}

local currentTrack = nil
local persistentTrackName = nil

-- Internal play function
local function playTrack(trackName)
	local sound = BGMFolder:FindFirstChild(trackName)
	if not sound then
		warn("[BGMHandler] Track not found:", trackName)
		return
	end

	if currentTrack then
		currentTrack:Stop()
		currentTrack:Destroy()
	end

	currentTrack = sound:Clone()
	currentTrack.Looped = true
	currentTrack.Volume = 0.1
	currentTrack.Parent = SoundService
	currentTrack:Play()
end

-- Public API
function BGMHandler.PlayPersistent(trackName)
	persistentTrackName = trackName
	playTrack(trackName)
end

function BGMHandler.PlayTemporary(trackName)
	playTrack(trackName)
end

function BGMHandler.RestorePersistent()
	if persistentTrackName then
		playTrack(persistentTrackName)
	else
		BGMHandler.Stop()
	end
end

function BGMHandler.Stop()
	if currentTrack then
		currentTrack:Stop()
		currentTrack:Destroy()
		currentTrack = nil
	end
end

return BGMHandler
