local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("BlackScreenGui")
local dialogueGui = playerGui:WaitForChild("DialogueGui")

local blackFrame = gui:WaitForChild("BlackFrame")
local textLabel = blackFrame:WaitForChild("TransitionText")
local clickCatcher = blackFrame:WaitForChild("ClickCatcher")

-- Returns the tween object so we can wait on it manually
local function fade(object, props, duration)
	local tween = TweenService:Create(object, TweenInfo.new(duration), props)
	tween:Play()
	return tween
end


-- Main transition function
local function playTransition(config)
	local transitionType = config and config.type or "staticText"
	local messages = config and config.messages or {""}
	local duration = config and config.duration or 2

	-- Hide VN GUI before fade-in
	dialogueGui.Enabled = false
	RunService.RenderStepped:Wait() -- Ensure GUI visually updates

	-- Prepare blackFrame and textLabel
	blackFrame.Visible = true
	textLabel.Visible = true
	clickCatcher.Visible = false
	textLabel.Text = ""
	blackFrame.BackgroundTransparency = 1
	textLabel.TextTransparency = 1

	if transitionType == "staticText" then
		-- Set message
		textLabel.Text = messages[1] or "..."

		-- Fade in both blackFrame and textLabel simultaneously
		local fadeInFrame = fade(blackFrame, {BackgroundTransparency = 0}, 0.5)
		local fadeInText = fade(textLabel, {TextTransparency = 0}, 0.5)
		fadeInFrame.Completed:Wait()

		task.wait(duration)

		-- Fade out both
		local fadeOutFrame = fade(blackFrame, {BackgroundTransparency = 1}, 0.5)
		local fadeOutText = fade(textLabel, {TextTransparency = 1}, 0.5)
		fadeOutFrame.Completed:Wait()

		-- Hide transition UI, restore VN GUI
		textLabel.Visible = false
		blackFrame.Visible = false
		dialogueGui.Enabled = true

	elseif transitionType == "clickText" then
		clickCatcher.Visible = true
		for i, msg in messages do
			textLabel.Text = msg

			-- Fade in both
			local fadeInFrame = fade(blackFrame, {BackgroundTransparency = 0}, 0.5)
			local fadeInText = fade(textLabel, {TextTransparency = 0}, 0.5)
			fadeInFrame.Completed:Wait()

			-- Wait for click
			local proceed = false
			local conn
			conn = clickCatcher.MouseButton1Click:Connect(function()
				proceed = true
			end)
			repeat task.wait() until proceed
			conn:Disconnect()

			-- Fade out text only (keep blackFrame for next message or fade out at end)
			local fadeOutText = fade(textLabel, {TextTransparency = 1}, 0.5)
			fadeOutText.Completed:Wait()
		end

		-- Fade out blackFrame at the end
		local fadeOutFrame = fade(blackFrame, {BackgroundTransparency = 1}, 0.5)
		fadeOutFrame.Completed:Wait()

		dialogueGui.Enabled = true
		textLabel.Visible = false
		blackFrame.Visible = false
		clickCatcher.Visible = false

	elseif transitionType == "dialogueScreenIn" then
		-- Hide VN GUI first
		dialogueGui.Enabled = true
		RunService.RenderStepped:Wait()

		-- Reset visuals
		blackFrame.BackgroundTransparency = 1
		blackFrame.Visible = true
		textLabel.Visible = false
		clickCatcher.Visible = false

		-- Fade in black screen
		local tween = fade(blackFrame, {BackgroundTransparency = 0}, 0.5)
		tween.Completed:Wait()

		-- Show VN GUI after fade completes

	elseif transitionType == "dialogueScreenOut" then
		-- VN GUI should already be on here, we just want to fade out blackFrame
		textLabel.Visible = false
		clickCatcher.Visible = false
		dialogueGui.Enabled = true

		-- Make sure blackFrame is visible and opaque first
		blackFrame.Visible = true
		blackFrame.BackgroundTransparency = 0

		local tween = fade(blackFrame, {BackgroundTransparency = 1}, 0.5)
		tween.Completed:Wait()

		-- Hide blackFrame after it's fully transparent
		blackFrame.Visible = false

	elseif transitionType == "syncTeleport" then
		dialogueGui.Enabled = false
		textLabel.Visible = true
		clickCatcher.Visible = false

		blackFrame.Visible = true
		blackFrame.BackgroundTransparency = 1
		textLabel.TextTransparency = 1

		-- ? Use messages[1] for static text
		textLabel.Text = messages and messages[1] or ""

		-- Smooth fade in
		local fadeInFrame = fade(blackFrame, {BackgroundTransparency = 0}, 0.5)
		local fadeInText = fade(textLabel, {TextTransparency = 0}, 0.5)
		fadeInFrame.Completed:Wait()

		-- ?? Teleport AFTER fade-in
		if config.teleport then
			local player = Players.LocalPlayer
			local char = player.Character or player.CharacterAdded:Wait()
			local data = config.teleport

			if data.position and typeof(data.position) == "Vector3" then
				char:PivotTo(CFrame.new(data.position))
			elseif data.target and typeof(data.target) == "string" then
				local folder = ReplicatedStorage:FindFirstChild("TeleportLocations")
				local target = folder and folder:FindFirstChild(data.target)
				if target and target:IsA("BasePart") then
					char:PivotTo(target.CFrame)
				else
					warn("Teleport target not found:", data.target)
				end
			else
				warn("Invalid teleport config in transition")
			end

			if _G.ResetCameraFocus then
				_G.ResetCameraFocus()
			end
		end

		-- Wait if duration is set
		local duration = config.duration or 0
		if duration > 0 then
			task.wait(duration)
		end

		-- Smooth fade out
		local fadeOutFrame = fade(blackFrame, {BackgroundTransparency = 1}, 0.5)
		local fadeOutText = fade(textLabel, {TextTransparency = 1}, 0.5)
		fadeOutFrame.Completed:Wait()

		textLabel.Visible = false
		blackFrame.Visible = false
		dialogueGui.Enabled = _G.DialogueWillContinue or false
	end
end

-- Expose to _G
_G.PlayBlackTransition = playTransition

