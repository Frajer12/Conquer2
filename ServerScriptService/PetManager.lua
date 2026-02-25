local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local PetStore = DataStoreService:GetDataStore("PlayerPetsData_V2")
local armySystem = ReplicatedStorage:WaitForChild("ArmySystem")

-- Tvoje specifická složka PetEvents a eventy
local petEvents = armySystem:WaitForChild("PetEvents")
local buyChestEvent = petEvents:WaitForChild("BuyChest")
local sellPetEvent = petEvents:WaitForChild("SellPet")
local toggleEquipEvent = petEvents:WaitForChild("ToggleEquip")

local shopFolder = armySystem:WaitForChild("Shop")

local MAX_PETS = 50
local MAX_EQUIPPED = 3

local PlayerPets = {}

local function generateUID()
	return HttpService:GenerateGUID(false)
end

-- PØEPOÈÍTÁNÍ BOOSTÙ
local function updatePlayerBoosts(player)
	local aDmg, aHp, bDmg, bHp, coinB = 0, 0, 0, 0, 0
	local ownedPets = PlayerPets[player.UserId] or {}

	for _, pet in ipairs(ownedPets) do
		if pet.Equipped then
			local chestFolder = shopFolder:FindFirstChild("Daily")
			if chestFolder then
				local petFolder = chestFolder:FindFirstChild(pet.Name)
				if petFolder and petFolder:FindFirstChild("Config") then
					local config = require(petFolder.Config)
					aDmg += (config.DamageArmy or 0)
					aHp += (config.HealthArmy or 0)
					bDmg += (config.DamageBuilding or 0)
					bHp += (config.HealthBuilding or 0)
					coinB += (config.CoinBoost or 0)
				end
			end
		end
	end

	player:SetAttribute("Pet_DamageArmy", aDmg)
	player:SetAttribute("Pet_HealthArmy", aHp)
	player:SetAttribute("Pet_DamageBuilding", bDmg)
	player:SetAttribute("Pet_HealthBuilding", bHp)
	player:SetAttribute("Pet_CoinBoost", coinB)
end

-- SPAWNOVÁNÍ FYZICKÝCH PETÙ
local function spawnPhysicalPets(player)
	local char = player.Character
	if not char or not char.PrimaryPart then return end

	local oldFolder = char:FindFirstChild("PhysicalPets")
	if oldFolder then oldFolder:Destroy() end

	local petFolder = Instance.new("Folder")
	petFolder.Name = "PhysicalPets"
	petFolder.Parent = char

	local equippedCount = 0
	for _, pet in ipairs(PlayerPets[player.UserId] or {}) do
		if pet.Equipped then
			equippedCount += 1
			local modelToClone = nil

			local chestFolder = shopFolder:FindFirstChild("Daily")
			if chestFolder then
				local pf = chestFolder:FindFirstChild(pet.Name)
				if pf and pf:FindFirstChildOfClass("Model") then
					modelToClone = pf:FindFirstChildOfClass("Model")
				end
			end

			if modelToClone then
				local clone = modelToClone:Clone()
				clone.Parent = petFolder
				local root = clone.PrimaryPart or clone:FindFirstChild("HumanoidRootPart")
				if not root then continue end

				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
						part.Massless = true
						part.Anchored = false
					end
				end

				local angle = (math.pi * 2 / MAX_EQUIPPED) * equippedCount
				local offset = Vector3.new(math.cos(angle) * 4, 2, math.sin(angle) * 4)

				local attachment0 = Instance.new("Attachment", root)
				local attachment1 = Instance.new("Attachment", char.PrimaryPart)
				attachment1.Position = offset

				local alignPos = Instance.new("AlignPosition", root)
				alignPos.Attachment0 = attachment0
				alignPos.Attachment1 = attachment1
				alignPos.RigidityEnabled = true
				alignPos.Responsiveness = 50

				local alignOri = Instance.new("AlignOrientation", root)
				alignOri.Attachment0 = attachment0
				alignOri.Attachment1 = attachment1
				alignOri.RigidityEnabled = true
			end
		end
	end
end

-- ==========================================
-- EVENTY Z KLIENTA
-- ==========================================

-- 1. KUPOVÁNÍ BEDNY
buyChestEvent.OnServerEvent:Connect(function(player, chestName)
	local ownedPets = PlayerPets[player.UserId] or {}
	local chestFolder = shopFolder:FindFirstChild(chestName)
	if not chestFolder then return end

	local confScript = chestFolder:FindFirstChild("Config")
	local cost = 100
	if confScript then cost = require(confScript).Cost or 100 end

	local leaderstats = player:FindFirstChild("leaderstats")
	local gems = leaderstats and leaderstats:FindFirstChild("Gems")

	if not gems or gems.Value < cost then return end
	if #ownedPets >= MAX_PETS then return end

	local totalChance = 0
	local petList = {}
	for _, child in ipairs(chestFolder:GetChildren()) do
		if child:IsA("Folder") and child:FindFirstChild("Config") then
			local conf = require(child.Config)
			totalChance += (conf.Chance or 0)
			table.insert(petList, {Name = child.Name, Chance = (conf.Chance or 0)})
		end
	end

	if totalChance == 0 then return end
	local roll = math.random() * totalChance
	local current = 0
	local wonPetName = nil

	for _, p in ipairs(petList) do
		current += p.Chance
		if roll <= current then
			wonPetName = p.Name
			break
		end
	end

	if wonPetName then
		gems.Value -= cost
		table.insert(ownedPets, {UID = generateUID(), Name = wonPetName, Equipped = false})
		PlayerPets[player.UserId] = ownedPets
		buyChestEvent:FireClient(player, "ChestOpened", wonPetName, ownedPets)
	end
end)

-- 2. EQUIP/UNEQUIP
toggleEquipEvent.OnServerEvent:Connect(function(player, uid)
	local ownedPets = PlayerPets[player.UserId] or {}
	local petData = nil
	local equippedCount = 0

	for _, p in ipairs(ownedPets) do
		if p.Equipped then equippedCount += 1 end
		if p.UID == uid then petData = p end
	end

	if petData then
		if petData.Equipped then
			petData.Equipped = false
		else
			if equippedCount < MAX_EQUIPPED then
				petData.Equipped = true
			end
		end
		updatePlayerBoosts(player)
		spawnPhysicalPets(player)
		toggleEquipEvent:FireClient(player, ownedPets)
	end
end)

-- 3. PRODEJ (SELL)
sellPetEvent.OnServerEvent:Connect(function(player, uid)
	local ownedPets = PlayerPets[player.UserId] or {}
	for i, p in ipairs(ownedPets) do
		if p.UID == uid then
			local sellValue = 10
			local chestFolder = shopFolder:FindFirstChild("Daily")
			if chestFolder then
				local pf = chestFolder:FindFirstChild(p.Name)
				if pf and pf:FindFirstChild("Config") then
					sellValue = require(pf.Config).SellCost or 10
				end
			end

			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats and leaderstats:FindFirstChild("Coins") then
				leaderstats.Coins.Value += sellValue
			end

			table.remove(ownedPets, i)
			updatePlayerBoosts(player)
			spawnPhysicalPets(player)
			sellPetEvent:FireClient(player, ownedPets)
			break
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	local data = nil
	pcall(function() data = PetStore:GetAsync(player.UserId) end)
	PlayerPets[player.UserId] = data or {}

	updatePlayerBoosts(player)

	player.CharacterAdded:Connect(function()
		task.wait(1)
		spawnPhysicalPets(player)
	end)

	task.wait(2)
	-- Synchronizace po naètení
	buyChestEvent:FireClient(player, "SyncPets", PlayerPets[player.UserId])
end)

Players.PlayerRemoving:Connect(function(player)
	if PlayerPets[player.UserId] then
		pcall(function() PetStore:SetAsync(player.UserId, PlayerPets[player.UserId]) end)
		PlayerPets[player.UserId] = nil
	end
end)