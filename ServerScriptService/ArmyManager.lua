local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local armySystem = ReplicatedStorage:WaitForChild("ArmySystem")
local soldiersFolder = armySystem:WaitForChild("Soldiers")
local buyEvent = armySystem:WaitForChild("BuyEvent")
local commandEvent = armySystem:WaitForChild("CommandEvent")

local Armies = {}
local ArmyTargets = {}
local PlayerColors = {}

-- ==========================================
-- 1. NASTAVENÍ KOLIZÍ
-- ==========================================
pcall(function()
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:RegisterCollisionGroup("Soldiers")
end)

-- Vypnuté kolize (vojáci prochází skrz sebe i skrz hráèe, aby se nezasekli)
PhysicsService:CollisionGroupSetCollidable("Soldiers", "Soldiers", false)
PhysicsService:CollisionGroupSetCollidable("Soldiers", "Players", false)

-- ==========================================
-- 2. POMOCNÉ FUNKCE
-- ==========================================
local function getSoldierFolder(soldierName)
	local melee = soldiersFolder:FindFirstChild("MeleeUnit")
	local ranged = soldiersFolder:FindFirstChild("RangedUnit")

	if melee and melee:FindFirstChild(soldierName) then return melee[soldierName] end
	if ranged and ranged:FindFirstChild(soldierName) then return ranged[soldierName] end
	return nil
end

local function assignSoldierToPlayer(soldier, playerOrName)
	local name = typeof(playerOrName) == "Instance" and playerOrName.Name or playerOrName
	soldier:SetAttribute("Owner", name)

	if not Armies[name] then Armies[name] = {} end
	table.insert(Armies[name], soldier)

	local color = (typeof(playerOrName) == "Instance" and PlayerColors[playerOrName]) or Color3.new(1, 0, 0)

	for _, part in ipairs(soldier:GetDescendants()) do
		if part:IsA("BasePart") then 
			part.CollisionGroup = "Soldiers"

			-- Vypnutí fyzické kolize pro tìlo (aby se nezasekávali pøi animacích)
			if part.Name ~= "HumanoidRootPart" then
				part.CanCollide = false
				part.Massless = true
			end

			if part.Name == "Head" then
				part.Color = color 
			end
		end
	end

	local hrp = soldier:FindFirstChild("HumanoidRootPart")
	if hrp then hrp:SetNetworkOwner(nil) end
end

local function makeSoldierOrphan(soldier)
	soldier:SetAttribute("Owner", "Orphan")

	for _, part in ipairs(soldier:GetDescendants()) do
		if part:IsA("BasePart") then 
			part.CollisionGroup = "Default" 
			if part.Name == "Head" then
				part.Color = Color3.new(0.5, 0.5, 0.5) 
			end
		end
	end

	local hrp = soldier:FindFirstChild("HumanoidRootPart")
	if hrp then
		local connection
		connection = hrp.Touched:Connect(function(hit)
			if soldier:GetAttribute("Owner") ~= "Orphan" then
				if connection then connection:Disconnect() end
				return
			end

			local char = hit.Parent
			local newPlayer = Players:GetPlayerFromCharacter(char)

			if newPlayer and newPlayer:GetAttribute("InGame") then
				assignSoldierToPlayer(soldier, newPlayer)
				if connection then connection:Disconnect() end
			end
		end)
	end
end

local function getConcentricCirclePosition(center, index, spacing)
	local ring = 1
	local maxInRing = 8
	local previousCount = 0

	while index > previousCount + maxInRing do
		previousCount = previousCount + maxInRing
		ring = ring + 1
		maxInRing = ring * 8
	end

	local posInRing = index - previousCount
	local angle = ((math.pi * 2) / maxInRing) * posInRing
	local radius = ring * spacing 

	return center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- ==========================================
-- 3. NÁKUP A VYVOLÁVÁNÍ
-- ==========================================
buyEvent.OnServerEvent:Connect(function(player, command, extraParam)
	local isEnemySpawn = (command == "SPAWN_ENEMY")
	local isDebugSpawn = (command == "DEBUG_SPAWN_TEAM")

	if isDebugSpawn and string.lower(player.Name) ~= "bramboraxl" then return end
	if not isEnemySpawn and not isDebugSpawn and not player:GetAttribute("InGame") then return end

	local targetPlayer = isEnemySpawn and "Enemy" or player
	local realSoldierName = command 

	if isEnemySpawn or isDebugSpawn then
		realSoldierName = (extraParam and extraParam ~= "") and extraParam or "Knight"
	end

	local folder = getSoldierFolder(realSoldierName)
	if not folder then return end

	local configModule = folder:FindFirstChild("Config")
	local actualModel = folder:FindFirstChildOfClass("Model")
	if not configModule or not actualModel then return end

	local config = require(configModule)

	if not isEnemySpawn and not isDebugSpawn then
		local leaderstats = player:FindFirstChild("leaderstats")
		local currency = leaderstats and leaderstats:FindFirstChild(config.Currency)
		if not currency or currency.Value < config.Cost then return end
		currency.Value = currency.Value - config.Cost
	end

	local newSoldier = actualModel:Clone()
	newSoldier.Name = isEnemySpawn and "EnemyUnit" or realSoldierName
	newSoldier.Parent = workspace

	local hrp = newSoldier:FindFirstChild("HumanoidRootPart")
	local hum = newSoldier:FindFirstChildOfClass("Humanoid")

	local hpMultiplier = 1
	if not isEnemySpawn and not isDebugSpawn then
		local hpBoost = player:GetAttribute("Pet_HealthArmy") or 0
		hpMultiplier = 1 + (hpBoost / 100)
	end

	if hrp and hum then
		newSoldier.PrimaryPart = hrp
		hrp.Anchored = false
		hum.MaxHealth = config.Health * hpMultiplier
		hum.Health = hum.MaxHealth
		hum.WalkSpeed = config.WalkSpeed or 16
		hum.RequiresNeck = false
	end

	newSoldier:SetAttribute("LastAttack", tick())
	newSoldier:SetAttribute("TemplateName", realSoldierName) 

	assignSoldierToPlayer(newSoldier, targetPlayer)

	if isEnemySpawn then
		if player.Character and player.Character.PrimaryPart then
			newSoldier:PivotTo(player.Character.PrimaryPart.CFrame * CFrame.new(0, 0, -20))
		end
	elseif player.Character and player.Character.PrimaryPart then
		newSoldier:PivotTo(player.Character.PrimaryPart.CFrame * CFrame.new(0, 0, -5))
	end
end)

-- ==========================================
-- 4. BOJ A POHYB (UPRAVENO PRO ÚTOK NA HRÁÈE)
-- ==========================================
commandEvent.OnServerEvent:Connect(function(player, targetPosition)
	if player:GetAttribute("InGame") then
		ArmyTargets[player] = targetPosition
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for ownerName, soldiers in pairs(Armies) do
		local player = Players:FindFirstChild(ownerName)
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")

		-- Èištìní mrtvých vojákù
		for i = #soldiers, 1, -1 do
			if not soldiers[i] or not soldiers[i].Parent or soldiers[i]:FindFirstChildOfClass("Humanoid").Health <= 0 then
				table.remove(soldiers, i)
			end
		end

		local groupTarget = nil
		local isManualMode = false

		if player and ArmyTargets[player] ~= nil then
			groupTarget = ArmyTargets[player]
			isManualMode = true
		elseif root then
			groupTarget = root.Position
		end

		if groupTarget then
			for index, soldier in ipairs(soldiers) do
				local sHum = soldier:FindFirstChildOfClass("Humanoid")
				local sRoot = soldier.PrimaryPart
				if not sHum or not sRoot then continue end

				local f = getSoldierFolder(soldier:GetAttribute("TemplateName"))
				if not f then continue end
				local config = require(f:FindFirstChild("Config"))

				local targetEnemy = nil
				local shortestDist = 50 -- Maximální "zorné pole" pro hledání cílù

				local canAttack = isManualMode or ownerName == "Enemy"

				if canAttack then
					-- 1. HLEDÁNÍ CIZÍCH VOJÁKÙ
					for otherOwner, otherSoldiers in pairs(Armies) do
						if otherOwner ~= ownerName then
							for _, enemy in ipairs(otherSoldiers) do
								local eRoot = enemy.PrimaryPart
								local eHum = enemy:FindFirstChildOfClass("Humanoid")
								if eRoot and eHum and eHum.Health > 0 then
									local d = (sRoot.Position - eRoot.Position).Magnitude
									if d < shortestDist then
										shortestDist = d
										targetEnemy = enemy
									end
								end
							end
						end
					end

					-- 2. NOVÉ: POKUD JSEM ENEMY, HLEDÁM I HRÁÈE
					if ownerName == "Enemy" then
						for _, p in ipairs(Players:GetPlayers()) do
							-- Hledáme jen hráèe, kteøí jsou "InGame" a mají postavu
							if p:GetAttribute("InGame") and p.Character then
								local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
								local pHum = p.Character:FindFirstChild("Humanoid")

								if pRoot and pHum and pHum.Health > 0 then
									local d = (sRoot.Position - pRoot.Position).Magnitude
									-- Pokud je hráè blíž než aktuální cíl (voják), pøepneme cíl na hráèe
									if d < shortestDist then
										shortestDist = d
										targetEnemy = p.Character
									end
								end
							end
						end
					end
				end

				-- ÚTOK NEBO POHYB
				if targetEnemy and shortestDist <= config.AttackRange then
					-- Zastavíme pohyb
					sHum:MoveTo(sRoot.Position) 

					-- Útok
					if tick() - soldier:GetAttribute("LastAttack") >= config.AttackSpeed then
						soldier:SetAttribute("LastAttack", tick())

						local dmgMultiplier = 1
						if player then
							local dmgBoost = player:GetAttribute("Pet_DamageArmy") or 0
							dmgMultiplier = 1 + (dmgBoost / 100)
						end

						local finalDamage = config.Damage * dmgMultiplier

						-- Tady to funguje pro vojáky i hráèe, protože obojí má Humanoid
						local enemyHum = targetEnemy:FindFirstChildOfClass("Humanoid")
						if enemyHum then
							enemyHum:TakeDamage(finalDamage)
						end

						if config.Type == "Ranged" then
							local part = soldier:FindFirstChild("ParticlePart")
							if part and part:FindFirstChildOfClass("ParticleEmitter") then
								part:FindFirstChildOfClass("ParticleEmitter"):Emit(1)
							end
						end
					end
				else
					-- Pokud nemáme cíl na útok, jdeme za formací
					local spacing = (isManualMode and ownerName ~= "Enemy") and 3.5 or 6
					local finalPos = getConcentricCirclePosition(groupTarget, index, spacing)
					sHum:MoveTo(finalPos)
				end
			end
		end
	end
end)

-- ==========================================
-- 5. PØIPOJENÍ A ODPOJENÍ
-- ==========================================
Players.PlayerAdded:Connect(function(player)
	PlayerColors[player] = Color3.fromHSV(math.random(), 0.7, 0.8)

	player.CharacterAdded:Connect(function(char)
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CollisionGroup = "Players" end
		end

		char.DescendantAdded:Connect(function(part)
			if part:IsA("BasePart") then part.CollisionGroup = "Players" end
		end)

		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			if Armies[player.Name] then
				for _, soldier in ipairs(Armies[player.Name]) do
					if soldier and soldier.Parent then
						makeSoldierOrphan(soldier)
					end
				end
				Armies[player.Name] = nil
				ArmyTargets[player] = nil
			end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if Armies[player.Name] then
		for _, soldier in ipairs(Armies[player.Name]) do
			if soldier then soldier:Destroy() end
		end
		Armies[player.Name] = nil
		ArmyTargets[player] = nil
	end
end)