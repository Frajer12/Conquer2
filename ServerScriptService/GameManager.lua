local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local GemStore = DataStoreService:GetDataStore("PlayerGemsData_V1")
local armySystem = ReplicatedStorage:WaitForChild("ArmySystem")
local playEvent = armySystem:WaitForChild("PlayEvent")

local function saveGems(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Gems") then
		pcall(function() GemStore:SetAsync(player.UserId, leaderstats.Gems.Value) end)
	end
end

local function setupCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then
		hum.Died:Connect(function()
			player:SetAttribute("InGame", false)
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats and leaderstats:FindFirstChild("Coins") then
				leaderstats.Coins:Destroy()
				local pGui = player:FindFirstChild("PlayerGui")
				if pGui and pGui:FindFirstChild("Gems") and pGui.Gems:FindFirstChild("Coins") then
					pGui.Gems.Coins.Text = "0"
				end
			end
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("InGame", false)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = 0
	gems.Parent = leaderstats

	local success, savedGems = pcall(function() return GemStore:GetAsync(player.UserId) end)
	if success and savedGems then gems.Value = savedGems end

	local playerGui = player:WaitForChild("PlayerGui")
	local gemsGui = playerGui:WaitForChild("Gems")
	if gemsGui:IsA("ScreenGui") then gemsGui.ResetOnSpawn = false end

	local gemsText = gemsGui:WaitForChild("Gems")
	gemsText.Text = tostring(gems.Value)
	gems.Changed:Connect(function() gemsText.Text = tostring(gems.Value) end)

	local coinsText = gemsGui:WaitForChild("Coins")
	coinsText.Text = "0" 

	leaderstats.ChildAdded:Connect(function(child)
		if child.Name == "Coins" then
			coinsText.Text = tostring(child.Value)
			child.Changed:Connect(function() coinsText.Text = tostring(child.Value) end)
		end
	end)

	-- POPULACE UI UPDATE
	local popText = gemsGui:WaitForChild("Population")
	local function updatePopUI()
		local cur = player:GetAttribute("CurrentPopulation") or 0
		local max = player:GetAttribute("MaxPopulation") or 10
		popText.Text = cur .. " / " .. max
	end
	player:GetAttributeChangedSignal("CurrentPopulation"):Connect(updatePopUI)
	player:GetAttributeChangedSignal("MaxPopulation"):Connect(updatePopUI)
	updatePopUI()

	task.spawn(function()
		while task.wait(120) do
			if player and player.Parent then saveGems(player) else break end
		end
	end)

	if player.Character then setupCharacter(player, player.Character) end
	player.CharacterAdded:Connect(function(char) setupCharacter(player, char) end)
end)

Players.PlayerRemoving:Connect(function(player) saveGems(player) end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do saveGems(p) end
	task.wait(2)
end)

playEvent.OnServerEvent:Connect(function(player)
	if player:GetAttribute("InGame") then return end
	player:SetAttribute("InGame", true)
	-- Reset populace pøi nové høe
	player:SetAttribute("CurrentPopulation", 0)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins") or Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = 500
		coins.Parent = leaderstats
	end

	local arenaSpawn = workspace:FindFirstChild("ArenaSpawn")
	if arenaSpawn and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character:PivotTo(arenaSpawn.CFrame * CFrame.new(0, 3, 0))
	end
end)