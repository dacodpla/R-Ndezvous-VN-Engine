-- ActionExecutor (server-side)
local MovementController = require(game.ReplicatedStorage:WaitForChild("MovementController"))

local ActionExecutor = {}

-- helper: resolve a model by actor name (string) or actorModel (instance)
local Players = game:GetService("Players")

local function resolveActor(actorField)
	if not actorField then return nil, "no actor specified" end

	if typeof(actorField) == "Instance" and actorField:IsA("Model") then
		local model = actorField
		local state = MovementController.GetState(model) or MovementController.CreateState(model)
		return model, state
	end

	if type(actorField) == "string" then
		-- Special case: "Takumi" should resolve to the local player's character
		if actorField == "Takumi" then
			local player = Players:GetPlayers()[1] -- singleplayer assumption
			if player and player.Character then
				local model = player.Character
				local state = MovementController.GetState(model) or MovementController.CreateState(model)
				return model, state
			end
		end

		-- Default: look up NPCs by name
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

	-- Movement: pathfinding for player, direct for NPC
	if action.moveTo then
		local target = action.moveTo
		local isPlayerChar = game.Players:GetPlayerFromCharacter(model) ~= nil

		if action.waitUntilArrive then
			-- blocking: wait until arrive
			local ok
			if isPlayerChar then
				ok = MovementController.MoveTo(model, target) -- pathfinding
			else
				ok = MovementController.MoveDirect(state, target) -- simple move
				if ok and state and model.PrimaryPart then
					state.lastKnownPosition = model.PrimaryPart.CFrame
				end
			end
			return ok
		else
			-- non-blocking: run in background
			task.spawn(function()
				if isPlayerChar then
					MovementController.MoveTo(model, target) -- pathfinding
				else
					local ok2 = MovementController.MoveDirect(state, target) -- simple move
					if ok2 and state and model.PrimaryPart then
						state.lastKnownPosition = model.PrimaryPart.CFrame
					end
				end
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
