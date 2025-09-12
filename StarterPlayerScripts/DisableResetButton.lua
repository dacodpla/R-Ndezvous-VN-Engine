local StarterGui = game:GetService("StarterGui")

local function disableReset()
	local success = false
	while not success do
		success = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if not success then
			task.wait(1)
		end
	end
end

disableReset()

