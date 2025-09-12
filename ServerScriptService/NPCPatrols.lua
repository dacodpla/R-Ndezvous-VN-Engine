-- NPCPatrols.server.lua
local MovementController = require(game.ReplicatedStorage:WaitForChild("MovementController"))

-- Store states
local npcStates = {}

local function startPatrol(npcModel)
	if npcStates[npcModel] then return end

	local state = MovementController.CreateState(npcModel)
	if not state then return end
	npcStates[npcModel] = state

	print("[NPCPatrols] Starting patrol for", npcModel.Name)
	MovementController.Patrol(state)
end

-- Scan workspace for NPCs with PatrolPoints
for _, obj in ipairs(workspace:GetDescendants()) do
	if obj:IsA("Model") and obj:FindFirstChild("PatrolPoints") and obj:FindFirstChildOfClass("Humanoid") then
		startPatrol(obj)
	end
end

for _, npc in ipairs(workspace:GetChildren()) do
	if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
		MovementController.CreateState(npc)
	end
end


workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Folder") and desc.Name == "PatrolPoints" then
		local model = desc.Parent
		if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
			startPatrol(model)
		end
	end
end)
