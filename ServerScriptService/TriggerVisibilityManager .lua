local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- ? Toggle this to show or hide triggers in play mode
local DEBUG_MODE = false

-- Only hide if we're in Play mode (not in the editor)
if RunService:IsRunning() then
	for _, part in ipairs(CollectionService:GetTagged("DialogueTrigger")) do
		if part:IsA("BasePart") then
			if DEBUG_MODE then
				part.Transparency = 0.6
				part.CanCollide = false
			else
				part.Transparency = 1
				part.CanCollide = false
			end
		end
	end
end
