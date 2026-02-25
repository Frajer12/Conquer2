local ReplicatedStorage = game:GetService("ReplicatedStorage")

local debugEvent = ReplicatedStorage:FindFirstChild("DebugEvent") or Instance.new("RemoteEvent")
debugEvent.Name = "DebugEvent"
debugEvent.Parent = ReplicatedStorage

-- Tabulka povolených adminù (všechna jména musí být malými písmeny)
local allowedAdmins = {
	["bramboraxl"] = true,
	["vladakral1"] = true
}

debugEvent.OnServerEvent:Connect(function(player, action, value, extraParam)
	-- Ochrana na serveru: zkontroluje tabulku adminù
	local playerName = string.lower(player.Name)
	if not allowedAdmins[playerName] then 
		warn("Hráè " .. player.Name .. " se pokusil použít debug menu na serveru!")
		return 
	end

	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	if action == "AddCoins" then
		local coins = stats:FindFirstChild("Coins")
		if coins then coins.Value = coins.Value + value end
	elseif action == "AddGems" then
		local gems = stats:FindFirstChild("Gems")
		if gems then gems.Value = gems.Value + value end
	elseif action == "SpawnEnemyBuilding" then
		local buildingName = value
		local targetCFrame = extraParam

		local bFolder = ReplicatedStorage.ArmySystem.Buildings:FindFirstChild(buildingName)
		local actualModel = bFolder and bFolder:FindFirstChildOfClass("Model")

		if bFolder and actualModel then
			local newBuilding = actualModel:Clone()
			newBuilding.Name = buildingName
			newBuilding:SetAttribute("Owner", "Enemy")

			local config = require(bFolder.Config)
			newBuilding:SetAttribute("BuildingType", config.Type)
			newBuilding:SetAttribute("LastAction", tick())

			if config.Type == "Defense" then 
				newBuilding:SetAttribute("Attack", config.Attack)
				newBuilding:SetAttribute("AttackRange", config.AttackRange)
				newBuilding:SetAttribute("AttackSpeed", config.AttackSpeed)
			end

			local hum = newBuilding:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.MaxHealth = config.Health
				hum.Health = config.Health
				hum.Died:Connect(function() task.wait(0.5); newBuilding:Destroy() end)
			end

			for _, part in ipairs(newBuilding:GetDescendants()) do
				if part:IsA("BasePart") then part.Anchored = true; part.CanCollide = true end
			end

			newBuilding:PivotTo(targetCFrame)
			newBuilding.Parent = workspace:WaitForChild("ActiveBuildings")
		end
	end
end)