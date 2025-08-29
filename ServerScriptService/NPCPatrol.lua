-- NPCPatrols.server.lua (Fixed Version)
-- Server-side patrol system with Pathfinding + configurable walk animation
-- Place in ServerScriptService

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Configuration
local DEFAULT_SPEED = 8
local DEFAULT_PAUSE = 1
local DEFAULT_LOOP = "Loop" -- or "PingPong"
local DEFAULT_WALK_ANIM = "Walk"
local DEFAULT_PATHFINDING = true
local MAX_PATH_RETRIES = 2
local MOVE_TO_TIMEOUT = 15
local ARRIVAL_THRESHOLD = 3

-- State
local patrolStates = {} -- [model] = state

local function safeFindHumanoid(model)
	if not model then return nil end
	return model:FindFirstChildOfClass("Humanoid")
end

local function ensureAnimator(humanoid)
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "AutoAnimator"
		animator.Parent = humanoid
	end
	return animator
end

local function collectWaypoints(npcModel)
	local waypoints = {}
	local folder = npcModel:FindFirstChild("PatrolPoints")
	if folder then
		for _, point in ipairs(folder:GetChildren()) do
			if point:IsA("BasePart") then
				table.insert(waypoints, point)
			end
		end
	end
	return waypoints
end

local function getAnimInstance(model, animName)
	local animationsRoot = ReplicatedStorage:FindFirstChild("Animations")
	if not animationsRoot then return nil end
	local folder = animationsRoot:FindFirstChild(model.Name)
	if not folder then return nil end
	local anim = folder:FindFirstChild(animName)
	if not anim or not anim:IsA("Animation") then return nil end
	return anim
end

local function playWalkAnimationFor(state)
	local humanoid = state.humanoid
	if not humanoid or not state.model then return end
	local animName = state.model:GetAttribute("PatrolWalkAnim") or DEFAULT_WALK_ANIM
	local animObj = getAnimInstance(state.model, animName)
	if not animObj then return end
	local animator = ensureAnimator(humanoid)
	if not animator then return end

	if state.walkTrack then
		pcall(function() if state.walkTrack.IsPlaying then state.walkTrack:Stop() end end)
		state.walkTrack = nil
	end

	local ok, track = pcall(function()
		return animator:LoadAnimation(animObj)
	end)
	if ok and track then
		track.Looped = true
		track:Play()
		state.walkTrack = track
	end
end

local function stopWalkAnimationFor(state)
	if state and state.walkTrack then
		pcall(function() if state.walkTrack.IsPlaying then state.walkTrack:Stop() end end)
		state.walkTrack = nil
	end
end

local function computePath(startPos, goalPos, agentRadius)
	local path = PathfindingService:CreatePath({AgentRadius = agentRadius or 2, AgentHeight = 5, AgentCanJump = true})
	local ok = pcall(function() path:ComputeAsync(startPos, goalPos) end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	return path
end

local function followPath(state, path)
	local humanoid = state.humanoid
	if not humanoid then return false end
	local waypoints = path:GetWaypoints()
	if #waypoints == 0 then return false end
	for _, wp in ipairs(waypoints) do
		if not state.model or not state.model.PrimaryPart then return false end
		local arrived = false
		local conn
		conn = humanoid.MoveToFinished:Connect(function() arrived = true end)
		humanoid:MoveTo(wp.Position)

		local startT = time()
		while not arrived and time() - startT < MOVE_TO_TIMEOUT do
			task.wait(0.05)
		end
		if conn then conn:Disconnect() end
	end
	return true
end

-- ✅ Fixed moveDirect
local function moveDirect(state, targetPos)
	local humanoid = state.humanoid
	if not humanoid or not state.model or not state.model.PrimaryPart or not targetPos then return false end

	playWalkAnimationFor(state)

	local arrived = false
	while not arrived do
		humanoid:MoveTo(targetPos)
		local reached = humanoid.MoveToFinished:Wait()
		if (state.model.PrimaryPart.Position - targetPos).Magnitude <= ARRIVAL_THRESHOLD then
			arrived = true
		else
			task.wait(0.05)
		end
	end

	stopWalkAnimationFor(state)
	return true
end

local function startPatrolFor(model)
	if patrolStates[model] then return end
	local humanoid = safeFindHumanoid(model)
	local folder = model:FindFirstChild("PatrolPoints")
	if not humanoid or not folder then return end
	local points = collectWaypoints(model)
	if #points < 2 then return end
	if not model.PrimaryPart then return end

	local state = {
		model = model,
		humanoid = humanoid,
		points = points,
		idx = 1,
		dir = 1,
		moving = false,
		walkTrack = nil,
		continueInDialogue = model:GetAttribute("PatrolContinueInDialogue") or false,
		usePathfinding = (model:GetAttribute("PatrolUsePathfinding") == nil) and DEFAULT_PATHFINDING or model:GetAttribute("PatrolUsePathfinding"),
	}
	patrolStates[model] = state

	warn("[NPCPatrols] ✅ Patrol started for", model.Name, "with", #points, "waypoints.")

	task.spawn(function()
		while model and model.Parent do
			if not state.moving then
				state.moving = true
				local targetPart = state.points[state.idx]
				if targetPart then
					local success = false
					if state.usePathfinding then
						local path = computePath(model.PrimaryPart.Position, targetPart.Position, 2)
						if path then success = followPath(state, path) else success = moveDirect(state, targetPart.Position) end
					else
						success = moveDirect(state, targetPart.Position)
					end
					if not success then warn("[NPCPatrols] Failed to reach waypoint", state.idx, "for", model.Name) end

					local pauseTime = model:GetAttribute("PatrolPause") or DEFAULT_PAUSE
					task.wait(pauseTime)

					local loopType = model:GetAttribute("PatrolLoop") or DEFAULT_LOOP
					if loopType == "PingPong" then
						if state.idx == #state.points then state.dir = -1 end
						if state.idx == 1 then state.dir = 1 end
						state.idx = state.idx + state.dir
					else
						state.idx = state.idx + 1
						if state.idx > #state.points then state.idx = 1 end
					end
				end
				state.moving = false
			end
			task.wait(0.1)
		end
		stopWalkAnimationFor(state)
		patrolStates[model] = nil
	end)
end

-- Scan workspace for patrol NPCs
for _, obj in ipairs(workspace:GetDescendants()) do
	if obj:IsA("Model") and obj:FindFirstChild("PatrolPoints") and obj:FindFirstChildOfClass("Humanoid") then
		startPatrolFor(obj)
	end
end

workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Folder") and desc.Name == "PatrolPoints" then
		local model = desc.Parent
		if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
			startPatrolFor(model)
		end
	end
end)

-- End of NPCPatrols.server.lua (Fixed Version)
