--!strict

--[[
	PrototypeWorkshop

	A Studio-only engineering harness. There is no authored level yet, so this
	module builds a crude runtime sandbox to test the construction kernel:

		Workspace
		└── WorkshopZeroRuntime
		    ├── Floor          big anchored slab
		    ├── BuildBounds    visible volume a placement must stay inside
		    ├── WorkshopSpawn  where the player starts, outside the build area
		    ├── Components     2 planks, 2 blocks, 4 wheels
		    └── Connections    created later by ConnectorService

	Rules this module obeys:

		* Studio only. A live server never fabricates level geometry.
		* If Workspace.Workshop exists - a hand-authored workshop - it steps
		  aside and touches nothing.
		* It never saves anything back into the place. Runtime content lives in
		  the running session; the place file stays Studio-owned.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)

local Config = ConstructionConfig

local PrototypeWorkshop = {}

local FLOOR_SIZE = Vector3.new(160, 4, 120)
local BOUNDS_CENTER = Vector3.new(0, Config.BuildBoundsSize.Y * 0.5, 0)
local SPAWN_POSITION = Vector3.new(0, 0.5, 45)

-- Wheels are spawned already yawed 90 degrees so their axle lines up with a
-- plank or block axle socket: one less rotation before the first snap.
local WHEEL_YAW = CFrame.Angles(0, math.rad(90), 0)

type StarterComponent = {
	Type: ConstructionTypes.ComponentType,
	Pivot: CFrame,
}

local STARTER_COMPONENTS: { StarterComponent } = {
	{ Type = "Plank", Pivot = CFrame.new(-14, 3, -8) },
	{ Type = "Plank", Pivot = CFrame.new(-14, 3, 6) },
	{ Type = "Block", Pivot = CFrame.new(0, 4, -8) },
	{ Type = "Block", Pivot = CFrame.new(0, 4, 6) },
	{ Type = "Wheel", Pivot = CFrame.new(14, 4, -12) * WHEEL_YAW },
	{ Type = "Wheel", Pivot = CFrame.new(14, 4, -4) * WHEEL_YAW },
	{ Type = "Wheel", Pivot = CFrame.new(14, 4, 4) * WHEEL_YAW },
	{ Type = "Wheel", Pivot = CFrame.new(14, 4, 12) * WHEEL_YAW },
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ] %s", message))
	end
end

local function createPart(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	return part
end

local function createFloor(runtime: Instance)
	local floor =
		createPart(Config.FloorName, FLOOR_SIZE, Vector3.new(0, -FLOOR_SIZE.Y * 0.5, 0), runtime)
	floor.Color = Color3.fromRGB(48, 50, 56)
	floor.Material = Enum.Material.Concrete
end

local function createBuildBounds(runtime: Instance)
	local bounds =
		createPart(Config.BuildBoundsName, Config.BuildBoundsSize, BOUNDS_CENTER, runtime)
	bounds.Color = Color3.fromRGB(70, 130, 190)
	bounds.Material = Enum.Material.SmoothPlastic
	bounds.Transparency = 0.92
	bounds.CanCollide = false
	bounds.CanQuery = false
	bounds.CanTouch = false
	bounds.CastShadow = false
end

local function createSpawn(runtime: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = Config.SpawnName
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(120, 200, 140)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.Parent = runtime
end

--[[
	Creates the runtime sandbox when it is needed, or returns the existing one.

	Returns nil when this server should not have a runtime workshop at all:
	outside Studio, or when a hand-authored workshop is present.
]]
function PrototypeWorkshop.Setup(): Instance?
	if not RunService:IsStudio() then
		return nil
	end

	if Workspace:FindFirstChild(Config.AuthoredWorkshopName) ~= nil then
		log("Workspace.Workshop exists - the prototype harness stays out of the way")
		return nil
	end

	local existing = Workspace:FindFirstChild(Config.RuntimeFolderName)
	if existing ~= nil then
		return existing
	end

	local runtime = Instance.new("Folder")
	runtime.Name = Config.RuntimeFolderName

	createFloor(runtime)
	createBuildBounds(runtime)
	createSpawn(runtime)

	-- Published before the first component is created so ComponentFactory knows
	-- where components and connections belong.
	runtime.Parent = Workspace
	ComponentFactory.SetRuntime(runtime)

	for _, entry in STARTER_COMPONENTS do
		ComponentFactory.Create(entry.Type, entry.Pivot)
	end

	log(string.format("Runtime workshop ready with %d components", #STARTER_COMPONENTS))

	return runtime
end

return table.freeze(PrototypeWorkshop)
