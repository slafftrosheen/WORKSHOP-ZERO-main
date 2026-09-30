--!strict

--[[
	UphillDeliveryLevel

	Builds Workspace.Workshop for Experiment 002: UPHILL DELIVERY inside
	Workshop.ExperimentBay.

	Geometry layout:
		* Lower start pad at ground level where the machine is built.
		* Duck starts at the lower area.
		* A clear 23-stud incline ramp rising 10 studs up to an elevated goal platform.
		* Wide ramp (~22 studs) so machine design, not steering precision, is tested.
		* Goal button sits atop the upper platform.
		* Solid support structures anchor the ramp and platform to the workshop floor.
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

local UphillDeliveryLevel = {}

export type Built = {
	Handles: ExperimentTypes.LevelHandles,
	Staged: { ExperimentTypes.StagedComponent },
	Workshop: Instance,
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Level 002] %s", message))
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

	-- Painted boundary tape
	local top = center.Y + size.Y * 0.5 + 0.06
	local inset = 0.6
	local thickness = 0.35
	local alongX = size.X * 0.5 - inset
	local alongZ = size.Z * 0.5 - inset

	local function tape(partName: string, barSize: Vector3, position: Vector3)
		local bar = Util.CreatePart(partName, barSize, CFrame.new(position), bay)
		Util.StylePart(bar, tapeColor, Enum.Material.SmoothPlastic)
		bar.CanCollide = false
		bar.CanQuery = false
		bar.CanTouch = false
		bar.CastShadow = false
	end

	tape(
		name .. "TapeFar",
		Vector3.new(size.X - inset * 2, 0.12, thickness),
		Vector3.new(center.X, top, center.Z - alongZ)
	)
	tape(
		name .. "TapeNear",
		Vector3.new(size.X - inset * 2, 0.12, thickness),
		Vector3.new(center.X, top, center.Z + alongZ)
	)
	tape(
		name .. "TapeLeft",
		Vector3.new(thickness, 0.12, alongZ * 2),
		Vector3.new(center.X - alongX, top, center.Z)
	)
	tape(
		name .. "TapeRight",
		Vector3.new(thickness, 0.12, alongZ * 2),
		Vector3.new(center.X + alongX, top, center.Z)
	)
end

local function buildInclineAndPlatform(
	bay: Instance,
	startPadCenter: Vector3,
	startPadSize: Vector3,
	goalPadCenter: Vector3,
	goalPadSize: Vector3
)
	-- Start of ramp meets start pad far edge:
	local rampStartZ = startPadCenter.Z + startPadSize.Z * 0.5
	local rampStartY = startPadCenter.Y + startPadSize.Y * 0.5

	-- End of ramp meets goal pad near edge:
	local rampEndZ = goalPadCenter.Z - goalPadSize.Z * 0.5
	local rampEndY = goalPadCenter.Y + goalPadSize.Y * 0.5

	local deltaZ = rampEndZ - rampStartZ
	local deltaY = rampEndY - rampStartY
	local slopeAngle = math.atan2(deltaY, deltaZ)
	local rampLength = math.sqrt(deltaZ * deltaZ + deltaY * deltaY)
	local rampWidth = 22
	local rampThickness = 0.8

	local rampMidY = (rampStartY + rampEndY) * 0.5
	local rampMidZ = (rampStartZ + rampEndZ) * 0.5
	local rampCFrame = CFrame.new(0, rampMidY, rampMidZ) * CFrame.Angles(-slopeAngle, 0, 0)

	-- The main ramp driving surface
	local ramp = Util.CreatePart(
		"InclineRamp",
		Vector3.new(rampWidth, rampThickness, rampLength),
		rampCFrame,
		bay
	)
	Util.StylePart(ramp, COLORS.Ramp, Enum.Material.WoodPlanks)

	-- Side curbs on the ramp so carts have a guide rail
	local curbThickness = 0.5
	local curbHeight = 0.9
	for _, xSide in { -1, 1 } do
		local curbX = xSide * (rampWidth * 0.5 - curbThickness * 0.5)
		local curbCFrame = rampCFrame * CFrame.new(curbX, (rampThickness + curbHeight) * 0.5, 0)
		local curb = Util.CreatePart(
			string.format("RampCurb_%d", xSide),
			Vector3.new(curbThickness, curbHeight, rampLength),
			curbCFrame,
			bay
		)
		Util.StylePart(curb, COLORS.Tape, Enum.Material.SmoothPlastic)
	end

	-- Solid foundation pillars under the elevated goal platform
	local foundationHeight = goalPadCenter.Y - 0.3
	local foundationCenter = Vector3.new(goalPadCenter.X, foundationHeight * 0.5, goalPadCenter.Z)
	local foundation = Util.CreatePart(
		"GoalPlatformFoundation",
		Vector3.new(goalPadSize.X - 1, foundationHeight, goalPadSize.Z - 1),
		CFrame.new(foundationCenter),
		bay
	)
	Util.StylePart(foundation, COLORS.Pit, Enum.Material.Concrete)

	-- Under-ramp support block so the ramp is physically anchored
	local supportCenter = Vector3.new(0, rampMidY * 0.45, rampMidZ + 2)
	local support = Util.CreatePart(
		"RampUnderSupport",
		Vector3.new(rampWidth - 2, rampMidY * 0.9, deltaZ * 0.65),
		CFrame.new(supportCenter),
		bay
	)
	Util.StylePart(support, COLORS.Pit, Enum.Material.Slate)
end

-- Level construction ---------------------------------------------------------

function UphillDeliveryLevel.Build(
	definition: ExperimentTypes.ExperimentDefinition,
	optionalBay: Instance?
): Built?
	local bay: Instance = optionalBay or WorkshopService.GetExperimentBay()
	bay:ClearAllChildren()
	bay:SetAttribute(Config.AttributeExperiment, definition.Id)

	local geometry = definition.Geometry

	buildFloor(bay, geometry)
	buildPad(bay, "StartPad", geometry.StartPadSize, geometry.StartPadCenter, COLORS.Tape)
	buildPad(bay, "GoalPad", geometry.GoalPadSize, geometry.GoalPadCenter, COLORS.Tape)
	buildInclineAndPlatform(
		bay,
		geometry.StartPadCenter,
		geometry.StartPadSize,
		geometry.GoalPadCenter,
		geometry.GoalPadSize
	)
	Util.CreateBuildBounds(geometry.BuildBoundsCenter, geometry.BuildBoundsSize, bay)

	local duck = Util.CreateDuck(definition.Payload, geometry.DuckSpawn, bay)
	local goal, cap, trigger = Util.CreateGoalButton(geometry.ButtonPosition, bay)

	local duckSpawn = CFrame.new(geometry.DuckSpawn)

	ComponentFactory.SetRuntime(bay)
	local staged = Util.StageParts(definition, bay)

	local handles: ExperimentTypes.LevelHandles = {
		Workshop = bay,
		Duck = duck,
		DuckSpawn = duckSpawn,
		Goal = goal,
		GoalTrigger = trigger,
		GoalCap = cap,
		Center = Vector3.new(0, 5, (geometry.DuckSpawn.Z + geometry.ButtonPosition.Z) * 0.5),
	}

	log(string.format("%s loaded in ExperimentBay with %d staged parts", definition.Name, #staged))

	return {
		Handles = handles,
		Staged = staged,
		Workshop = bay,
	}
end

return table.freeze(UphillDeliveryLevel)
