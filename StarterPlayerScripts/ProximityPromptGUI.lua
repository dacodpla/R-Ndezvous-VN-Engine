local ProximityPromptService = game:GetService("ProximityPromptService")
local workspace = game:GetService("Workspace")

-- Helper: checks if a prompt belongs to a model with a Humanoid
local function isHumanoidPrompt(prompt)
	-- Walk up the hierarchy to find the model
	local model = prompt:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return true
	end
	return false
end

-- Create a billboard template for a prompt
local function createBillboard(prompt, head)
	-- Disable Roblox's default UI for this prompt
	prompt.Style = Enum.ProximityPromptStyle.Custom

	-- Avoid duplicates
	if head:FindFirstChild("CustomBillboardPrompt") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CustomBillboardPrompt"
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 150, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	local function updateLabel()
		-- If ObjectText is set on the prompt, use it, otherwise decide between Talk/Interact
		if prompt.ObjectText and prompt.ObjectText ~= "" then
			label.Text = prompt.ObjectText
		else
			if isHumanoidPrompt(prompt) then
				label.Text = "'E' to Talk"
			else
				label.Text = "'E' to Interact"
			end
		end
	end

	-- Show/hide billboard when prompt shows/hides
	prompt.PromptShown:Connect(function()
		updateLabel()
		billboard.Enabled = true
	end)
	prompt.PromptHidden:Connect(function()
		billboard.Enabled = false
	end)

	-- Cleanup if prompt or head is removed
	prompt.AncestryChanged:Connect(function(_, parent)
		if not parent and billboard then billboard:Destroy() end
	end)
end

-- Scan a single model for prompts
local function scanModel(model)
	if not model:IsA("Model") then return end
	local head = model:FindFirstChild("Head")
	if not head then return end

	for _, prompt in ipairs(model:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			createBillboard(prompt, head)
		end
	end
end

-- Initial scan of all workspace models
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("Model") then
		scanModel(descendant)
	end
end

-- Watch for new models or prompts being added dynamically
workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("ProximityPrompt") then
		-- Find the nearest Head to attach the billboard
		local model = obj:FindFirstAncestorOfClass("Model")
		if model then
			local head = model:FindFirstChild("Head") or obj.Parent:FindFirstChild("Head")
			if head then
				createBillboard(obj, head)
			end
		end
	elseif obj:IsA("Model") then
		scanModel(obj)
	end
end)
