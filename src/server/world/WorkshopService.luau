--!strict

--[[
	WorkshopService

	Owns the persistent physical Workshop shell and manages the swappable
	ExperimentBay where active challenges live.

	Structure:
		Workspace
		└── Workshop
		    ├── Shell
		    │   ├── Floor & Walls (perimeter boundaries)
		    │   ├── Overhead Gantry & Lighting
		    │   ├── MakerWorkbench (custom asset or procedural fallback)
		    │   ├── ToolStorageRack (custom asset or procedural fallback)
		    │   ├── WallPanels & ConnectorBoard
		    │   ├── Crates
		    │   └── WorkshopSpawn
		    │
		    └── ExperimentBay
		        └── current experiment (floor sections, obstacles, duck, goal, parts)

	When experiments switch (e.g. 001 -> 002):
		* Workshop.Shell remains untouched (no camera jump, no visual flash)
		* Workshop.ExperimentBay is cleared and populated with the new challenge
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)

local AssetProvider = require(script.Parent.Parent.assets.AssetProvider)

local Config = ConstructionConfig

local WorkshopService = {}

local COLORS = {
	Floor = Color3.fromRGB(72, 68, 62),
	FloorTrim = Color3.fromRGB(50, 48, 44),
	Wall = Color3.fromRGB(98, 82, 68),
	WallTrim = Color3.fromRGB(55, 52, 50),
	Metal = Color3.fromRGB(90, 94, 102),
	DarkMetal = Color3.fromRGB(48, 50, 56),
	IndustrialYellow = Color3.fromRGB(240, 185, 45),
	Wood = Color3.fromRGB(115, 85, 58),
	WoodTop = Color3.fromRGB(135, 102, 70),
	CrateWood = Color3.fromRGB(150, 115, 75),
	Spawn = Color3.fromRGB(90, 180, 120),
	LampFixture = Color3.fromRGB(45, 48, 52),
	LampBulb = Color3.fromRGB(255, 245, 220),
}

local workshopInstance: Instance? = nil
local shellInstance: Instance? = nil
local experimentBayInstance: Folder? = nil
local spawnLocationInstance: SpawnLocation? = nil

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Workshop] %s", message))
	end
end

local function createPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	parent: Instance,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CollisionGroup = Config.CollisionGroupEnvironment
	part.Parent = parent

	return part
end

local function createInvisibleCollider(
	name: string,
	size: Vector3,
	cframe: CFrame,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name .. "_Collider"
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.CastShadow = false
	part.CollisionGroup = Config.CollisionGroupEnvironment
	part.Parent = parent

	return part
end

--[[
	Ensures imported custom visual assets are anchored, non-colliding,
	and cannot interfere with gameplay queries.
]]
local function prepCustomVisual(visual: Model)
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CollisionGroup = Config.CollisionGroupEnvironment
		end
	end
end

-- Lighting baseline -----------------------------------------------------------

local function setupBaselineLighting()
	Lighting.Brightness = 2.0
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 41.7
	Lighting.Ambient = Color3.fromRGB(85, 85, 92)
	Lighting.OutdoorAmbient = Color3.fromRGB(115, 115, 122)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
end

-- Procedural fallbacks for workshop props -------------------------------------

local function buildFallbackWorkbench(parent: Instance, pivot: CFrame)
	local model = Instance.new("Model")
	model.Name = "MakerWorkbench_Fallback"

	local topSize = Vector3.new(12, 0.6, 5)
	local topY = 3.3
	local top = createPart(
		"BenchTop",
		topSize,
		pivot * CFrame.new(0, topY, 0),
		model,
		COLORS.WoodTop,
		Enum.Material.WoodPlanks
	)
	model.PrimaryPart = top

	local legSize = Vector3.new(0.8, 3.0, 0.8)
	for _, xOff in { -5.2, 5.2 } do
		for _, zOff in { -2.0, 2.0 } do
			createPart(
				"BenchLeg",
				legSize,
				pivot * CFrame.new(xOff, 1.5, zOff),
				model,
				COLORS.DarkMetal,
				Enum.Material.Metal
			)
		end
	end

	-- Lower tool shelf
	createPart(
		"BenchShelf",
		Vector3.new(10.5, 0.3, 4),
		pivot * CFrame.new(0, 0.8, 0),
		model,
		COLORS.Wood,
		Enum.Material.Wood
	)

	-- Toolboxes on top
	for i, xOff in { -3, 3 } do
		local tb = createPart(
			string.format("Toolbox_%d", i),
			Vector3.new(2.4, 1.6, 1.8),
			pivot * CFrame.new(xOff, topY + 0.8 + 0.3, -0.6),
			model,
			if i == 1 then COLORS.IndustrialYellow else COLORS.Metal,
			Enum.Material.Metal
		)
		tb.CanCollide = false
	end

	createInvisibleCollider(
		"MakerWorkbench",
		Vector3.new(12.2, 3.8, 5.2),
		pivot * CFrame.new(0, 1.9, 0),
		model
	)
	model.Parent = parent
end

local function buildFallbackToolRack(parent: Instance, pivot: CFrame)
	local model = Instance.new("Model")
	model.Name = "ToolStorageRack_Fallback"

	local width = 10
	local height = 8
	local depth = 3

	local leftPost = createPart(
		"PostLeft",
		Vector3.new(0.8, height, 0.8),
		pivot * CFrame.new(-width * 0.5 + 0.4, height * 0.5, 0),
		model,
		COLORS.DarkMetal,
		Enum.Material.Metal
	)
	model.PrimaryPart = leftPost

	createPart(
		"PostRight",
		Vector3.new(0.8, height, 0.8),
		pivot * CFrame.new(width * 0.5 - 0.4, height * 0.5, 0),
		model,
		COLORS.DarkMetal,
		Enum.Material.Metal
	)

	-- Crossbars (industrial yellow painted steel)
	for _, barY in { 2.2, 4.2, 6.2 } do
		createPart(
			"CrossBar",
			Vector3.new(width - 0.8, 0.4, 0.4),
			pivot * CFrame.new(0, barY, 0),
			model,
			COLORS.IndustrialYellow,
			Enum.Material.Metal
		)
	end

	-- Bottom parts tray
	createPart(
		"PartsTray",
		Vector3.new(width, 0.6, depth),
		pivot * CFrame.new(0, 0.3, 0),
		model,
		COLORS.Metal,
		Enum.Material.CorrodedMetal
	)

	createInvisibleCollider(
		"ToolStorageRack",
		Vector3.new(width + 0.4, height, depth + 0.4),
		pivot * CFrame.new(0, height * 0.5, 0),
		model
	)
	model.Parent = parent
end

local function buildFallbackWallPanel(parent: Instance, pivot: CFrame)
	local model = Instance.new("Model")
	model.Name = "WallPanel_Fallback"

	local panel = createPart(
		"Panel",
		Vector3.new(8, 12, 0.6),
		pivot,
		model,
		COLORS.DarkMetal,
		Enum.Material.Metal
	)
	panel.CanCollide = false
	model.PrimaryPart = panel

	-- Ribbed detail
	for yOff = -4, 4, 2 do
		local rib = createPart(
			"Rib",
			Vector3.new(7.4, 0.3, 0.3),
			pivot * CFrame.new(0, yOff, 0.4),
			model,
			COLORS.IndustrialYellow,
			Enum.Material.SmoothPlastic
		)
		rib.CanCollide = false
	end

	model.Parent = parent
end

local function buildFallbackConnectorBoard(parent: Instance, pivot: CFrame)
	local model = Instance.new("Model")
	model.Name = "ConnectorBoard_Fallback"

	local board = createPart(
		"Board",
		Vector3.new(12, 8, 0.6),
		pivot,
		model,
		Color3.fromRGB(65, 75, 88),
		Enum.Material.SmoothPlastic
	)
	board.CanCollide = false
	model.PrimaryPart = board

	-- Frame
	local frame = createPart(
		"Frame",
		Vector3.new(12.4, 8.4, 0.4),
		pivot * CFrame.new(0, 0, -0.2),
		model,
		COLORS.DarkMetal,
		Enum.Material.Metal
	)
	frame.CanCollide = false

	model.Parent = parent
end

local function buildFallbackCrate(parent: Instance, pivot: CFrame)
	local model = Instance.new("Model")
	model.Name = "Crate_Fallback"

	local crate = createPart(
		"CrateBody",
		Vector3.new(3.5, 2.5, 3.5),
		pivot * CFrame.new(0, 1.25, 0),
		model,
		COLORS.CrateWood,
		Enum.Material.WoodPlanks
	)
	model.PrimaryPart = crate

	createInvisibleCollider(
		"Crate",
		Vector3.new(3.6, 2.6, 3.6),
		pivot * CFrame.new(0, 1.25, 0),
		model
	)
	model.Parent = parent
end

-- Prop placement helpers ------------------------------------------------------

local function placeProp(
	parent: Instance,
	propName: string,
	pivot: CFrame,
	fallbackBuilder: (parent: Instance, pivot: CFrame) -> ()
)
	local visual = AssetProvider.GetOrNil("Props", propName)
	if visual ~= nil then
		prepCustomVisual(visual)
		visual:PivotTo(pivot)
		visual.Parent = parent

		-- Simple invisible collider for props that players might bump into
		local extents = visual:GetExtentsSize()
		local boundingBoxCFrame = visual:GetPivot()
		if propName == "MakerWorkbench" or propName == "ToolStorageRack" or propName == "Crate" then
			createInvisibleCollider(propName, extents, boundingBoxCFrame, parent)
		end
		log(string.format("Placed custom prop: %s", propName))
	else
		fallbackBuilder(parent, pivot)
		log(string.format("Placed procedural fallback for prop: %s", propName))
	end
end

-- Shell Construction ---------------------------------------------------------

local function buildPersistentShell(workshop: Instance): Instance
	local shell = Instance.new("Folder")
	shell.Name = Config.ShellFolderName
	shell:SetAttribute(Config.AttributePersistentShell, true)

	-- 1. Workshop perimeter floor
	local floor = createPart(
		"PerimeterFloor",
		Vector3.new(130, 2, 130),
		CFrame.new(0, -1, 0),
		shell,
		COLORS.Floor,
		Enum.Material.Concrete
	)
	floor.CanCollide = true

	-- Perimeter boundary curb / trim
	for _, x in { -64, 64 } do
		createPart(
			"CurbX",
			Vector3.new(2, 1.5, 130),
			CFrame.new(x, 0.75, 0),
			shell,
			COLORS.FloorTrim,
			Enum.Material.Concrete
		)
	end

	-- 2. Workshop Walls
	-- Back wall (behind the action)
	createPart(
		"BackWall",
		Vector3.new(130, 32, 2),
		CFrame.new(0, 15, -42),
		shell,
		COLORS.Wall,
		Enum.Material.WoodPlanks
	)

	-- Left wall
	createPart(
		"LeftWall",
		Vector3.new(2, 32, 130),
		CFrame.new(-65, 15, 0),
		shell,
		COLORS.Wall,
		Enum.Material.Concrete
	)

	-- Right wall
	createPart(
		"RightWall",
		Vector3.new(2, 32, 130),
		CFrame.new(65, 15, 0),
		shell,
		COLORS.Wall,
		Enum.Material.Concrete
	)

	-- 3. Overhead Lighting & Gantry Trusses
	local lightingFolder = Instance.new("Folder")
	lightingFolder.Name = "LightingDressing"
	lightingFolder.Parent = shell

	-- Steel gantry beams crossing left-to-right overhead
	for _, beamZ in { -22, 12 } do
		createPart(
			"GantryTruss",
			Vector3.new(130, 1.4, 1.4),
			CFrame.new(0, 28, beamZ),
			lightingFolder,
			COLORS.DarkMetal,
			Enum.Material.Metal
		)
	end

	-- Overhead pendant lights
	local lightPositions = {
		Vector3.new(-22, 22, -18), -- above workbench area
		Vector3.new(22, 22, -18), -- above tool rack area
		Vector3.new(0, 24, -16), -- above start pad
		Vector3.new(0, 24, 16), -- above goal pad
	}

	for i, pos in lightPositions do
		local fixture = createPart(
			string.format("PendantLight_%d", i),
			Vector3.new(2.4, 0.8, 2.4),
			CFrame.new(pos),
			lightingFolder,
			COLORS.LampFixture,
			Enum.Material.Metal
		)
		fixture.CanCollide = false

		-- Cord to ceiling
		local cord = createPart(
			string.format("LampCord_%d", i),
			Vector3.new(0.2, 28 - pos.Y, 0.2),
			CFrame.new(pos.X, (pos.Y + 28) * 0.5, pos.Z),
			lightingFolder,
			COLORS.DarkMetal,
			Enum.Material.SmoothPlastic
		)
		cord.CanCollide = false

		-- Glowing bulb
		local bulb = createPart(
			string.format("LampBulb_%d", i),
			Vector3.new(1.8, 0.4, 1.8),
			CFrame.new(pos.X, pos.Y - 0.4, pos.Z),
			lightingFolder,
			COLORS.LampBulb,
			Enum.Material.Neon
		)
		bulb.CanCollide = false

		local pointLight = Instance.new("PointLight")
		pointLight.Name = "OverheadLight"
		pointLight.Color = Color3.fromRGB(255, 238, 215)
		pointLight.Brightness = 2.0
		pointLight.Range = 45
		pointLight.Shadows = true
		pointLight.Parent = bulb
	end

	-- 4. Props
	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "Props"
	propsFolder.Parent = shell

	-- MakerWorkbench: on the left of the start pad, facing the experiment bay
	local benchPivot = CFrame.new(-28, 0, -18) * CFrame.Angles(0, math.rad(90), 0)
	placeProp(propsFolder, "MakerWorkbench", benchPivot, buildFallbackWorkbench)

	-- ToolStorageRack: on the right of the start pad, facing the experiment bay
	local rackPivot = CFrame.new(28, 0, -18) * CFrame.Angles(0, math.rad(-90), 0)
	placeProp(propsFolder, "ToolStorageRack", rackPivot, buildFallbackToolRack)

	-- Wall Panels & Connector Board on Back Wall
	local leftPanelPivot = CFrame.new(-18, 14, -40.5)
	placeProp(propsFolder, "WorkshopWallPanel", leftPanelPivot, buildFallbackWallPanel)

	local rightPanelPivot = CFrame.new(18, 14, -40.5)
	placeProp(propsFolder, "WorkshopWallPanel", rightPanelPivot, buildFallbackWallPanel)

	local boardPivot = CFrame.new(0, 14, -40.5)
	placeProp(propsFolder, "ConnectorBoard", boardPivot, buildFallbackConnectorBoard)

	-- Crates
	local cratePositions = {
		CFrame.new(-34, 0, -6),
		CFrame.new(-34, 2.5, -6) * CFrame.Angles(0, math.rad(15), 0),
		CFrame.new(34, 0, -6),
		CFrame.new(34, 0, -10),
		CFrame.new(34, 2.5, -8) * CFrame.Angles(0, math.rad(-10), 0),
	}
	for _, cPivot in cratePositions do
		placeProp(propsFolder, "Crate", cPivot, buildFallbackCrate)
	end

	-- 5. Workshop Spawn
	local spawnCFrame = CFrame.lookAt(Vector3.new(0, 0.5, -34), Vector3.new(0, 0.5, 0))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = Config.SpawnName
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = spawnCFrame
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Color = COLORS.Spawn
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Transparency = 0.5
	spawn.CollisionGroup = Config.CollisionGroupEnvironment
	spawn.Parent = shell

	spawnLocationInstance = spawn
	shell.Parent = workshop

	log("Persistent Workshop Shell built successfully")
	return shell
end

-- Public Service API ---------------------------------------------------------

function WorkshopService.GetOrCreateWorkshop(): Instance
	if workshopInstance ~= nil and workshopInstance.Parent ~= nil then
		return workshopInstance
	end

	local existing = Workspace:FindFirstChild(Config.AuthoredWorkshopName)
	if existing ~= nil then
		workshopInstance = existing
	else
		local workshop = Instance.new("Folder")
		workshop.Name = Config.AuthoredWorkshopName
		workshop:SetAttribute(Config.AttributeGenerated, true)
		workshop.Parent = Workspace
		workshopInstance = workshop
	end

	setupBaselineLighting()

	-- Ensure Shell
	local shell = workshopInstance:FindFirstChild(Config.ShellFolderName)
	if shell ~= nil then
		shellInstance = shell
		local spawn = shell:FindFirstChild(Config.SpawnName)
		if spawn ~= nil and spawn:IsA("SpawnLocation") then
			spawnLocationInstance = spawn
		end
	else
		shellInstance = buildPersistentShell(workshopInstance)
	end

	-- Ensure ExperimentBay
	local bay = workshopInstance:FindFirstChild(Config.ExperimentBayFolderName)
	if bay ~= nil and bay:IsA("Folder") then
		experimentBayInstance = bay
	else
		local newBay = Instance.new("Folder")
		newBay.Name = Config.ExperimentBayFolderName
		newBay:SetAttribute(Config.AttributeExperimentBay, true)
		newBay.Parent = workshopInstance
		experimentBayInstance = newBay
	end

	return workshopInstance
end

function WorkshopService.GetWorkshop(): Instance
	return WorkshopService.GetOrCreateWorkshop()
end

function WorkshopService.GetShell(): Instance
	WorkshopService.GetOrCreateWorkshop()
	assert(shellInstance ~= nil, "Shell must exist")
	return shellInstance
end

function WorkshopService.GetExperimentBay(): Folder
	WorkshopService.GetOrCreateWorkshop()
	assert(experimentBayInstance ~= nil, "ExperimentBay must exist")
	return experimentBayInstance
end

function WorkshopService.ClearExperimentBay()
	local bay = WorkshopService.GetExperimentBay()
	bay:ClearAllChildren()
	log("Cleared ExperimentBay (Shell preserved)")
end

function WorkshopService.GetSpawnLocation(): SpawnLocation
	WorkshopService.GetOrCreateWorkshop()
	if spawnLocationInstance ~= nil then
		return spawnLocationInstance
	end

	-- Fallback
	local shell = WorkshopService.GetShell()
	local spawn = shell:FindFirstChild(Config.SpawnName)
	if spawn ~= nil and spawn:IsA("SpawnLocation") then
		spawnLocationInstance = spawn
		return spawn
	end

	local fallback = Instance.new("SpawnLocation")
	fallback.Name = Config.SpawnName
	fallback.CFrame = CFrame.new(0, 1, -34)
	fallback.Parent = shell
	spawnLocationInstance = fallback
	return fallback
end

function WorkshopService.GetToolRackCFrame(): CFrame
	return CFrame.new(28, 0, -18) * CFrame.Angles(0, math.rad(-90), 0)
end

function WorkshopService.GetWorkbenchCFrame(): CFrame
	return CFrame.new(-28, 0, -18) * CFrame.Angles(0, math.rad(90), 0)
end

return table.freeze(WorkshopService)
