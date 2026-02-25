local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

print("[DEBUG] === MAIN MENU SCRIPT START ===")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ==========================================
-- 1. VYTVORENIE »IERNEJ OBRAZOVKY A LOADINGU
-- ==========================================
print("[DEBUG] Vytv·ram Black Screen a Loading Label...")
local playerGui = player:WaitForChild("PlayerGui")
local fadeGui = playerGui:FindFirstChild("BlackScreenTransitionGui")
if not fadeGui then
	fadeGui = Instance.new("ScreenGui")
	fadeGui.Name = "BlackScreenTransitionGui"
	fadeGui.ResetOnSpawn = false
	fadeGui.DisplayOrder = 9999 
	fadeGui.IgnoreGuiInset = true 
	fadeGui.Parent = playerGui
end

local blackScreen = fadeGui:FindFirstChild("FadeScreen")
if not blackScreen then
	blackScreen = Instance.new("Frame")
	blackScreen.Name = "FadeScreen"
	blackScreen.Size = UDim2.new(1, 0, 1, 0)
	blackScreen.BackgroundColor3 = Color3.new(0, 0, 0)
	blackScreen.BackgroundTransparency = 0
	blackScreen.Visible = true
	blackScreen.Parent = fadeGui
end

local loadingLabel = blackScreen:FindFirstChild("LoadingText")
if not loadingLabel then
	loadingLabel = Instance.new("TextLabel")
	loadingLabel.Name = "LoadingText"
	loadingLabel.Size = UDim2.new(1, 0, 0, 50)
	loadingLabel.Position = UDim2.new(0, 0, 0.5, 0)
	loadingLabel.AnchorPoint = Vector2.new(0, 0.5)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.TextColor3 = Color3.new(1, 1, 1)
	loadingLabel.Font = Enum.Font.GothamBold
	loadingLabel.TextScaled = true
	loadingLabel.Text = "loading scripts/models/gui: 0/0"
	loadingLabel.Parent = blackScreen
end

-- ==========================================
-- 2. HºADANIE SYST…MOV (Replicated Storage)
-- ==========================================
print("[DEBUG] »ak·m na ArmySystem v ReplicatedStorage...")
local armySystem = ReplicatedStorage:WaitForChild("ArmySystem", 10)
if not armySystem then warn("[DEBUG CHYBA] ArmySystem sa vÙbec nenaöiel!") end

local playEvent = armySystem:WaitForChild("PlayEvent", 5)
local petEvents = armySystem:WaitForChild("PetEvents", 5)
if not petEvents then warn("[DEBUG CHYBA] PetEvents zloûka ch˝ba!") end

local buyChestEvent = petEvents and petEvents:WaitForChild("BuyChest", 5)
local sellPetEvent = petEvents and petEvents:WaitForChild("SellPet", 5)
local toggleEquipEvent = petEvents and petEvents:WaitForChild("ToggleEquip", 5)

local shopFolder = armySystem:WaitForChild("Shop", 5)
local uiFolder = armySystem:WaitForChild("UI", 5)
local petFrameTemplate = uiFolder and uiFolder:WaitForChild("PetFrame", 5)
if not petFrameTemplate then warn("[DEBUG CHYBA] PetFrame öablÛna v UI zloûke ch˝ba!") else print("[DEBUG] PetFrame öablÛna n·jden·.") end

local mainMenuGui = script.Parent
mainMenuGui.ResetOnSpawn = false 

-- ==========================================
-- 3. ZACHYTENIE DAT ZO SERVERA (SyncPets)
-- ==========================================
local currentOwnedPets = {}
local selectedPetUID = nil
local isBuyingChest = false
local updatePetInventory 

if buyChestEvent then
	buyChestEvent.OnClientEvent:Connect(function(action, arg1, arg2)
		print("[DEBUG] Prijat˝ BuyChestEvent! Akcia: " .. tostring(action))
		if action == "SyncPets" then
			currentOwnedPets = arg1 or {}
			print("[DEBUG] SyncPets prijatÈ. PoËet petov: " .. tostring(#currentOwnedPets))
			if updatePetInventory then updatePetInventory() end
		elseif action == "ChestOpened" then
			local petName = arg1
			currentOwnedPets = arg2 or {}
			print("[DEBUG] ChestOpened prijatÈ. Padol pet: " .. tostring(petName) .. " | Celkov˝ poËet petov: " .. tostring(#currentOwnedPets))
			if updatePetInventory then updatePetInventory() end

			local claimedFrame = mainMenuGui:FindFirstChild("Claimed")
			if claimedFrame then
				print("[DEBUG] Zobrazujem Claimed Frame pre peta: " .. tostring(petName))
				for _, child in ipairs(claimedFrame:GetChildren()) do
					if child:IsA("ViewportFrame") then child:Destroy() end
				end
				local daily = shopFolder:FindFirstChild("Daily")
				local pFolder = daily and daily:FindFirstChild(petName)
				local model = pFolder and pFolder:FindFirstChildOfClass("Model")

				if model then
					local vpf = Instance.new("ViewportFrame")
					vpf.Size = UDim2.new(1, 0, 1, 0)
					vpf.BackgroundTransparency = 1
					vpf.ZIndex = claimedFrame.ZIndex
					vpf.Parent = claimedFrame
					local clone = model:Clone()
					clone:PivotTo(CFrame.new(0, 0, 0))
					clone.Parent = vpf
					local cam = Instance.new("Camera")
					cam.CFrame = CFrame.new(Vector3.new(4, 3, 6), Vector3.new(0, 0, 0))
					vpf.CurrentCamera = cam
				else
					warn("[DEBUG CHYBA] Nenaöiel sa model pre Claimed UI pre peta: " .. tostring(petName))
				end
				claimedFrame.Visible = true
				task.delay(4, function() claimedFrame.Visible = false end)
			end
		end
	end)
else
	warn("[DEBUG CHYBA] buyChestEvent neexistuje, klient nemÙûe prijÌmaù pety!")
end

if toggleEquipEvent then
	toggleEquipEvent.OnClientEvent:Connect(function(pets)
		print("[DEBUG] ToggleEquipEvent prijat˝.")
		currentOwnedPets = pets or {}
		if updatePetInventory then updatePetInventory() end
	end)
end

if sellPetEvent then
	sellPetEvent.OnClientEvent:Connect(function(pets)
		print("[DEBUG] SellPetEvent prijat˝.")
		currentOwnedPets = pets or {}
		if updatePetInventory then updatePetInventory() end
	end)
end

-- ==========================================
-- 4. FYZICK› LOADING SCREEN
-- ==========================================
print("[DEBUG] ZaËÌnam sùahovaù modely a GUI (PreloadAsync)...")
local assetsToLoad = {}
if armySystem then
	for _, obj in ipairs(armySystem:GetDescendants()) do table.insert(assetsToLoad, obj) end
end
for _, obj in ipairs(mainMenuGui:GetDescendants()) do table.insert(assetsToLoad, obj) end

local totalAssets = #assetsToLoad
local loadedAssets = 0

for _, asset in ipairs(assetsToLoad) do
	ContentProvider:PreloadAsync({asset})
	loadedAssets += 1
	if loadedAssets % 10 == 0 then
		loadingLabel.Text = "loading scripts/models/gui: " .. loadedAssets .. "/" .. totalAssets
		RunService.RenderStepped:Wait() 
	end
end
loadingLabel.Text = "loading scripts/models/gui: " .. totalAssets .. "/" .. totalAssets
print("[DEBUG] Vöetky modely a GUI s˙ stiahnutÈ! ("..totalAssets.." assetov)")
task.wait(0.5) 
loadingLabel.Visible = false

-- ==========================================
-- 5. BEZPE»N… HºADANIE UI S V›PISMI
-- ==========================================
print("[DEBUG] Hæad·m prvky v UI...")
local function findUI(parent, name)
	if not parent then return nil end
	local obj = parent:WaitForChild(name, 2)
	if not obj then 
		warn("[DEBUG CHYBA UI] Ch˝ba prvok: '" .. name .. "' v '" .. parent.Name .. "'.") 
	else
		print("[DEBUG] ⁄speöne n·jdenÈ UI: " .. name)
	end
	return obj
end

local playBtn = findUI(mainMenuGui, "PlayButton")
local shopMenuBtn = findUI(mainMenuGui, "ShopButton")
local petsMenuBtn = findUI(mainMenuGui, "Pets")

local futureShopFrame = findUI(mainMenuGui, "ShopFrame")
local closeShopBtn = findUI(futureShopFrame, "CloseButton")
local dailyChestFrame = findUI(futureShopFrame, "DailyChest")
local chestNameLabel = findUI(dailyChestFrame, "ChestName")
local chestCostLabel = findUI(dailyChestFrame, "ChestCost")

local petsFrame = findUI(mainMenuGui, "PetsFrame")
local closePetsBtn = findUI(petsFrame, "CloseButton")
local petPreviewFrame = findUI(petsFrame, "Frame")
local petScroll = findUI(petPreviewFrame, "ScrollingFrame") 
local equipBtn = findUI(petsFrame, "Equip")
local sellBtn = findUI(petsFrame, "Sell")
local countLabel = findUI(petsFrame, "Count")
local equippedLabel = findUI(petsFrame, "Equiped")
local statsLabel = findUI(petsFrame, "Stats") 

local claimedFrame = findUI(mainMenuGui, "Claimed")
if claimedFrame then
	local claimedCloseBtn = Instance.new("TextButton")
	claimedCloseBtn.Size = UDim2.new(1, 0, 1, 0)
	claimedCloseBtn.BackgroundTransparency = 1
	claimedCloseBtn.Text = ""
	claimedCloseBtn.ZIndex = 100
	claimedCloseBtn.Parent = claimedFrame
	claimedCloseBtn.MouseButton1Click:Connect(function() claimedFrame.Visible = false end)
end

-- ==========================================
-- 6. POMOCN… FUNKCIE A ANIM¡CIE
-- ==========================================
local slideTweenInfo = TweenInfo.new(1.0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local shopOrigPos, shopOffPos = UDim2.new(0.5, 0, 0.5, 0), UDim2.new(1.5, 0, 0.5, 0)
local petsOrigPos, petsOffPos = UDim2.new(0.5, 0, 0.5, 0), UDim2.new(-0.5, 0, 0.5, 0)

if futureShopFrame then
	shopOrigPos = futureShopFrame.Position
	shopOffPos = UDim2.new(1.5, 0, shopOrigPos.Y.Scale, shopOrigPos.Y.Offset)
	futureShopFrame.Position = shopOffPos
	futureShopFrame.Visible = false
end
if petsFrame then
	petsOrigPos = petsFrame.Position
	petsOffPos = UDim2.new(-0.5, 0, petsOrigPos.Y.Scale, petsOrigPos.Y.Offset)
	petsFrame.Position = petsOffPos
	petsFrame.Visible = false
end

local function render3DModel(parentFrame, modelObj)
	if not parentFrame then warn("[DEBUG] render3DModel zlyhal: ParentFrame neexistuje!") return end
	if not modelObj then warn("[DEBUG] render3DModel zlyhal: ModelObj neexistuje!") return end

	for _, child in ipairs(parentFrame:GetChildren()) do
		if child:IsA("ViewportFrame") then child:Destroy() end
	end

	local vpf = Instance.new("ViewportFrame")
	vpf.Size = UDim2.new(1, 0, 1, 0)
	vpf.BackgroundTransparency = 1
	vpf.ZIndex = parentFrame.ZIndex
	vpf.Parent = parentFrame

	local clone = modelObj:Clone()
	local root = clone.PrimaryPart or clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChildWhichIsA("BasePart")
	if root then clone.PrimaryPart = root end
	clone:PivotTo(CFrame.new(0, 0, 0)) 
	clone.Parent = vpf

	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.new(Vector3.new(4, 3, 6), Vector3.new(0, 0, 0))
	vpf.CurrentCamera = cam
	print("[DEBUG] ⁄speöne vyrenderovan˝ 3D model do " .. parentFrame.Name)
end

-- ==========================================
-- 7. LOGIKA PET INVENT¡RA
-- ==========================================
local function getPetConfig(petName)
	if not shopFolder then return nil, nil end
	local daily = shopFolder:FindFirstChild("Daily")
	if daily then
		local p = daily:FindFirstChild(petName)
		if p and p:FindFirstChild("Config") then 
			return require(p.Config), p:FindFirstChildOfClass("Model") 
		end
	end
	warn("[DEBUG CHYBA] Nenaöiel sa config alebo model pre peta: " .. tostring(petName))
	return nil, nil
end

updatePetInventory = function()
	print("[DEBUG] Sp˙öùam updatePetInventory(). PoËet vlastnen˝ch petov: " .. tostring(#currentOwnedPets))
	local equipCount = 0
	for _, pet in ipairs(currentOwnedPets) do
		if pet.Equipped then equipCount += 1 end
	end

	if countLabel then countLabel.Text = #currentOwnedPets .. " / 50" end
	if equippedLabel then equippedLabel.Text = equipCount .. " / 3" end

	if not petScroll then 
		warn("[DEBUG CHYBA] Nenaöiel sa petScroll (ScrollingFrame)!") 
		return 
	end

	for _, child in ipairs(petScroll:GetChildren()) do
		if child:IsA("Frame") or child.Name == "PetSlot" then child:Destroy() end
	end

	for index, pet in ipairs(currentOwnedPets) do
		print("[DEBUG] Vykresæujem peta Ë. " .. index .. ": " .. tostring(pet.Name))
		local config, model = getPetConfig(pet.Name)

		if config and petFrameTemplate then
			local slot = petFrameTemplate:Clone()
			slot.Name = "PetSlot"
			slot.Visible = true 

			local nameLbl = slot:FindFirstChild("NameLabel", true)
			if nameLbl then nameLbl.Text = pet.Name .. (pet.Equipped and " (E)" or "") end
			slot.Parent = petScroll

			if model then
				render3DModel(slot, model)
			else
				warn("[DEBUG] Model pre peta " .. pet.Name .. " neexistuje, nebude maù 3D n·hæad.")
			end

			local function onSlotClick()
				print("[DEBUG] Klikol si na peta: " .. pet.Name)
				selectedPetUID = pet.UID
				render3DModel(petPreviewFrame, model)
				local statsText = string.format("Sell: %d ??\nArmy DMG: +%d%%\nArmy HP: +%d%%\nBldg DMG: +%d%%\nBldg HP: +%d%%\nCoin Boost: +%d%%",
					config.SellCost or 0, config.DamageArmy or 0, config.HealthArmy or 0, config.DamageBuilding or 0, config.HealthBuilding or 0, config.CoinBoost or 0)
				if statsLabel then statsLabel.Text = statsText end
				if equipBtn then equipBtn.Text = pet.Equipped and "Unequip" or "Equip" end
			end

			local btn = slot:FindFirstChildOfClass("TextButton") or slot:FindFirstChildOfClass("ImageButton") or slot 
			if btn:IsA("GuiButton") then
				btn.MouseButton1Click:Connect(onSlotClick)
			else
				btn.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						onSlotClick()
					end
				end)
			end
		else
			warn("[DEBUG CHYBA] Zlyhalo klonovanie PetFrameTemplate alebo naËÌtanie Configu pre " .. tostring(pet.Name))
		end
	end
	print("[DEBUG] updatePetInventory() dokonËenÈ.")
end

-- ==========================================
-- 8. PÿÕPRAVA DAILY CHEST V MENU
-- ==========================================
print("[DEBUG] Nastavujem Daily Chest UI...")
local dailyData = shopFolder and shopFolder:FindFirstChild("Daily")
if dailyData then
	local confScript = dailyData:FindFirstChild("Config")
	local cost = 100
	if confScript then 
		cost = require(confScript).Cost or 100 
		print("[DEBUG] Cena Daily bedne ˙speöne naËÌtan·: " .. cost)
	else
		warn("[DEBUG CHYBA] Ch˝ba Config skript priamo v Daily zloûke!")
	end

	if chestNameLabel then chestNameLabel.Text = "Daily Chest" end
	if chestCostLabel then chestCostLabel.Text = "?? " .. tostring(cost) end

	local chestModel = dailyData:FindFirstChild("Model")
	if chestModel and dailyChestFrame then 
		render3DModel(dailyChestFrame, chestModel) 
	else
		warn("[DEBUG CHYBA] Nenaöiel sa 3D model pre Daily Chest v zloûke Daily!")
	end
else
	warn("[DEBUG CHYBA] Zloûka Daily v zloûke Shop neexistuje!")
end

-- ==========================================
-- 9. KLIKANIE NA TLA»IDL¡
-- ==========================================
if dailyChestFrame then
	dailyChestFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			print("[DEBUG] Klikol si na Daily Chest Frame.")
			if isBuyingChest then print("[DEBUG] BlokovanÈ: Uû pr·ve kupujeö bedÚu.") return end
			if not buyChestEvent then warn("[DEBUG] buyChestEvent neexistuje, n·kup zlyhal.") return end

			isBuyingChest = true
			print("[DEBUG] Odosielam poûiadavku na n·kup Daily na server...")
			buyChestEvent:FireServer("Daily")
			task.delay(1, function() isBuyingChest = false end)
		end
	end)
end

if equipBtn then
	equipBtn.MouseButton1Click:Connect(function()
		if selectedPetUID and toggleEquipEvent then 
			print("[DEBUG] Posielam poûiadavku na Equip pre UID: " .. selectedPetUID)
			toggleEquipEvent:FireServer(selectedPetUID) 
		end
	end)
end

if sellBtn then
	sellBtn.MouseButton1Click:Connect(function()
		if selectedPetUID and sellPetEvent then 
			print("[DEBUG] Posielam poûiadavku na Sell pre UID: " .. selectedPetUID)
			sellPetEvent:FireServer(selectedPetUID) 
			selectedPetUID = nil
			if statsLabel then statsLabel.Text = "Select a pet" end
			render3DModel(petPreviewFrame, nil)
		end
	end)
end

local isShopOpen, isPetsOpen = false, false
local function toggleMenu(frame, origPos, offPos, stateVar)
	if not frame then return false end
	if stateVar then
		stateVar = false
		local tw = TweenService:Create(frame, slideTweenInfo, {Position = offPos})
		tw:Play()
		tw.Completed:Connect(function() if not stateVar then frame.Visible = false end end)
		return false
	else
		stateVar = true
		frame.Visible = true
		TweenService:Create(frame, slideTweenInfo, {Position = origPos}):Play()
		return true
	end
end

if shopMenuBtn and futureShopFrame then shopMenuBtn.MouseButton1Click:Connect(function() isShopOpen = toggleMenu(futureShopFrame, shopOrigPos, shopOffPos, isShopOpen) end) end
if closeShopBtn and futureShopFrame then closeShopBtn.MouseButton1Click:Connect(function() isShopOpen = toggleMenu(futureShopFrame, shopOrigPos, shopOffPos, isShopOpen) end) end
if petsMenuBtn and petsFrame then petsMenuBtn.MouseButton1Click:Connect(function() isPetsOpen = toggleMenu(petsFrame, petsOrigPos, petsOffPos, isPetsOpen) end) end
if closePetsBtn and petsFrame then closePetsBtn.MouseButton1Click:Connect(function() isPetsOpen = toggleMenu(petsFrame, petsOrigPos, petsOffPos, isPetsOpen) end) end

-- ==========================================
-- 10. SPR¡VA STAVU HRY (Kamera)
-- ==========================================
local cameraConnection = nil
local function updateGameState()
	local inGame = player:GetAttribute("InGame")
	if inGame then
		mainMenuGui.Enabled = false
		isShopOpen, isPetsOpen = false, false
		if futureShopFrame then futureShopFrame.Position = shopOffPos; futureShopFrame.Visible = false end
		if petsFrame then petsFrame.Position = petsOffPos; petsFrame.Visible = false end
		if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
	else
		mainMenuGui.Enabled = true
		if not cameraConnection then
			local menuCenter = workspace:WaitForChild("MenuCenter", 10)
			if menuCenter then
				local cameraAngle = 0
				cameraConnection = RunService.RenderStepped:Connect(function(dt)
					camera.CameraType = Enum.CameraType.Scriptable 
					cameraAngle = cameraAngle + math.rad(15 * dt)
					local offset = Vector3.new(math.cos(cameraAngle) * 25, 15, math.sin(cameraAngle) * 25)
					camera.CFrame = CFrame.new(menuCenter.Position + offset, menuCenter.Position)
				end)
			end
		end
	end
end

-- Vöetko je naËÌtanÈ! Zmizne Ëierna obrazovka
print("[DEBUG] Skript kompletne prebehol, odstraÚujem Black Screen!")
TweenService:Create(blackScreen, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
task.delay(1.0, function() blackScreen.Visible = false end)

local function onCharacterAdded(char)
	local hum = char:WaitForChild("Humanoid", 5)
	if hum and blackScreen then 
		hum.Died:Connect(function() 
			if loadingLabel then loadingLabel.Visible = false end 
			blackScreen.BackgroundTransparency = 0; 
			blackScreen.Visible = true 
			task.wait(1.5)
			TweenService:Create(blackScreen, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
			task.delay(1.0, function() blackScreen.Visible = false end)
		end) 
	end
end

if player.Character then task.spawn(onCharacterAdded, player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

if playBtn then playBtn.MouseButton1Click:Connect(function() if not player:GetAttribute("InGame") and playEvent then playEvent:FireServer() end end) end

updateGameState()
player:GetAttributeChangedSignal("InGame"):Connect(updateGameState)