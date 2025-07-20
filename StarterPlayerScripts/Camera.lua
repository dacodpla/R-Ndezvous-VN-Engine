--//Settings//--
local zoomValue = Instance.new("NumberValue")
zoomValue.Value = 90 -- Default zoom distance
local FieldOfView = 10 -- Standard FOV for normal GUI size

--//Do not edit unless you know what you're doing//--
local Player = game.Players.LocalPlayer
-- Global speaker override (optional)
_G.CurrentSpeakerModel = nil
local currentFocusPosition = nil
local Character = Player.Character or Player.CharacterAdded:Wait()
local Camera = workspace.CurrentCamera
Camera.CameraType = Enum.CameraType.Scriptable -- Prevents default zoom controls

-- Prevent mouse wheel from changing zoom
local UserInputService = game:GetService("UserInputService")
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		-- Do nothing: disables zooming with mouse wheel
	end
end)

local RunService = game:GetService("RunService")

RunService.RenderStepped:Connect(function()
	Camera.FieldOfView = FieldOfView

	local focusModel = _G.CurrentSpeakerModel or Character
	if focusModel and focusModel:FindFirstChild("Head") then
		local head = focusModel.Head
		local targetPos = head.Position
		game:GetService("SoundService"):SetListener(Enum.ListenerType.ObjectCFrame, head)

		-- Initialize if nil
		if not currentFocusPosition then
			currentFocusPosition = targetPos
		end

		-- Smoothly interpolate
		currentFocusPosition = currentFocusPosition:Lerp(targetPos, 0.1)

		local zoom = zoomValue.Value
		local camPos = Vector3.new(
			currentFocusPosition.X + zoom,
			currentFocusPosition.Y + zoom,
			currentFocusPosition.Z + zoom
		)

		Camera.CFrame = CFrame.new(camPos, currentFocusPosition)
	end
end)



local TweenService = game:GetService("TweenService")

local function ZoomTo(distance, duration)
	local tween = TweenService:Create(zoomValue, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Value = distance
	})
	tween:Play()
end

local function ResetCameraFocus()
	local focusModel = _G.CurrentSpeakerModel or Character
	if focusModel and focusModel:FindFirstChild("Head") then
		currentFocusPosition = focusModel.Head.Position
	end
end

function _G.ResetCameraFocus()
	_G.CurrentSpeakerModel = nil
	currentFocusPosition = nil -- forces re-focus to player
end


_G.ResetCameraFocus = ResetCameraFocus

_G.ZoomTo = ZoomTo -- Make it globally callable


