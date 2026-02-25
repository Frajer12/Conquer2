local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local armySystem = ReplicatedStorage:WaitForChild("ArmySystem")
local buyEvent = armySystem:WaitForChild("BuyEvent")
local commandEvent = armySystem:WaitForChild("CommandEvent")

local isHolding = false

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not player:GetAttribute("InGame") then return end
	-- OPRAVA: Zabráníme pohybu vojákù, pokud zrovna hráè staví budovu
	if player:GetAttribute("IsPlacing") then return end 

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isHolding = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isHolding = false
		if player:GetAttribute("InGame") then commandEvent:FireServer(nil) end
	end
end)

RunService.RenderStepped:Connect(function()
	if isHolding and mouse.Hit and player:GetAttribute("InGame") and not player:GetAttribute("IsPlacing") then
		commandEvent:FireServer(mouse.Hit.Position)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.3) 

		if not player:GetAttribute("InGame") or player:GetAttribute("IsPlacing") then
			isHolding = false
			continue
		end

		if isHolding and UserInputService.MouseEnabled then
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				isHolding = false
				commandEvent:FireServer(nil)
			end
		end

		if not isHolding then
			commandEvent:FireServer(nil)
		end
	end
end)