--!strict

--[[
	OverTheWallLevel

	Builds Workspace.Workshop for Experiment 003: OVER THE WALL.

	Geometry layout:
		* Start pad at ground level where the machine is constructed.
		* Duck starts on the start pad.
		* A tall obstacle wall (12 studs high, 28 studs wide, 4 studs thick)
		  dividing the playfield.
		* Goal pad and red button sit behind the wall.
		* Staging racks with Planks, Blocks, Wheels, 1 Motor, and 2 Springs.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local ExperimentLevelUtil = require(script.Parent.ExperimentLevelUtil)

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

local function buildFloor(workshop: Instance, geometry: ExperimentTypes.LevelGeometry)
	local floor =
		Util.CreatePart("Floor", geometry.FloorSize, CFrame.new(geometry.FloorCenter), workshop)
	Util.StylePart(floor, COLORS.Floor, Enum.Material.Concrete)
end

local function buildPad(
	workshop: Instance,
	name: string,
	size: Vector3,
	center: Vector3,
	tapeColor: Color3
)
	local pad = Util.CreatePart(name, size, CFrame.new(center), workshop)
	Util.StylePart(pad, COLORS.Pad, Enum.Material.WoodPlanks)

	-- Tape border along edge
	local border = Util.CreatePart(
		name .. "Tape",
		Vector3.new(size.X + 0.3, 0.05, size.Z + 0.3),
		CFrame.new(center.X, center.Y - size.Y * 0.5 + 0.02, center.Z),
		workshop
	)
	Util.StylePart(border, tapeColor, Enum.Material.SmoothPlastic)
end

local function buildWall(workshop: Instance)
	local wallCenter = Vector3.new(0, 6, 0)
	local wallSize = Vector3.new(28, 12, 4)

	local wall = Util.CreatePart("WallObstacle", wallSize, CFrame.new(wallCenter), workshop)
	Util.StylePart(wall, Color3.fromRGB(115, 110, 105), Enum.Material.Concrete)
	wall:SetAttribute("WZ_WallObstacle", true)

	-- Top coping stone / ledge
	local coping =
		Util.CreatePart("WallCoping", Vector3.new(30, 0.8, 5), CFrame.new(0, 12.4, 0), workshop)
	Util.StylePart(coping, Color3.fromRGB(85, 82, 80), Enum.Material.SmoothPlastic)

	-- Side pillars / buttresses
	for _, x in { -13.5, 13.5 } do
		local pillar =
			Util.CreatePart("WallPillar", Vector3.new(2, 13, 5), CFrame.new(x, 6.5, 0), workshop)
		Util.StylePart(pillar, Color3.fromRGB(75, 78, 85), Enum.Material.Metal)
	end
end

local function buildDressing(workshop: Instance, geometry: ExperimentTypes.LevelGeometry)
	local wall = Util.CreatePart(
		"BackWall",
		geometry.BackWallSize,
		CFrame.new(geometry.BackWallCenter),
		workshop
	)
	Util.StylePart(wall, COLORS.Wall, Enum.Material.WoodPlanks)

	for _, shelfY in { 8, 16 } do
		local shelf = Util.CreatePart(
			"Shelf",
			Vector3.new(36, 0.6, 3),
			CFrame.new(0, shelfY, geometry.BackWallCenter.Z + 2),
			workshop
		)
		Util.StylePart(shelf, COLORS.Shelf, Enum.Material.Wood)

		for _, crateX in { -12, -4, 5, 13 } do
			local crate = Util.CreatePart(
				"Crate",
				Vector3.new(3.5, 2.5, 2.2),
				CFrame.new(crateX, shelfY + 1.5, geometry.BackWallCenter.Z + 2),
				workshop
			)
			Util.StylePart(crate, COLORS.Crate, Enum.Material.WoodPlanks)
		end
	end
end

-- Level builder --------------------------------------------------------------

function OverTheWallLevel.Build(definition: ExperimentTypes.ExperimentDefinition): Built
	local existing = Workspace:FindFirstChild(Config.AuthoredWorkshopName)
	if existing ~= nil then
		if existing:GetAttribute(Config.AttributeGenerated) == true then
			existing:Destroy()
		end
	end

	local geometry = definition.Geometry
	local workshop = Instance.new("Folder")
	workshop.Name = Config.AuthoredWorkshopName
	workshop:SetAttribute(Config.AttributeGenerated, true)
	workshop:SetAttribute(Config.AttributeExperiment, definition.Id)

	buildFloor(workshop, geometry)
	buildPad(workshop, "StartPad", geometry.StartPadSize, geometry.StartPadCenter, COLORS.Tape)
	buildPad(workshop, "GoalPad", geometry.GoalPadSize, geometry.GoalPadCenter, COLORS.Tape)
	buildWall(workshop)
	buildDressing(workshop, geometry)
	Util.CreateBuildBounds(geometry.BuildBoundsSize, geometry.BuildBoundsCenter, workshop)
	Util.CreateSpawn(geometry.PlayerSpawn, nil, workshop)

	local duck = Util.BuildDuckPayload(definition, geometry.DuckSpawn, workshop)
	local goal, cap, trigger = Util.BuildGoalButton(geometry.ButtonPosition, workshop)

	duck.Parent = workshop
	goal.Parent = workshop
	workshop.Parent = Workspace

	ComponentFactory.SetRuntime(workshop)
	local staged = Util.StageInventory(definition, workshop)

	local handles: ExperimentTypes.LevelHandles = {
		Workshop = workshop,
		Duck = duck,
		DuckSpawn = CFrame.new(geometry.DuckSpawn),
		Goal = goal,
		GoalTrigger = trigger,
		GoalCap = cap,
		Center = Vector3.new(0, 0, (geometry.DuckSpawn.Z + geometry.ButtonPosition.Z) * 0.5),
	}

	log(string.format("%s loaded with %d staged parts", definition.Name, #staged))

	return {
		Handles = handles,
		Staged = staged,
		Workshop = workshop,
	}
end

return table.freeze(OverTheWallLevel)
