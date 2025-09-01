-- ReplicatedStorage/MovementController.lua
-- Centralized NPC movement/animation controller

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementController = {}
local npcStates = {}

-- Config defaults
local DEFAULT_SPEED = 8
local MOVE_TO_TIMEOUT = 10
local ARRIVAL_THRESHOLD = 5

-- Utilities
local function safeHumanoid(model)
	return model and model:FindFirstChildOfClass("Humanoid")
end

local function ensureAnimator(humanoid)
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "AutoAnimator"
		animator.Parent = humanoid
	end
	return animator
end

local function getAnimInstance(model, animName)
	local animationsRoot = ReplicatedStorage:FindFirstChild("Animations")
	if not animationsRoot then return nil end
	local folder = animationsRoot:FindFirstChild(model.Name)
	if not folder then return nil end
	local anim = folder:FindFirstChild(animName)
	if anim and anim:IsA("Animation") then
		return anim
	end
	return nil
end

-- Animation Handling
local function playAnimation(state, animName, priority)
	local animObj = getAnimInstance(state.model, animName)
	if not animObj then return end

	if state.currentTrack and state.currentTrack.IsPlaying then
		state.currentTrack:Stop()
	end

	local track = state.animator:LoadAnimation(animObj)
	track.Priority = priority or Enum.AnimationPriority.Idle
	track.Looped = true
	track:Play()
	state.currentTrack = track
end

local function playWalkAnim(state)
	local animName = state.model:GetAttribute("PatrolWalkAnim") or "Walk"
	playAnimation(state, animName, Enum.AnimationPriority.Movement)
end

local function playIdleAnim(state)
	local animName = state.model:GetAttribute("IdleAnimation") or "Idle"
	playAnimation(state, animName, Enum.AnimationPriority.Idle)
end

-- Pathfinding
local function computePath(startPos, goalPos)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true
	})
	local ok = pcall(function()
		path:ComputeAsync(startPos, goalPos)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	return path
end

-- Public API

-- Moves NPC directly to target (fallback)
function MovementController.MoveDirect(state, targetPos)
	local humanoid = state.humanoid
	if not humanoid then return false end

	humanoid.WalkSpeed = state.model:GetAttribute("PatrolSpeed") or DEFAULT_SPEED
	playWalkAnim(state)

	local arrived = false
	local startTime = time()
	while not arrived and (time() - startTime) < MOVE_TO_TIMEOUT do
		humanoid:MoveTo(targetPos)
		local reached = false
		local conn = humanoid.MoveToFinished:Connect(function(success)
			reached = success
		end)

		local waited = 0
		repeat
			task.wait(0.05)
			waited += 0.05
		until reached or waited > 1.5

		conn:Disconnect()

		if (state.model.PrimaryPart.Position - targetPos).Magnitude <= ARRIVAL_THRESHOLD then
			arrived = true
		end
	end

	playIdleAnim(state)
	return arrived
end

-- Uses pathfinding
-- Modified MoveTo with dialogue interrupt support
function MovementController.MoveTo(state, targetPos)
	local humanoid = state.humanoid
	if not humanoid then return false end

	local path = computePath(state.model.PrimaryPart.Position, targetPos)
	if not path then
		return MovementController.MoveDirect(state, targetPos)
	end

	humanoid.WalkSpeed = state.model:GetAttribute("PatrolSpeed") or DEFAULT_SPEED
	playWalkAnim(state)

	for _, wp in ipairs(path:GetWaypoints()) do
		-- ❌ If dialogue starts, stop walking immediately
		if state.inDialogue then
			humanoid:Move(Vector3.new(0, 0, 0), false) -- stop
			playIdleAnim(state)
			return false -- mark as interrupted
		end

		local reached = false
		humanoid:MoveTo(wp.Position)
		local conn = humanoid.MoveToFinished:Connect(function(success)
			reached = success
		end)

		local start = time()
		while not reached and (time() - start) < MOVE_TO_TIMEOUT do
			if state.inDialogue then
				humanoid:Move(Vector3.new(0, 0, 0), false)
				conn:Disconnect()
				playIdleAnim(state)
				return false -- interrupted mid-walk
			end
			task.wait(0.1)
		end
		conn:Disconnect()
	end

	playIdleAnim(state)
	return true
end


-- Makes NPC patrol through its PatrolPoints
function MovementController.Patrol(state)
	local pointsFolder = state.model:FindFirstChild("PatrolPoints")
	if not pointsFolder then return end
	local points = {}
	for _, p in ipairs(pointsFolder:GetChildren()) do
		if p:IsA("BasePart") then table.insert(points, p) end
	end
	if #points < 2 then return end

	state.points = points
	state.idx = 1
	state.dir = 1

	task.spawn(function()
		while state.model and state.model.Parent do
			-- Pause patrol fully while in dialogue
			if state.inDialogue then
				playIdleAnim(state)
				repeat task.wait(0.2) until not state.inDialogue
				print("[Patrol] "..state.model.Name.." resumed after dialogue, retrying waypoint "..state.idx)
			end

			local targetPart = state.points[state.idx]
			if targetPart then
				-- 🔑 Keep retrying this MoveTo until it succeeds
				local arrived = false
				while not arrived and state.model and state.model.Parent do
					if state.inDialogue then break end -- if dialogue starts again, break early
					arrived = MovementController.MoveTo(state, targetPart.Position)
					if not arrived then
						print("[Patrol] "..state.model.Name.." retrying waypoint "..state.idx)
						task.wait(0.5)
					end
				end

				if arrived then
					task.wait(state.model:GetAttribute("PatrolPause") or 1)

					local loopType = state.model:GetAttribute("PatrolLoop") or "Loop"
					if loopType == "PingPong" then
						if state.idx == #state.points then state.dir = -1 end
						if state.idx == 1 then state.dir = 1 end
						state.idx = state.idx + state.dir
					else
						state.idx = state.idx + 1
						if state.idx > #state.points then state.idx = 1 end
					end
				end
			end

			task.wait(0.1)
		end
	end)
end




-- Makes NPC follow a Player
function MovementController.FollowPlayer(state, player)
	task.spawn(function()
		while state.model and state.model.Parent and player.Character and player.Character.PrimaryPart do
			local targetPos = player.Character.PrimaryPart.Position
			MovementController.MoveTo(state, targetPos)
			task.wait(0.5)
		end
	end)
end

-- Setup helper
function MovementController.CreateState(npcModel)
	local humanoid = safeHumanoid(npcModel)
	if not humanoid then return nil end
	if not npcModel.PrimaryPart then return nil end
	local animator = ensureAnimator(humanoid)

	local state = {
		model = npcModel,
		inDialogue = false,
		continueInDialogue = npcModel:GetAttribute("PatrolContinueInDialogue") or false,
		humanoid = humanoid,
		animator = animator,
		currentTrack = nil
	}

	npcStates[npcModel] = state
	return state
end

-- 🔎 NEW: GetState helper
function MovementController.GetState(npcModel)
	return npcStates[npcModel]
end

-- (Optional) allow cleanup if an NPC is destroyed
function MovementController.RemoveState(npcModel)
	npcStates[npcModel] = nil
end

-- Dialogue hook
local DialogueEvent = ReplicatedStorage:WaitForChild("DialogueEvent")

DialogueEvent.OnServerEvent:Connect(function(player, action, npcName)
	print("[MovementController] DialogueEvent received:", action, npcName)

	if not npcName then return end
	local npcModel = workspace:FindFirstChild(npcName)
	if not npcModel then return end

	local state = MovementController.GetState and MovementController.GetState(npcModel)
	if not state then
		warn("[MovementController] No patrol state found for", npcName)
		return
	end

	if action == "Start" then
		state.inDialogue = true
		print("[MovementController] Pausing patrol for", npcName)
	elseif action == "End" then
		state.inDialogue = false
		print("[MovementController] Resuming patrol for", npcName)
	end
end)

return MovementController
