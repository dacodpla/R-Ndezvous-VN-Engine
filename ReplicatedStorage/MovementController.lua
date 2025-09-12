-- ReplicatedStorage/MovementController.lua
-- Centralized NPC movement/animation controller

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

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

local function togglePrompts(model, enabled)
	for _, prompt in ipairs(model:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and not prompt:GetAttribute("IgnoreMovementHide") then
			prompt.Enabled = enabled
		end
	end
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

function MovementController.moveWithPath(state, targetPos)
	local humanoid = state.model:FindFirstChildOfClass("Humanoid")
	local hrp = state.model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 4
	})
	path:ComputeAsync(hrp.Position, targetPos)

	if path.Status == Enum.PathStatus.Success then
		for _, waypoint in ipairs(path:GetWaypoints()) do
			humanoid:MoveTo(waypoint.Position)
			humanoid.MoveToFinished:Wait()

			-- Play walk animation while moving
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
		end
	else
		warn("[Pathfinding] Failed to find path for", state.model.Name)
	end
end

--// Animation lookup
local function getAnimInstance(model, animName)
	if not model then
		warn("[MovementController] getAnimInstance called with nil model for anim:", animName)
		return nil
	end

	local animationsRoot = ReplicatedStorage:FindFirstChild("Animations")
	if not animationsRoot then
		warn("[MovementController] Animations folder missing in ReplicatedStorage")
		return nil
	end

	-- Player special case ? always Takumi
	local folderName
	local player = game.Players:GetPlayerFromCharacter(model)
	if player then
		folderName = "Takumi"
	else
		folderName = model.Name
	end

	local folder = animationsRoot:FindFirstChild(folderName)
	if not folder then
		warn(("[MovementController] No animation folder found for %s (model.Name: %s)")
			:format(folderName, model.Name))
		return nil
	end

	print("[DEBUG] Looking for", animName, "in folder:", folderName)
	for _, child in ipairs(folder:GetChildren()) do
		print("  ->", child.Name, child.ClassName)
	end

	local anim = folder:FindFirstChild(animName)
	if anim then
		print("[DEBUG] Found child for", animName, "ClassName:", anim.ClassName)

		if anim:IsA("Animation") then
			return anim
		else
			warn("[MovementController] Found", animName, "but it’s not an Animation (Class:", anim.ClassName, ")")
		end
	end


	warn(("[MovementController] Missing animation: %s for %s (model.Name: %s)")
		:format(animName, folderName, model.Name))
	return nil
end

--// Core play function
local function playAnimation(state, animName, priority)
	local animObj = getAnimInstance(state.model, animName)
	if not animObj or not state.animator then
		-- Warn but don’t stop movement
		local modelName = state.model and state.model.Name or "nil"
		warn("[MovementController] No anim loaded for", modelName, "anim:", animName)
		return
	end

	-- Don’t restart same anim unnecessarily
	if state.currentTrack and state.currentTrack.IsPlaying and state.currentTrack.Name == animObj.Name then
		return
	end

	-- Stop old track if different
	if state.currentTrack and state.currentTrack.IsPlaying then
		state.currentTrack:Stop()
	end

	local track = state.animator:LoadAnimation(animObj)
	track.Name = animObj.Name
	track.Priority = priority or Enum.AnimationPriority.Idle
	track.Looped = true
	track:Play()

	state.currentTrack = track
end

--// High-level helpers
local function playWalkAnim(state)
	local animName = state.model:GetAttribute("WalkAnimation") or "Walk"
	local animObj = getAnimInstance(state.model, animName)

	if animObj then
		playAnimation(state, animName, Enum.AnimationPriority.Movement)
	else
		warn("[MovementController] No Walk animation for", state.model.Name, "— moving without anim.")
		-- Fallback: humanoid will still walk without custom anims
	end
end

local function playIdleAnim(state)
	local animName = state.model:GetAttribute("IdleAnimation") or "Idle"
	local animObj = getAnimInstance(state.model, animName)

	if animObj then
		playAnimation(state, animName, Enum.AnimationPriority.Idle)
	else
		warn("[MovementController] No Idle animation for", state.model.Name, "— standing without anim.")
	end
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
function MovementController.MoveDirect(state, targetPos, opts)
	opts = opts or {}
	local humanoid = state.humanoid
	if not humanoid then return false end

	-- ?? Block movement if inDialogue, unless explicitly allowed
	if state.inDialogue and not opts.allowDuringDialogue then
		return false
	end

	print("[MovementController] MoveDirect called for:", state.model.Name, "to", targetPos)

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


-- New Pathfinder-based MoveTo
-- MovementController.lua
local PathfindingService = game:GetService("PathfindingService")

function MovementController.MoveTo(model, targetPosition)
	togglePrompts(model, false) -- hide prompts while moving

	if not model or not targetPosition then return end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	-- Retrieve the state for animations
	local state = MovementController.GetState(model) or MovementController.CreateState(model)

	-- Generate a path
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
	})
	path:ComputeAsync(root.Position, targetPosition)

	if path.Status ~= Enum.PathStatus.Success then
		humanoid:MoveTo(targetPosition) -- fallback
		return
	end

	local waypoints = path:GetWaypoints()
	if #waypoints == 0 then return end

	-- Start walking animation
	playWalkAnim(state)

	for _, waypoint in ipairs(waypoints) do
		-- Pause check
		if state.isPaused then
			playIdleAnim(state)
			return
		end

		humanoid:MoveTo(waypoint.Position)
		local reached = humanoid.MoveToFinished:Wait(2) -- timeout to avoid freezing
		if not reached then
			path:ComputeAsync(root.Position, targetPosition)
			if path.Status == Enum.PathStatus.Success then
				waypoints = path:GetWaypoints()
			end
		end
	end

	-- Switch back to idle when done
	playIdleAnim(state)
	togglePrompts(model, true)
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
				-- ?? Keep retrying this MoveTo until it succeeds
				local arrived = false
				while not arrived and state.model and state.model.Parent do
					if state.inDialogue then break end -- if dialogue starts again, break early
					arrived = MovementController.MoveDirect(state, targetPart.Position)
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

local following = {} -- [Model] = thread

function MovementController.FollowPlayer(state, player)
	-- Restore NPC to last known position before following (optional)
	if state.lastKnownPosition and state.model and state.model.PrimaryPart then
		state.model:SetPrimaryPartCFrame(state.lastKnownPosition)
	end

	if following[state.model] then return end
	following[state.model] = task.spawn(function()
		local safeZoneRadius = 5

		while state.model and state.model.Parent and player.Character and player.Character.PrimaryPart do
			if state.isPaused then
				playIdleAnim(state)
				task.wait(0.5)
				continue
			end

			local playerRoot = player.Character.PrimaryPart
			local npcRoot = state.model.PrimaryPart
			local targetPos = playerRoot.Position
			local npcPos = npcRoot.Position
			local distance = (npcPos - targetPos).Magnitude

			if distance > safeZoneRadius + 0.5 then
				local lookVec = playerRoot.CFrame.LookVector
				local safeTarget = targetPos - lookVec * safeZoneRadius
				MovementController.MoveTo(state.model, safeTarget)
			else
				if state.currentTrack and state.currentTrack.IsPlaying then
					state.currentTrack:Stop()
				end
				playIdleAnim(state)
			end
			task.wait(0.5)
		end
	end)
end



function MovementController.StopFollowing(state)
	if following[state.model] then
		task.cancel(following[state.model])
		following[state.model] = nil
	end
end

-- Setup helper
function MovementController.CreateState(npcModel)
	local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	if not npcModel.PrimaryPart then return nil end

	-- ensure Animator exists
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "AutoAnimator"
		animator.Parent = humanoid
		print("[MovementController] Auto-created Animator for", npcModel.Name)
	end

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



-- ?? NEW: GetState helper
function MovementController.GetState(npcModel)
	return npcStates[npcModel]
end

-- (Optional) allow cleanup if an NPC is destroyed
function MovementController.RemoveState(npcModel)
	npcStates[npcModel] = nil
end

-- Dialogue hook
local DialogueEvent = ReplicatedStorage:WaitForChild("DialogueEvent")

if RunService:IsServer() then
	DialogueEvent.OnServerEvent:Connect(function(player, action, payload)
		print("[MovementController] DialogueEvent received:", action, payload)

		if action == "Start" or action == "End" then
			local npcName = payload
			if not npcName then return end

			local npcModel = workspace:FindFirstChild(npcName)
			if not npcModel then return end

			local state = MovementController.GetState and MovementController.GetState(npcModel)
			if not state then
				warn("[MovementController] No patrol state found for", npcName)
				return
			end

			if action == "Start" then
				if state.isPatrolling then
					state.inDialogue = true
					print("[MovementController] Pausing patrol for", npcName)
				end
			elseif action == "End" then
				if state.isPatrolling then
					state.inDialogue = false
					print("[MovementController] Resuming patrol for", npcName)
				end
			end
		else
			-- ignore RunActions, AfterDialogue, etc.
			print("[MovementController] Ignored action:", action)
		end
	end)
end

function MovementController.PauseMovement(model)
	local state = MovementController.GetState(model)
	if not state then return end
	state.isPaused = true

	-- Stop current movement immediately
	local humanoid = state.humanoid or model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Force-stop MoveTo by moving to its own position
		humanoid:MoveTo(model.PrimaryPart.Position)
		-- Optional: clear velocity to prevent sliding
		if model.PrimaryPart then
			model.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
		end
	end

	-- Stop walk animation
	if state.currentTrack and state.currentTrack.IsPlaying then
		state.currentTrack:Stop()
	end

	-- Switch to idle animation
	playIdleAnim(state)
end


function MovementController.ResumeMovement(model)
	local state = MovementController.GetState(model)
	if not state then return end
	state.isPaused = false
end


return MovementController

