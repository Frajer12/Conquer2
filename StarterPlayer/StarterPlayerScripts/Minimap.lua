local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- 1. Vytvoření GUI pro minimapu
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MinimapGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local viewportFrame = Instance.new("ViewportFrame")
viewportFrame.Name = "MinimapDisplay"
viewportFrame.Size = UDim2.new(0, 250, 0, 250)
viewportFrame.Position = UDim2.new(1, -270, 0, 20) 
-- Odstranění výplně minimapy (úplná průhlednost)
viewportFrame.BackgroundTransparency = 1 
viewportFrame.BorderSizePixel = 0
viewportFrame.ClipsDescendants = true

-- OPRAVA SVĚTLA: Bez tohoto jsou naklonované Party ve ViewportFrame úplně černé/neviditelné!
viewportFrame.Ambient = Color3.fromRGB(255, 255, 255)
viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)

viewportFrame.Parent = screenGui

-- Zakulacení celé minimapy
local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(0.1, 0)
mapCorner.Parent = viewportFrame

-- Bílý obrys celé minimapy (zůstává zachován)
local mapStroke = Instance.new("UIStroke")
mapStroke.Color = Color3.fromRGB(255, 255, 255)
mapStroke.Thickness = 3
mapStroke.Parent = viewportFrame

-- 2. Vytvoření a nastavení kamery
local minimapCamera = Instance.new("Camera")
minimapCamera.CameraType = Enum.CameraType.Scriptable
minimapCamera.FieldOfView = 70
viewportFrame.CurrentCamera = minimapCamera
minimapCamera.Parent = viewportFrame

-- Nalezení Baseplatu a přizpůsobení minimapy jeho velikosti
local baseplate = workspace:WaitForChild("Baseplate", 10)

if baseplate then
	local aspectRatio = Instance.new("UIAspectRatioConstraint")
	aspectRatio.AspectRatio = baseplate.Size.X / baseplate.Size.Z
	aspectRatio.Parent = viewportFrame

	local maxDimension = math.max(baseplate.Size.X, baseplate.Size.Z)
	local fov = minimapCamera.FieldOfView
	local cameraHeight = ((maxDimension / 2) / math.tan(math.rad(fov / 2))) * 1.05 

	local bpPos = baseplate.Position
	local cameraPos = Vector3.new(bpPos.X, bpPos.Y + cameraHeight, bpPos.Z)

	minimapCamera.CFrame = CFrame.new(cameraPos, bpPos)
else
	warn("Objekt 'Baseplate' nebyl nalezen! Skript nebude fungovat správně.")
	return -- Zastaví skript, pokud neexistuje Baseplate
end

-- 3. Funkce pro načtení 3D objektů do minimapy z Workspace
local function loadMinimapObjects()
	local workspaceMinimapFolder = workspace:WaitForChild("Minimap", 10)

	if not workspaceMinimapFolder then return end

	-- OPRAVA NAČÍTÁNÍ: Počkáme 2 vteřiny, než se klientovi do složky reálně stáhnou objekty ze serveru
	task.wait(2)

	for _, obj in ipairs(workspaceMinimapFolder:GetChildren()) do
		if obj:IsA("BasePart") or obj:IsA("Model") then
			local clone = obj:Clone()

			if clone:IsA("Model") then
				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Transparency = 0
					end
				end
			elseif clone:IsA("BasePart") then
				clone.Transparency = 0
			end

			clone.Parent = viewportFrame
		end
	end
end

-- Použití task.spawn, aby čekání 2 vteřiny nezastavilo zbytek skriptu a rovnou se ukázali hráči
task.spawn(loadMinimapObjects)


-- 4. Systém pro sledování VŠECH hráčů
local playerIcons = {}

local function createPlayerIcon(plr)
	if playerIcons[plr] then return end -- Pokud už ikonu má, nevytváříme novou

	local icon = Instance.new("ImageLabel")
	icon.Name = plr.Name .. "_Icon"
	icon.Size = UDim2.new(0, 18, 0, 18) -- Zmenšená ikona
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.ZIndex = 10
	icon.Visible = false -- Skryto, dokud nenajdeme postavu

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0.5, 0) -- Dokonalý kruh
	uiCorner.Parent = icon

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 2
	uiStroke.Color = Color3.fromRGB(255, 255, 255) -- Bílý obrys ikony hráče
	uiStroke.Parent = icon

	-- Tvoje ikona bude vždy vykreslena nad ostatními
	if plr == player then
		icon.ZIndex = 11 
	end

	-- Načtení fotky asynchronně
	task.spawn(function()
		local success, content = pcall(function()
			return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		if success then
			icon.Image = content
		end
	end)

	icon.Parent = viewportFrame
	playerIcons[plr] = icon
end

local function removePlayerIcon(plr)
	if playerIcons[plr] then
		playerIcons[plr]:Destroy()
		playerIcons[plr] = nil
	end
end

-- Vytvoří ikony pro hráče, kteří už ve hře jsou, a hlídá připojení/odpojení
for _, plr in ipairs(Players:GetPlayers()) do
	createPlayerIcon(plr)
end
Players.PlayerAdded:Connect(createPlayerIcon)
Players.PlayerRemoving:Connect(removePlayerIcon)


-- =======================================================
-- 5. Systém pro sledování BUDOV (zmenšené tečky)
-- =======================================================
local activeBuildings = workspace:WaitForChild("ActiveBuildings", 10)
local buildingIcons = {}

local function createBuildingIcon(building)
	if not building:IsA("Model") then return end
	
	-- Počkáme na PrimaryPart, podle kterého zjistíme pozici
	local rootPart = building.PrimaryPart or building:WaitForChild("HumanoidRootPart", 2)
	if not rootPart then return end

	-- Vytvoření zmenšené tečky pro budovu
	local icon = Instance.new("Frame")
	icon.Name = building.Name .. "_Icon"
	icon.Size = UDim2.new(0, 8, 0, 8) -- ZMENŠENO na 8x8 px
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.ZIndex = 8
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = icon
	
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = icon

	if building.Name == "Zlata Dola" then
		icon.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	else
		icon.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
	end

	local relativeX = (rootPart.Position.X - baseplate.Position.X) / baseplate.Size.X + 0.5
	local relativeZ = (rootPart.Position.Z - baseplate.Position.Z) / baseplate.Size.Z + 0.5
	
	if relativeX >= 0 and relativeX <= 1 and relativeZ >= 0 and relativeZ <= 1 then
		icon.Position = UDim2.new(relativeX, 0, relativeZ, 0)
		icon.Parent = viewportFrame
		buildingIcons[building] = icon
	else
		icon:Destroy()
	end
end

local function removeBuildingIcon(building)
	if buildingIcons[building] then
		buildingIcons[building]:Destroy()
		buildingIcons[building] = nil
	end
end

if activeBuildings then
	for _, building in ipairs(activeBuildings:GetChildren()) do
		createBuildingIcon(building)
	end
	activeBuildings.ChildAdded:Connect(createBuildingIcon)
	activeBuildings.ChildRemoved:Connect(removeBuildingIcon)
end
-- =======================================================


-- 6. Smyčka pro aktualizaci pozic všech hráčů
RunService.RenderStepped:Connect(function()
	for plr, icon in pairs(playerIcons) do
		local character = plr.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local rootPart = character.HumanoidRootPart

			-- Relativní pozice na Baseplatu místo pixelů kamery
			local relativeX = (rootPart.Position.X - baseplate.Position.X) / baseplate.Size.X + 0.5
			local relativeZ = (rootPart.Position.Z - baseplate.Position.Z) / baseplate.Size.Z + 0.5

			-- Pokud je hráč na mapě (hodnoty od 0 do 1), tak ho zobrazíme
			if relativeX >= 0 and relativeX <= 1 and relativeZ >= 0 and relativeZ <= 1 then
				icon.Visible = true

				-- Aplikování přesné pozice do UI (Scale místo Offset)
				icon.Position = UDim2.new(relativeX, 0, relativeZ, 0)

				-- Výpočet rotace ikony
				local lookVector = rootPart.CFrame.LookVector
				local rotation = math.deg(math.atan2(lookVector.X, lookVector.Z))
				icon.Rotation = rotation + 180
			else
				icon.Visible = false
			end
		else
			icon.Visible = false
		end
	end
end)
