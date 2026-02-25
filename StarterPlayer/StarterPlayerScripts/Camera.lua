local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService") -- Služba pro detekci myši

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- --- NASTAVENÍ ---
local FOV = 25           -- Project Zomboid efekt
local HLADKST = 0.2      -- Rychlost vyhlazování pohybu

-- Nastavení Zoomu
local START_ZOOM = 60    -- Výchozí vzdálenost
local START_VYSKA = 60   -- Výchozí výška (pro výpoèet úhlu)
local MIN_ZOOM = 20      -- Jak nejblíže mùžeš pøiblížit
local MAX_ZOOM = 350     -- Jak nejdále mùžeš oddálit
local Rychlost_Zoomu = 5 -- O kolik se kamera posune jedním otoèením koleèka

-- --- PROMÌNNÉ PRO VÝPOÈTY ---
local aktualniZoom = START_ZOOM
-- Vypoèítáme pomìr výšky vùèi vzdálenosti, abychom pøi zoomování zachovali úhel
local pomerVysky = START_VYSKA / START_ZOOM 

camera.FieldOfView = FOV

-- --- FUNKCE PRO DETEKCI KOLEÈKA MYŠI ---
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	-- Pokud hráè toèí koleèkem
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		-- Input.Position.Z je buï 1 (nahoru) nebo -1 (dolu)
		-- Když toèíme nahoru (Zoom In), chceme zmenšit vzdálenost (proto mínus)
		local novyZoom = aktualniZoom - (input.Position.Z * Rychlost_Zoomu)

		-- Omezíme zoom, aby nešel pod MIN nebo nad MAX (math.clamp)
		aktualniZoom = math.clamp(novyZoom, MIN_ZOOM, MAX_ZOOM)
	end
end)

-- --- HLAVNÍ FUNKCE KAMERY ---
local function updateCamera()
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			camera.CameraType = Enum.CameraType.Scriptable

			-- Pøepoèítáme výšku podle aktuálního zoomu, aby úhel zùstal stejný
			local aktualniVyska = aktualniZoom * pomerVysky

			-- ÚPRAVA: Kamera je nyní usazena "dole" (na ose Z) a dívá se "nahoru"
			-- Tím se srovná smìr chùze obrazovky s orientací minimapy.
			-- Když pùjdeš "S" (k sobì), pùjdeš dolù i na minimapì.
			local targetPosition = rootPart.Position + Vector3.new(0, aktualniVyska, aktualniZoom)

			local targetCFrame = CFrame.new(targetPosition, rootPart.Position)

			-- Aplikujeme plynulý pohyb
			camera.CFrame = camera.CFrame:Lerp(targetCFrame, HLADKST)
		end
	end
end

RunService.RenderStepped:Connect(updateCamera)