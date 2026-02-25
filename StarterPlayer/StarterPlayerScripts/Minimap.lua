local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- 1. Vytvoøení GUI pro minimapu
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MinimapGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local viewportFrame = Instance.new("ViewportFrame")
viewportFrame.Name = "MinimapDisplay"
viewportFrame.Size = UDim2.new(0, 250, 0, 250)
viewportFrame.Position = UDim2.new(1, -270, 0, 20) 
-- Odstranìní výplnì minimapy (úplná prùhlednost)
viewportFrame.BackgroundTransparency = 1 
viewportFrame.BorderSizePixel = 0
viewportFrame.ClipsDescendants = true
viewportFrame.Parent = screenGui

-- Zakulacení celé minimapy
local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(0.1, 0)
mapCorner.Parent = viewportFrame

-- Bílý obrys celé minimapy (zùstává zachován)
local mapStroke = Instance.new("UIStroke")
mapStroke.Color = Color3.fromRGB(255, 255, 255)
mapStroke.Thickness = 3
mapStroke.Parent = viewportFrame

-- 2. Vytvoøení a nastavení kamery
local minimapCamera = Instance.new("Camera")
minimapCamera.CameraType = Enum.CameraType.Scriptable
minimapCamera.FieldOfView = 70
viewportFrame.CurrentCamera = minimapCamera
minimapCamera.Parent = viewportFrame

-- Nalezení Baseplatu a pøizpùsobení minimapy jeho velikosti
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
	warn("Objekt 'Baseplate' nebyl nalezen! Skript nebude fungovat správnì.")
	return -- Zastaví skript, pokud neexistuje Baseplate
end

-- 3. Funkce pro naètení 3D objektù do minimapy z Workspace
local function loadMinimapObjects()
	local workspaceMinimapFolder = workspace:WaitForChild("Minimap", 10)

	if not workspaceMinimapFolder then return end

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

loadMinimapObjects()

-- 4. Systém pro sledování VŠECH hráèù
local playerIcons = {}

local function createPlayerIcon(plr)
	if playerIcons[plr] then return end -- Pokud už ikonu má, nevytváøíme novou

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
	uiStroke.Color = Color3.fromRGB(255, 255, 255) -- Bílý obrys ikony hráèe
	uiStroke.Parent = icon

	-- Tvoje ikona bude vždy vykreslena nad ostatními
	if plr == player then
		icon.ZIndex = 11 
	end

	-- Naètení fotky asynchronnì
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

-- Vytvoøí ikony pro hráèe, kteøí už ve høe jsou, a hlídá pøipojení/odpojení
for _, plr in ipairs(Players:GetPlayers()) do
	createPlayerIcon(plr)
end
Players.PlayerAdded:Connect(createPlayerIcon)
Players.PlayerRemoving:Connect(removePlayerIcon)

-- 5. Smyèka pro aktualizaci pozic všech hráèù
RunService.RenderStepped:Connect(function()
	for plr, icon in pairs(playerIcons) do
		local character = plr.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local rootPart = character.HumanoidRootPart

			-- Relativní pozice na Baseplatu místo pixelù kamery
			local relativeX = (rootPart.Position.X - baseplate.Position.X) / baseplate.Size.X + 0.5
			local relativeZ = (rootPart.Position.Z - baseplate.Position.Z) / baseplate.Size.Z + 0.5

			-- Pokud je hráè na mapì (hodnoty od 0 do 1), tak ho zobrazíme
			if relativeX >= 0 and relativeX <= 1 and relativeZ >= 0 and relativeZ <= 1 then
				icon.Visible = true

				-- Aplikování pøesné pozice do UI (Scale místo Offset)
				icon.Position = UDim2.new(relativeX, 0, relativeZ, 0)

				-- Výpoèet rotace ikony
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