-- DialogueDispatcher (ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueEvent = ReplicatedStorage:WaitForChild("DialogueEvent")

local ActionExecutor = require(ReplicatedStorage:WaitForChild("ActionExecutor"))
local AfterDialogueHandler = require(ReplicatedStorage:WaitForChild("AfterDialogueHandler"))

print("[DialogueDispatcher] Ready.")

DialogueEvent.OnServerEvent:Connect(function(player, command, payload)
	if command == "RunActions" then
		print("[DialogueDispatcher] RunActions from", player.Name)
		-- payload is the actions table (array)
		ActionExecutor.Run(payload, { player = player })
	elseif command == "AfterDialogue" then
		print("[DialogueDispatcher] AfterDialogue from", player.Name)
		AfterDialogueHandler.Execute(payload, { player = player })
	else
		warn("[DialogueDispatcher] Unknown command:", tostring(command))
	end
end)
