local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local hotkeyMap = {}

local armySystem = ReplicatedStorage:WaitForChild("ArmySystem")
local soldiersFolder = armySystem:WaitForChild("Soldiers")
local buildingsFolder = armySystem:WaitForChild("Buildings")
local buyEvent = armySystem:WaitForChild("BuyEvent")
local placeEvent = armySystem:WaitForChild("PlaceEvent")

local playerGui = player:WaitForChild("PlayerGui")
local oldShop = playerGui:FindFirstChild("ArmyShopGui")
if oldShop then oldShop:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ArmyShopGui"
screenGui.ResetOnSpawn = false 
screenGui.Parent = playerGui

local armyShopFrame = Instance.new("Frame")
armyShopFrame.Name = "ArmyShopContainer"
armyShopFrame.Size = UDim2.new(0.8, 0, 0, 120)
armyShopFrame.Position = UDim2.new(0.1, 0, 1, -140) 
armyShopFrame.BackgroundTransparency = 1
armyShopFrame.Visible = false 
armyShopFrame.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 15)
layout.Parent = armyShopFrame

-- ==========================================
-- SYSTÉM STAVÌNÍ BUDOV A CANCEL TLAÈÍTKO
-- ==========================================
local isPlacing = false
local previewModel = nil
local currentBuildingName = nil
local canPlace = false

local gemsGui = playerGui:WaitForChild("Gems")
local cancelBtn = gemsGui:WaitForChild("Cancel")
cancelBtn.Visible = false -- Tlaèítko schováme, dokud nestavíme

local function stopPlacement()
	isPlacing = false
	currentBuildingName = nil
	player:SetAttribute("IsPlacing", false) 
	mouse.TargetFilter = nil 
	cancelBtn.Visible = false -- Schová Cancel tlaèítko

	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
end

-- Napojení Cancel tlaèítka v GUI
cancelBtn.MouseButton1Click:Connect(function()
	if isPlacing then stopPlacement() end
end)

local function startPlacement(buildingName)
	if isPlacing then stopPlacement() end
	local bFolder = buildingsFolder:FindFirstChild(buildingName)
	if not bFolder then return end

	local model = bFolder:FindFirstChildOfClass("Model")
	if not model or not model.PrimaryPart then 
		warn("CHYBA: Model budovy " .. buildingName .. " nemá nastavený PrimaryPart!")
		return 
	end

	previewModel = model:Clone()
	for _, part in ipairs(previewModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Transparency = 0.5
			if part.Name == "HumanoidRootPart" then part.Transparency = 1 end
		end
	end

	previewModel.Parent = workspace
	mouse.TargetFilter = previewModel 
	player:SetAttribute("IsPlacing", true)
	cancelBtn.Visible = true -- Ukáže Cancel tlaèítko, když zaèneme stavìt

	currentBuildingName = buildingName
	isPlacing = true
end

-- Aktualizace preview (Zamknuto na osu Y)
RunService.RenderStepped:Connect(function()
	if isPlacing and previewModel and previewModel.PrimaryPart then
		if not mouse.Hit then return end

		-- ZAMKNUTÍ VÝŠKY: Zjistíme úroveò zemì (Baseplatu)
		local baseplate = workspace:FindFirstChild("Baseplate")
		local groundY = 0
		if baseplate then
			groundY = baseplate.Position.Y + (baseplate.Size.Y / 2)
		end

		-- Myš dává X a Z, výšku držíme natvrdo pøesnì na groundY
		local hitPos = mouse.Hit.Position
		local targetPos = Vector3.new(hitPos.X, groundY, hitPos.Z)

		local targetCFrame = CFrame.new(targetPos + Vector3.new(0, previewModel.PrimaryPart.Size.Y/2, 0))
		previewModel:PivotTo(targetCFrame)

		-- Detekce kolizí s jinými budovami/vojáky
		local overlapParams = OverlapParams.new()
		overlapParams.FilterDescendantsInstances = {previewModel, player.Character}
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude

		local partsInBox = workspace:GetPartsInPart(previewModel.PrimaryPart, overlapParams)

		canPlace = true
		for _, p in ipairs(partsInBox) do
			if p.CanCollide and p.Name ~= "Baseplate" and p.Name ~= "Terrain" then
				canPlace = false
				break
			end
		end

		local color = canPlace and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
		for _, part in ipairs(previewModel:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Color = color
			end
		end
	end
end)

local isBuying = false

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	-- 1. Pokud zrovna stavíme budovu
	if isPlacing then
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			-- Položení budovy levým tlaèítkem
			if canPlace and previewModel and previewModel.PrimaryPart then
				placeEvent:FireServer(currentBuildingName, previewModel.PrimaryPart.CFrame)
				stopPlacement()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Zrušení pravým tlaèítkem myši
			stopPlacement() 
		elseif input.KeyCode == Enum.KeyCode.Q then
			-- Zrušení klávesou Q
			stopPlacement()
		end

		-- Pokud jsme v režimu stavìní, chceme ignorovat klávesy pro nákup dalších jednotek
		return 
	end

	-- 2. Pokud nestavíme, øešíme klávesové zkratky pro shop
	if not player:GetAttribute("InGame") then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	local item = hotkeyMap[input.KeyCode]
	if item then
		if item.IsBuilding then
			startPlacement(item.Name)
		else
			if isBuying then return end
			isBuying = true
			buyEvent:FireServer(item.Name)
			task.delay(0.2, function() isBuying = false end)
		end
	end
end)

-- ==========================================
-- GENEROVÁNÍ TLAÈÍTEK
-- ==========================================
local function createButton(folder, isBuilding)
	local configModule = folder:FindFirstChild("Config")
	local actualModel = folder:FindFirstChildOfClass("Model")
	if not configModule or not actualModel then return end

	local config = require(configModule)
	hotkeyMap[config.Hotkey] = {Name = folder.Name, IsBuilding = isBuilding}

	local btn = Instance.new("TextButton")
	btn.Name = folder.Name .. "_Btn"
	btn.Size = UDim2.new(0, 100, 0, 120)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	btn.Text = ""
	btn.AutoButtonColor = false 
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0.1, 0)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 200, 200)
	stroke.Thickness = 2
	stroke.Parent = btn

	local vpf = Instance.new("ViewportFrame")
	vpf.Size = UDim2.new(1, 0, 0.6, 0)
	vpf.BackgroundTransparency = 1
	vpf.Parent = btn

	local clone = actualModel:Clone()
	for _, v in ipairs(clone:GetDescendants()) do
		if v:IsA("Script") or v:IsA("LocalScript") then v:Destroy() end
	end
	if not clone.PrimaryPart then clone.PrimaryPart = clone:FindFirstChild("HumanoidRootPart") end
	if clone.PrimaryPart then clone:PivotTo(CFrame.new(0, 0, 0)) end
	clone.Parent = vpf

	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.new(Vector3.new(3, 3, 6), Vector3.new(0, 0.5, 0))
	vpf.CurrentCamera = cam

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.2, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.6, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = config.Name
	nameLabel.TextColor3 = isBuilding and Color3.fromRGB(150, 200, 255) or Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.Parent = btn

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, 0, 0.2, 0)
	costLabel.Position = UDim2.new(0, 0, 0.8, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = config.Cost .. " [" .. config.Hotkey.Name .. "]"
	costLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	costLabel.Font = Enum.Font.Gotham
	costLabel.TextScaled = true
	costLabel.Parent = btn

	local uiScale = Instance.new("UIScale", btn)

	btn.MouseEnter:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.1}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(255, 255, 255)}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.2), {Scale = 1.0}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(200, 200, 200)}):Play()
	end)

	btn.MouseButton1Click:Connect(function()
		if player:GetAttribute("InGame") then
			if isBuilding then
				startPlacement(folder.Name)
			else
				buyEvent:FireServer(folder.Name)
			end
		end
	end)
	btn.Parent = armyShopFrame
end

-- Vytvoøení vojákù
for _, category in ipairs(soldiersFolder:GetChildren()) do
	for _, soldier in ipairs(category:GetChildren()) do
		createButton(soldier, false)
	end
end
-- Vytvoøení budov
for _, building in ipairs(buildingsFolder:GetChildren()) do
	createButton(building, true)
end

local function updateShopVisibility()
	armyShopFrame.Visible = player:GetAttribute("InGame") or false
	if not armyShopFrame.Visible then stopPlacement() end
end

updateShopVisibility()
player:GetAttributeChangedSignal("InGame"):Connect(updateShopVisibility)