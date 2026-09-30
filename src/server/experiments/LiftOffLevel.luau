--!strict

--[[
	LiftOffLevel

	Builds Workspace.Workshop for Experiment 005: LIFT OFF inside
	Workshop.ExperimentBay.

	Geometry layout:
		* Start staging area at Z = -16, where duck starts at Z = -12.
		* High platform raised ~14.4 studs above floor at Z = 14, supported
		  by industrial structural pillars.
		* Overhead Gantry frame spanning between X = -14 and X = 14 at Y = 24.
		* Prebuilt static Hook components mounted in the gantry ceiling with
		  downward-facing rope eyelets for crane / hoist rigging.
		* Goal button resting atop the high platform.
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

local LiftOffLevel = {}

export type Built = {
	Handles: ExperimentTypes.LevelHandles,
	Staged: { ExperimentTypes.StagedComponent },
	Workshop: Instance,
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Level 005] %s", message))
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

local function buildHighPlatform(bay: Instance, geometry: ExperimentTypes.LevelGeometry)
	local padCenter = geometry.GoalPadCenter
	local padSize = geometry.GoalPadSize

	-- Build high platform surface
	buildPad(bay, "HighPlatform", padSize, padCenter, Color3.fromRGB(240, 180, 40))

	-- Four heavy support pillars holding up the platform
	local halfX = (padSize.X * 0.5) - 1.2
	local halfZ = (padSize.Z * 0.5) - 1.2
	local pillarHeight = padCenter.Y - (padSize.Y * 0.5)
	local pillarY = pillarHeight * 0.5

	local pillarOffsets = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, halfZ),
	}

	for i, offset in pillarOffsets do
		local pillar = Util.CreatePart(
			string.format("Pillar_%d", i),
			Vector3.new(1.4, pillarHeight, 1.4),
			CFrame.new(padCenter.X + offset.X, pillarY, padCenter.Z + offset.Z),
			bay
		)
		Util.StylePart(pillar, Color3.fromRGB(60, 65, 75), Enum.Material.Metal)

		-- Top mounting bracket
		local cap = Util.CreatePart(
			string.format("PillarCap_%d", i),
			Vector3.new(2, 0.4, 2),
			CFrame.new(padCenter.X + offset.X, pillarHeight - 0.2, padCenter.Z + offset.Z),
			bay
		)
		Util.StylePart(cap, Color3.fromRGB(210, 160, 30), Enum.Material.Metal)
	end

	-- Safety rail around back and sides of platform
	local railHeight = 1.6
	local railThickness = 0.3
	local railY = padCenter.Y + (padSize.Y * 0.5) + (railHeight * 0.5)

	-- Back rail
	local backRail = Util.CreatePart(
		"PlatformBackRail",
		Vector3.new(padSize.X, railHeight, railThickness),
		CFrame.new(padCenter.X, railY, padCenter.Z + padSize.Z * 0.5 - railThickness * 0.5),
		bay
	)
	Util.StylePart(backRail, Color3.fromRGB(80, 85, 95), Enum.Material.Metal)

	-- Left and right rails
	for _, sign in { -1, 1 } do
		local sideRail = Util.CreatePart(
			"PlatformSideRail",
			Vector3.new(railThickness, railHeight, padSize.Z),
			CFrame.new(
				padCenter.X + sign * (padSize.X * 0.5 - railThickness * 0.5),
				railY,
				padCenter.Z
			),
			bay
		)
		Util.StylePart(sideRail, Color3.fromRGB(80, 85, 95), Enum.Material.Metal)
	end
end

local function buildGantry(bay: Instance): { Model }
	local gantryHooks: { Model } = {}
	local gantryY = 23
	local gantryHeight = 24
	local halfSpanX = 14

	-- Upright gantry columns on left and right
	for _, x in { -halfSpanX, halfSpanX } do
		for _, z in { -8, 8 } do
			local col = Util.CreatePart(
				"GantryColumn",
				Vector3.new(1.6, gantryHeight, 1.6),
				CFrame.new(x, gantryHeight * 0.5, z),
				bay
			)
			Util.StylePart(col, Color3.fromRGB(50, 54, 64), Enum.Material.Metal)
		end

		-- Longitudinal header beam connecting front and back columns
		local sideBeam = Util.CreatePart(
			"GantrySideBeam",
			Vector3.new(1.4, 1.4, 18),
			CFrame.new(x, gantryY + 0.7, 0),
			bay
		)
		Util.StylePart(sideBeam, Color3.fromRGB(220, 150, 25), Enum.Material.Metal)
	end

	-- Crossbeams spanning across the bay overhead
	local crossbeamZPositions = { -4, 4 }
	for _, z in crossbeamZPositions do
		local beam = Util.CreatePart(
			"GantryCrossbeam",
			Vector3.new(halfSpanX * 2 + 1.6, 1.2, 1.2),
			CFrame.new(0, gantryY + 0.6, z),
			bay
		)
		Util.StylePart(beam, Color3.fromRGB(70, 75, 86), Enum.Material.Metal)
	end

	-- Create prebuilt static Hook components mounted on the crossbeams with eyelets pointing downward
	local hookPositions = {
		Vector3.new(-5, gantryY, -4),
		Vector3.new(0, gantryY, 0),
		Vector3.new(5, gantryY, -4),
		Vector3.new(0, gantryY, 4),
	}

	for _, pos in hookPositions do
		-- Point Hook downward (rotate 180 degrees around Z)
		local hookPivot = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(180))
		local hookModel = ComponentFactory.CreateComponent("Hook", hookPivot)

		-- Make it a permanent static anchor
		hookModel:SetAttribute("WZ_StaticAnchor", true)
		local root = hookModel.PrimaryPart
		if root ~= nil then
			root.Anchored = true
		end

		local dd = ComponentFactory.GetDragDetector(hookModel)
		if dd ~= nil then
			dd.Enabled = false
		end

		table.insert(gantryHooks, hookModel)
	end

	return gantryHooks
end

-- Level builder --------------------------------------------------------------

function LiftOffLevel.Build(
	definition: ExperimentTypes.ExperimentDefinition,
	optionalBay: Instance?
): Built
	local bay: Instance = optionalBay or WorkshopService.GetExperimentBay()
	bay:ClearAllChildren()
	bay:SetAttribute(Config.AttributeExperiment, definition.Id)

	local geometry = definition.Geometry

	buildFloor(bay, geometry)
	buildPad(bay, "StartPad", geometry.StartPadSize, geometry.StartPadCenter, COLORS.Tape)
	buildHighPlatform(bay, geometry)
	buildGantry(bay)
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

return table.freeze(LiftOffLevel)
