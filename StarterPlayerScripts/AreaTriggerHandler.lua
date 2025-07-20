local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

local TRIGGER_TAG = "DialogueTrigger"
local TRIGGER_RADIUS = 2

local wasInside = {}
local triggered = {}

RunService.RenderStepped:Connect(function()
	for _, trigger in ipairs(CollectionService:GetTagged(TRIGGER_TAG)) do
		if trigger:IsA("BasePart") and trigger:IsDescendantOf(workspace) then
			local distance = (root.Position - trigger.Position).Magnitude
			local isInside = distance <= TRIGGER_RADIUS

			local dialogueName = trigger:GetAttribute("DialogueName")
			local canRepeat = trigger:GetAttribute("CanRepeat")

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

				if dialogueName then
					print("[AreaTrigger] Player triggered dialogue:", dialogueName)
					triggered[trigger] = true

					local dialogueFolder = ReplicatedStorage:FindFirstChild("DialogueModules")
					if dialogueFolder then
						local module = dialogueFolder:FindFirstChild(dialogueName)
						if module and module:IsA("ModuleScript") then
							local dialogueData = require(module)
							if typeof(_G.EnterStoryMode) == "function" then
								_G.EnterStoryMode(dialogueData)
							end
						else
							warn("[AreaTrigger] Dialogue module not found:", dialogueName)
						end
					else
						warn("[AreaTrigger] DialogueModules folder not found.")
					end
				else
					warn("[AreaTrigger] Trigger part missing DialogueName attribute:", trigger.Name)
				end
			end
		end
	end
end)
