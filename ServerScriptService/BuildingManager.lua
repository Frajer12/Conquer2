local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local armySystem = ReplicatedStorage:WaitForChild("ArmySystem")
local buildingsFolder = armySystem:WaitForChild("Buildings")
local placeEvent = armySystem:WaitForChild("PlaceEvent")

local activeBuildingsFolder = workspace:WaitForChild("ActiveBuildings")

-- Základní kapacita populace
local BASE_POPULATION = 10

local function updatePlayerPopulation(player)
	local maxPop = BASE_POPULATION
	for _, b in ipairs(activeBuildingsFolder:GetChildren()) do
		if b:GetAttribute("Owner") == player.Name then
			local bType = b:GetAttribute("BuildingType")
			if bType == "People" then
				maxPop = maxPop + b:GetAttribute("PopulationVal")
			end
		end
	end
	player:SetAttribute("MaxPopulation", maxPop)
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("CurrentPopulation", 0)
	player:SetAttribute("MaxPopulation", BASE_POPULATION)
end)

placeEvent.OnServerEvent:Connect(function(player, buildingName, targetCFrame, isDebug)
	if not player:GetAttribute("InGame") and not isDebug then return end

	local bFolder = buildingsFolder:FindFirstChild(buildingName)
	if not bFolder then return end

	local config = require(bFolder.Config)
	local model = bFolder:FindFirstChildOfClass("Model")
	if not model then return end

	-- Odeètení penìz
	if not isDebug then
		local leaderstats = player:FindFirstChild("leaderstats")
		local currency = leaderstats and leaderstats:FindFirstChild(config.Currency)
		if not currency or currency.Value < config.Cost then return end
		currency.Value = currency.Value - config.Cost
	end

	-- Spawnování
	local newBuilding = model:Clone()
	newBuilding.Name = buildingName
	newBuilding:SetAttribute("Owner", player.Name)
	newBuilding:SetAttribute("BuildingType", config.Type)
	newBuilding:SetAttribute("LastAction", tick())

	if config.Type == "People" then newBuilding:SetAttribute("PopulationVal", config.Population) end
	if config.Type == "Defense" then 
		newBuilding:SetAttribute("Attack", config.Attack)
		newBuilding:SetAttribute("AttackRange", config.AttackRange)
		newBuilding:SetAttribute("AttackSpeed", config.AttackSpeed)
	end
	if config.Type == "Mine" then
		newBuilding:SetAttribute("CoinsPer30", config.CoinsPer30Seconds)
	end

	local hum = newBuilding:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = config.Health
		hum.Health = config.Health
		hum.Died:Connect(function()
			task.wait(0.5)
			newBuilding:Destroy()
			updatePlayerPopulation(player)
		end)
	end

	-- Ukotvení budovy (aby nespadla)
	for _, part in ipairs(newBuilding:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = true
		end
	end

	newBuilding:PivotTo(targetCFrame)
	newBuilding.Parent = activeBuildingsFolder
	updatePlayerPopulation(player)
end)

-- Loop pro doly a obranu
RunService.Heartbeat:Connect(function(dt)
	local now = tick()
	for _, building in ipairs(activeBuildingsFolder:GetChildren()) do
		local ownerName = building:GetAttribute("Owner")
		local bType = building:GetAttribute("BuildingType")
		local lastAction = building:GetAttribute("LastAction") or now
		local root = building.PrimaryPart or building:FindFirstChild("HumanoidRootPart")

		if bType == "Mine" then
			if now - lastAction >= 30 then
				building:SetAttribute("LastAction", now)
				local player = Players:FindFirstChild(ownerName)
				if player then
					local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
					if coins then coins.Value = coins.Value + building:GetAttribute("CoinsPer30") end
				end
			end
		elseif bType == "Defense" and root then
			local aSpeed = building:GetAttribute("AttackSpeed")
			if now - lastAction >= aSpeed then
				-- Hledání cíle (nepøátelští vojáci)
				local aRange = building:GetAttribute("AttackRange")
				local target, minDist = nil, aRange

				-- Najdeme nejbližšího nepøítele
				for _, enemyPlayer in ipairs(Players:GetPlayers()) do
					if enemyPlayer.Name ~= ownerName then
						-- Hledáme v active Armies (pokud to jde, zde zjednodušenì pøes workspace)
						for _, char in ipairs(workspace:GetChildren()) do
							if char:GetAttribute("Owner") and char:GetAttribute("Owner") ~= ownerName and char:GetAttribute("Owner") ~= "Orphan" then
								local eRoot = char:FindFirstChild("HumanoidRootPart")
								local eHum = char:FindFirstChildOfClass("Humanoid")
								if eRoot and eHum and eHum.Health > 0 then
									local dist = (eRoot.Position - root.Position).Magnitude
									if dist <= minDist then
										minDist = dist
										target = eHum
									end
								end
							end
						end
					end
				end

				if target then
					building:SetAttribute("LastAction", now)
					target:TakeDamage(building:GetAttribute("Attack"))
					local part = building:FindFirstChild("ParticlePart")
					if part and part:FindFirstChildOfClass("ParticleEmitter") then
						part:FindFirstChildOfClass("ParticleEmitter"):Emit(1)
					end
				end
			end
		end
	end
end)