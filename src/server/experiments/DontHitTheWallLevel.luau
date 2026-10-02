--!strict

--[[
	DontHitTheWallLevel

	Builds Workspace.Workshop for Experiment 006: DON'T HIT THE WALL inside
	Workshop.ExperimentBay.

	Geometry layout:
		* Start staging area at Z = -22, where vehicle is built and duck starts.
		* Runway track bounded by guide curbs leading forward to the goal.
		* Target zone with goal button at Z = 10.
		* High heavy crash barrier wall at Z = 22.
		* If vehicle cannot stop, it rams the crash wall.
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

local DontHitTheWallLevel = {}

export type Built = {
	Handles: ExperimentTypes.LevelHandles & {
		CrashWall: BasePart,
	},
	Staged: { ExperimentTypes.StagedComponent },
	Workshop: Instance,
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Level 006] %s", message))
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

	local border = Util.CreatePart(
		name .. "Tape",
		Vector3.new(size.X + 0.3, 0.05, size.Z + 0.3),
		CFrame.new(center.X, center.Y - size.Y * 0.5 + 0.02, center.Z),
		bay
	)
	Util.StylePart(border, tapeColor, Enum.Material.SmoothPlastic)
end

local function buildTrackCurbs(bay: Instance)
	local curbLeft =
		Util.CreatePart("CurbLeft", Vector3.new(1.2, 0.8, 48), CFrame.new(-12, 0.4, 0), bay)
	Util.StylePart(curbLeft, COLORS.Border, Enum.Material.Concrete)

	local curbRight =
		Util.CreatePart("CurbRight", Vector3.new(1.2, 0.8, 48), CFrame.new(12, 0.4, 0), bay)
	Util.StylePart(curbRight, COLORS.Border, Enum.Material.Concrete)
end

local function buildCrashWall(bay: Instance): BasePart
	local wall = Util.CreatePart("CrashWall", Vector3.new(24, 12, 4), CFrame.new(0, 6, 22), bay)
	Util.StylePart(wall, Color3.fromRGB(48, 52, 60), Enum.Material.Concrete)
	wall:SetAttribute("WZ_CrashWall", true)

	-- Hazard stripe accent bar across the front
	local stripe =
		Util.CreatePart("HazardBar", Vector3.new(24, 1.6, 0.4), CFrame.new(0, 4, 19.8), bay)
	Util.StylePart(stripe, Color3.fromRGB(240, 185, 40), Enum.Material.Neon)

	return wall
end

function DontHitTheWallLevel.Build(
	definition: ExperimentTypes.ExperimentDefinition,
	optionalBay: Instance?
): Built
	local bay: Instance = optionalBay or WorkshopService.GetExperimentBay()
	bay:ClearAllChildren()
	bay:SetAttribute(Config.AttributeExperiment, definition.Id)

	local geometry = definition.Geometry

	buildFloor(bay, geometry)
	buildTrackCurbs(bay)
	buildPad(
		bay,
		"StartPad",
		geometry.StartPadSize,
		geometry.StartPadCenter,
		Color3.fromRGB(60, 120, 240)
	)
	buildPad(
		bay,
		"GoalPad",
		geometry.GoalPadSize,
		geometry.GoalPadCenter,
		Color3.fromRGB(240, 180, 40)
	)

	local crashWall = buildCrashWall(bay)
	Util.CreateBuildBounds(geometry.BuildBoundsCenter, geometry.BuildBoundsSize, bay)

	local duck = Util.CreateDuck(definition.Payload, geometry.DuckSpawn, bay)
	local goal, cap, trigger = Util.CreateGoalButton(geometry.ButtonPosition, bay)

	duck.Parent = bay
	goal.Parent = bay

	ComponentFactory.SetRuntime(bay)
	local staged = Util.StageParts(definition, bay)

	log(string.format("Level 006 built: %d staged components", #staged))

	return {
		Handles = {
			Workshop = bay,
			Duck = duck,
			DuckSpawn = CFrame.new(geometry.DuckSpawn),
			Goal = goal,
			GoalCap = cap,
			GoalTrigger = trigger,
			Center = Vector3.new(0, 0, (geometry.DuckSpawn.Z + geometry.ButtonPosition.Z) * 0.5),
			CrashWall = crashWall,
		},
		Staged = staged,
		Workshop = bay,
	}
end

return table.freeze(DontHitTheWallLevel)
