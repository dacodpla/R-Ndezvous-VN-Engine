---- EnhancedPlayerVisibility.lua
---- Improves player visibility in isometric view by highlighting character and fading all obstacles between camera and player.

--local Players = game:GetService("Players")
--local RunService = game:GetService("RunService")

--local player = Players.LocalPlayer
--local camera = workspace.CurrentCamera

---- Config
--local FADE_TRANSPARENCY = 0.7      -- how transparent obstacles become
--local RESTORE_SPEED = 2            -- speed to restore original transparency
--local RAY_STEP = 0.5               -- step size along the ray
--local MAX_RAY_DISTANCE = 500       -- max distance to check
--local HIGHLIGHT_COLOR = Color3.fromRGB(255, 255, 0) -- bright yellow outline

--local fadedParts = {}              -- tracks {part = originalTransparency}
--local currentFrameParts = {}       -- parts faded this frame

---- Highlight setup
--local function ensureHighlight(char)
--	local h = char:FindFirstChildOfClass("Highlight")
--	if not h then
--		h = Instance.new("Highlight")
--		h.FillColor = Color3.fromRGB(255,255,255)
--		h.FillTransparency = 1          -- no fill, only outline
--		h.OutlineColor = HIGHLIGHT_COLOR
--		h.OutlineTransparency = 0.1
--		h.DepthMode = Enum.HighlightDepthMode.Occluded
--		h.Parent = char
--	end
--end

--local function onCharacterAdded(char)
--	ensureHighlight(char)
--end

--player.CharacterAdded:Connect(onCharacterAdded)
--if player.Character then
--	onCharacterAdded(player.Character)
--end

---- Fade logic
--RunService.RenderStepped:Connect(function(dt)
--	if not player.Character or not player.Character.PrimaryPart then return end
--	if not camera then camera = workspace.CurrentCamera end

--	-- Prepare for this frame
--	currentFrameParts = {}

--	-- Cast multiple points along the ray from camera to player
--	local origin = camera.CFrame.Position
--	local target = player.Character.PrimaryPart.Position
--	local direction = (target - origin)
--	local distance = direction.Magnitude
--	local stepCount = math.floor(distance / RAY_STEP)
--	local rayParams = RaycastParams.new()
--	rayParams.FilterDescendantsInstances = {player.Character}
--	rayParams.FilterType = Enum.RaycastFilterType.Blacklist

--	for i = 1, stepCount do
--		local stepPos = origin + direction.Unit * (i * RAY_STEP)
--		local rayResult = workspace:Raycast(origin, stepPos - origin, rayParams)
--		if rayResult and rayResult.Instance then
--			local part = rayResult.Instance
--			if part:IsA("BasePart") and not fadedParts[part] then
--				fadedParts[part] = part.Transparency
--				part.Transparency = FADE_TRANSPARENCY
--			end
--			currentFrameParts[part] = true
--		end
--	end

--	-- Restore parts that are no longer blocking the view
--	for part, origTrans in fadedParts do
--		if not currentFrameParts[part] then
--			if part and part.Parent then
--				part.Transparency = math.clamp(
--					part.Transparency + RESTORE_SPEED * dt,
--					origTrans,
--					1
--				)
--				if part.Transparency <= origTrans + 0.01 then
--					part.Transparency = origTrans
--					fadedParts[part] = nil
--				end
--			else
--				fadedParts[part] = nil
--			end
--		end
--	end
--end)