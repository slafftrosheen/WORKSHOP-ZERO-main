--!strict

--[[
	OverTheWallLevel

	Builds Workspace.Workshop for Experiment 003: OVER THE WALL inside
	Workshop.ExperimentBay.

	Geometry layout:
		* Start pad at ground level where the machine is constructed.
		* Duck starts on the start pad.
		* A tall obstacle wall (12 studs high, 28 studs wide, 4 studs thick)
		  dividing the playfield.
		* Goal pad and red button sit behind the wall.
		* Staging racks with Planks, Blocks, Wheels, 1 Motor, and 2 Springs.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local ExperimentLevelUtil = require(script.Parent.ExperimentLevelUtil)
local WorkshopService = require(script.Parent.Parent.world.WorkshopService)

local Config = ConstructionConfig
local Util = ExperimentLevelUtil
local COLORS = Util.COLORS

local OverTheWallLevel = {}

export type Built = {
	Handles: ExperimentTypes.LevelHandles,
	Staged: { ExperimentTypes.StagedComponent },
	Workshop: Instance,
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Level 003] %s", message))
	end
end

-- Layout builders ------------------------------------------------------------

local function buildFloor(bay: Instance, geometry: ExperimentTypes.LevelGeometry)
	local floor =
		Util.CreatePart("Floor", geometry.FloorSize, CFrame.new(geometry.FloorCenter), bay)
	Util.StylePart(floor, COLORS.Floor, Enum.Material.Concrete)
end

local function buildPad(
	bay: Instance,
	name: string,
	size: Vector3,
	center: Vector3,
	tapeColor: Color3
)
	local pad = Util.CreatePart(name, size, CFrame.new(center), bay)
	Util.StylePart(pad, COLORS.Pad, Enum.Material.WoodPlanks)

	-- Tape border along edge
	local border = Util.CreatePart(
		name .. "Tape",
		Vector3.new(size.X + 0.3, 0.05, size.Z + 0.3),
		CFrame.new(center.X, center.Y - size.Y * 0.5 + 0.02, center.Z),
		bay
	)
	Util.StylePart(border, tapeColor, Enum.Material.SmoothPlastic)
end

local function buildWall(bay: Instance)
	local wallCenter = Vector3.new(0, 6, 0)
	local wallSize = Vector3.new(28, 12, 4)

	local wall = Util.CreatePart("WallObstacle", wallSize, CFrame.new(wallCenter), bay)
	Util.StylePart(wall, Color3.fromRGB(115, 110, 105), Enum.Material.Concrete)
	wall:SetAttribute("WZ_WallObstacle", true)

	-- Top coping stone / ledge
	local coping =
		Util.CreatePart("WallCoping", Vector3.new(30, 0.8, 5), CFrame.new(0, 12.4, 0), bay)
	Util.StylePart(coping, Color3.fromRGB(85, 82, 80), Enum.Material.SmoothPlastic)

	-- Side pillars / buttresses
	for _, x in { -13.5, 13.5 } do
		local pillar =
			Util.CreatePart("WallPillar", Vector3.new(2, 13, 5), CFrame.new(x, 6.5, 0), bay)
		Util.StylePart(pillar, Color3.fromRGB(75, 78, 85), Enum.Material.Metal)
	end
end

-- Level builder --------------------------------------------------------------

function OverTheWallLevel.Build(
	definition: ExperimentTypes.ExperimentDefinition,
	optionalBay: Instance?
): Built
	local bay: Instance = optionalBay or WorkshopService.GetExperimentBay()
	bay:ClearAllChildren()
	bay:SetAttribute(Config.AttributeExperiment, definition.Id)

	local geometry = definition.Geometry

	buildFloor(bay, geometry)
	buildPad(bay, "StartPad", geometry.StartPadSize, geometry.StartPadCenter, COLORS.Tape)
	buildPad(bay, "GoalPad", geometry.GoalPadSize, geometry.GoalPadCenter, COLORS.Tape)
	buildWall(bay)
	Util.CreateBuildBounds(geometry.BuildBoundsCenter, geometry.BuildBoundsSize, bay)

	local duck = Util.CreateDuck(definition.Payload, geometry.DuckSpawn, bay)
	local goal, cap, trigger = Util.CreateGoalButton(geometry.ButtonPosition, bay)

	duck.Parent = bay
	goal.Parent = bay

	ComponentFactory.SetRuntime(bay)
	local staged = Util.StageParts(definition, bay)

	local handles: ExperimentTypes.LevelHandles = {
		Workshop = bay,
		Duck = duck,
		DuckSpawn = CFrame.new(geometry.DuckSpawn),
		Goal = goal,
		GoalTrigger = trigger,
		GoalCap = cap,
		Center = Vector3.new(0, 0, (geometry.DuckSpawn.Z + geometry.ButtonPosition.Z) * 0.5),
	}

	log(string.format("%s loaded in ExperimentBay with %d staged parts", definition.Name, #staged))

	return {
		Handles = handles,
		Staged = staged,
		Workshop = bay,
	}
end

return table.freeze(OverTheWallLevel)
