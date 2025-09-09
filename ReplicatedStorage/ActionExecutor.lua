-- ActionExecutor (server-side)
local MovementController = require(game.ReplicatedStorage:WaitForChild("MovementController"))

local ActionExecutor = {}

-- helper: resolve a model by actor name (string) or actorModel (instance)
local function resolveActor(actorField)
	if not actorField then return nil, "no actor specified" end

	if typeof(actorField) == "Instance" and actorField:IsA("Model") then
		local model = actorField
		local state = MovementController.GetState(model) or MovementController.CreateState(model)
		return model, state
	end

	if type(actorField) == "string" then
		local model = workspace:FindFirstChild(actorField)
		if not model then
			return nil, ("actor model '%s' not found in workspace"):format(actorField)
		end
		local state = MovementController.GetState(model) or MovementController.CreateState(model)
		return model, state
	end

	return nil, "unsupported actor type"
end

-- Run one move action (supports moveTo vector, teleport, and simple turn)
local function runSingleAction(action, opts)
	opts = opts or {}
	if not action then return false end

	-- allow specifying actor as .actor (string) or .actorModel (Instance)
	local actorKey = action.actor or action.actorName or action.actorModel
	local model, stateOrErr = resolveActor(actorKey)
	if not model then
		warn("[ActionExecutor] resolveActor failed:", stateOrErr)
		return false
	end
	local state = stateOrErr

	-- Movement: use MovementController.MoveTo (pathfinder) with interruption/during-dialogue handling
	if action.moveTo then
		local target = action.moveTo
		if action.waitUntilArrive then
			-- blocking: wait until MoveTo returns true/false
			local ok = MovementController.MoveTo(state, target)
			return ok
		else
			-- non-blocking: run in background
			task.spawn(function()
				MovementController.MoveTo(state, target)
			end)
			return true
		end
	end

	-- Teleport: instant reposition
	if action.teleport then
		local tp = action.teleport
		local newPos = tp.target or tp.position or tp
		if model.PrimaryPart then
			model:SetPrimaryPartCFrame(CFrame.new(newPos))
			return true
		end
		return false
	end

	-- Turn to (face a Vector3 or another actor)
	if action.turnTo then
		local aim = action.turnTo
		local aimPos
		if typeof(aim) == "Instance" and aim:IsA("Model") and aim.PrimaryPart then
			aimPos = aim.PrimaryPart.Position
		elseif typeof(aim) == "Vector3" then
			aimPos = aim
		end
		if aimPos and model.PrimaryPart then
			local look = CFrame.new(model.PrimaryPart.Position, Vector3.new(aimPos.X, model.PrimaryPart.Position.Y, aimPos.Z))
			model:SetPrimaryPartCFrame(look)
			return true
		end
	end

	-- Expandable: play SFX, set face flags, etc.
	return false
end

-- Run an array of actions in parallel, respect `waitUntilArrive` per action
-- opts can contain { player = player }
function ActionExecutor.Run(actions, opts)
	if not actions or type(actions) ~= "table" then
		warn("[ActionExecutor] invalid actions")
		return false
	end

	-- Kick off each action
	local tasks = {}
	for _, action in ipairs(actions) do
		local a = action
		if a.waitUntilArrive then
			-- blocking on main thread for sync actions - run directly
			local ok = runSingleAction(a, opts)
			tasks[#tasks + 1] = ok
		else
			-- background
			task.spawn(function()
				runSingleAction(a, opts)
			end)
			tasks[#tasks + 1] = true
		end
	end

	return true
end

return ActionExecutor
