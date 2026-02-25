local player = game.Players.LocalPlayer
if string.lower(player.Name) ~= "bramboraxl" then return end

local sg = Instance.new("ScreenGui")
sg.Name = "BramboraDebugGui"
sg.ResetOnSpawn = false
sg.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 320)
mainFrame.Position = UDim2.new(1, -230, 0.5, -155)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
mainFrame.ClipsDescendants = true 
mainFrame.Parent = sg
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundTransparency = 1
topBar.Parent = mainFrame

local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.Text = "??? BRAMBORA XL"
title.TextColor3 = Color3.fromRGB(255, 200, 50)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left

local toggleBtn = Instance.new("TextButton", topBar)
toggleBtn.Size = UDim2.new(0, 30, 0, 30)
toggleBtn.Position = UDim2.new(1, -35, 0, 5)
toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Text = "X"
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1, 0, 1, -40)
contentFrame.Position = UDim2.new(0, 0, 0, 40)
contentFrame.BackgroundTransparency = 1

local function createButton(name, text, yPos, color)
	local btn = Instance.new("TextButton", contentFrame)
	btn.Name = name
	btn.Size = UDim2.new(0.9, 0, 0, 35)
	btn.Position = UDim2.new(0.05, 0, 0, yPos)
	btn.Text = text
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	return btn
end

local btnCoins = createButton("BtnCoins", "+5000 Coins", 5, Color3.fromRGB(200, 150, 0))
local btnGems = createButton("BtnGems", "+5000 Gems", 45, Color3.fromRGB(150, 0, 200))

local selectedItem = ""
local dropdownHeader = createButton("DropdownHeader", "Vyber...", 85, Color3.fromRGB(60, 60, 60))
local btnSpawnAlly = createButton("BtnSpawnAlly", "Spawn Mùj Tým", 125, Color3.fromRGB(0, 150, 50))
local btnSpawnEnemy = createButton("BtnSpawnEnemy", "Spawn Enemy", 165, Color3.fromRGB(200, 50, 50))
local btnSpawnBuilding = createButton("BtnSpawnBuilding", "Spawn Budovu (Mnì)", 205, Color3.fromRGB(0, 100, 200))
local btnSpawnEnemyBuilding = createButton("BtnSpawnEnemyBuilding", "Spawn Budovu (Enemy)", 245, Color3.fromRGB(200, 100, 0))

local dropdownList = Instance.new("ScrollingFrame", contentFrame)
dropdownList.Size = UDim2.new(0.9, 0, 0, 150)
dropdownList.Position = UDim2.new(0.05, 0, 0, 120)
dropdownList.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
dropdownList.ZIndex = 10
dropdownList.Visible = false
Instance.new("UICorner", dropdownList).CornerRadius = UDim.new(0, 6)
local listLayout = Instance.new("UIListLayout", dropdownList)

local RS = game:GetService("ReplicatedStorage")
task.spawn(function()
	local armySystem = RS:WaitForChild("ArmySystem")
	local count = 0

	local function addItem(name, isBuilding)
		if count == 0 then
			selectedItem = name
			dropdownHeader.Text = (isBuilding and "[B] " or "[V] ") .. name
		end
		local option = Instance.new("TextButton", dropdownList)
		option.Size = UDim2.new(1, 0, 0, 30)
		option.Text = (isBuilding and "[B] " or "[V] ") .. name
		option.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
		option.TextColor3 = Color3.new(1, 1, 1)
		option.ZIndex = 11
		option.MouseButton1Click:Connect(function()
			selectedItem = name
			dropdownHeader.Text = option.Text
			dropdownList.Visible = false
		end)
		count = count + 1
	end

	for _, c in ipairs(armySystem:WaitForChild("Soldiers"):GetChildren()) do
		for _, s in ipairs(c:GetChildren()) do addItem(s.Name, false) end
	end
	for _, b in ipairs(armySystem:WaitForChild("Buildings"):GetChildren()) do
		addItem(b.Name, true)
	end
	dropdownList.CanvasSize = UDim2.new(0, 0, 0, count * 30)
end)

dropdownHeader.MouseButton1Click:Connect(function() dropdownList.Visible = not dropdownList.Visible end)

local minimized = false
toggleBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		mainFrame.Size = UDim2.new(0, 220, 0, 40)
		toggleBtn.Text = "+"
		dropdownList.Visible = false
	else
		mainFrame.Size = UDim2.new(0, 220, 0, 320)
		toggleBtn.Text = "X"
	end
end)

local debugEvent = RS:WaitForChild("DebugEvent")
local buyEvent = RS:WaitForChild("ArmySystem"):WaitForChild("BuyEvent")
local placeEvent = RS:WaitForChild("ArmySystem"):WaitForChild("PlaceEvent")

btnCoins.MouseButton1Click:Connect(function() debugEvent:FireServer("AddCoins", 5000) end)
btnGems.MouseButton1Click:Connect(function() debugEvent:FireServer("AddGems", 5000) end)

btnSpawnAlly.MouseButton1Click:Connect(function()
	if selectedItem ~= "" then buyEvent:FireServer("DEBUG_SPAWN_TEAM", selectedItem) end
end)
btnSpawnEnemy.MouseButton1Click:Connect(function()
	if selectedItem ~= "" then buyEvent:FireServer("SPAWN_ENEMY", selectedItem) end
end)

btnSpawnBuilding.MouseButton1Click:Connect(function()
	if selectedItem ~= "" and player.Character and player.Character.PrimaryPart then
		local pos = player.Character.PrimaryPart.CFrame * CFrame.new(0,0,-10)
		placeEvent:FireServer(selectedItem, pos, true) -- true = isDebug
	end
end)
btnSpawnEnemyBuilding.MouseButton1Click:Connect(function()
	if selectedItem ~= "" and player.Character and player.Character.PrimaryPart then
		local pos = player.Character.PrimaryPart.CFrame * CFrame.new(0,0,-10)
		debugEvent:FireServer("SpawnEnemyBuilding", selectedItem, pos)
	end
end)