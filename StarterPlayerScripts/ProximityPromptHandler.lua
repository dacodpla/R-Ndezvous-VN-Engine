local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local promptConnections = {}

print("[ProximityPromptHandler] Loaded. _G.EnterStoryMode =", _G.EnterStoryMode)

-- ?? Clean old connections if any
for _, conn in promptConnections do
	if typeof(conn) == "RBXScriptConnection" then
		conn:Disconnect()
	end
end

-- Debug: List all DialogueModules available
local dialogueModulesFolder = ReplicatedStorage:FindFirstChild("DialogueModules")
if not dialogueModulesFolder then
	warn("DialogueModules folder not found in ReplicatedStorage!")
else
	print("Available DialogueModules:")
	for _, mod in dialogueModulesFolder:GetChildren() do
		print(" -", mod.Name, mod.ClassName)
	end
end

-- ?? Scan for all ProximityPrompts in the Workspace
for _, model in workspace:GetDescendants() do
	if model:IsA("Model") and model:FindFirstChildWhichIsA("ProximityPrompt", true) then
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)

		print("Prompt found!", prompt:GetFullName())

		local conn = prompt.Triggered:Connect(function()
			print("ProximityPrompt triggered by", player.Name)

			local dialogueName = model:GetAttribute("DialogueName")
			if not dialogueName then
				warn("No DialogueName attribute found in", model.Name)
				return
			end

			print("Triggering dialogue:", dialogueName)

			-- ?? Load dialogue data from module
			local result = nil
			local success, requireResult = pcall(function()
				local module = ReplicatedStorage:FindFirstChild("DialogueModules") and ReplicatedStorage.DialogueModules:FindFirstChild(dialogueName)
				if not module then
					warn("Dialogue module '" .. tostring(dialogueName) .. "' not found in DialogueModules folder!")
					return nil
				end
				print("Requiring module:", module)
				return require(module)
			end)

			if not success then
				warn("Error requiring module:", requireResult)
				result = nil
			else
				result = requireResult
			end

			if typeof(result) ~= "table" then
				warn("Dialogue module did not return a table for '" .. tostring(dialogueName) .. "'. Passing empty table to EnterStoryMode.")
				result = {}
			end

			print("Loaded dialogue module. First line speaker:", result[1] and result[1].speaker)
			print("Type of result:", typeof(result))
			print("Result content:", result)

			-- ? Now we have dialogue data, enter story mode and pass it
			print("[ProximityPromptHandler] About to call _G.EnterStoryMode. Current value:", _G.EnterStoryMode)
			print("[ProximityPromptHandler] About to call _G.EnterStoryMode. Current value:", _G.EnterStoryMode)
			if _G.EnterStoryMode then
				local ok, err = pcall(function()
					local npcName
					-- If it's an NPC model with a Humanoid + direct ProximityPrompt, use its name
					if model:IsA("Model") and model:FindFirstChild("Humanoid") and model:FindFirstChild("ProximityPrompt") then
						npcName = model.Name
					else
						-- fallback for object dialogues (doors, mirrors, books, etc.)
						npcName = dialogueName
					end

					_G.EnterStoryMode(result, npcName)
				end)
				if not ok then
					warn("[ProximityPromptHandler] Error calling _G.EnterStoryMode:", err)
				end
			else
				warn("[ProximityPromptHandler] EnterStoryMode function not ready. _G.EnterStoryMode =", _G.EnterStoryMode)
			end
		end)

		table.insert(promptConnections, conn)
	end
end

