--!strict

--[[
	SaveTheDuckLevel

	Builds the experiment-specific geometry for Experiment 001: SAVE THE DUCK
	inside Workshop.ExperimentBay.

	The layout:
		* Floor slabs on either side of a 14-stud gap
		* Pit trench 4 studs deep below
		* Start pad and goal pad with painted borders
		* Duck payload and goal button
		* Staged parts with world-space count labels
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

local SaveTheDuckLevel = {}

export type Built = {
	Handles: ExperimentTypes.LevelHandles,
	Staged: { ExperimentTypes.StagedComponent },
	Workshop: Instance,
}

local COLORS = {
	Floor = Color3.fromRGB(88, 80, 70),
	Pit = Color3.fromRGB(44, 40, 36),
	Pad = Color3.fromRGB(140, 122, 96),
	Tape = Color3.fromRGB(248, 210, 60),
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Level 001] %s", message))
	end
end

-- Environment -----------------------------------------------------------------

local function buildFloor(bay: Instance, geometry: ExperimentTypes.LevelGeometry)
	local floorSize = geometry.FloorSize
	local halfDepth = floorSize.Z * 0.5

	-- Two slabs with a trench between them, plus the trench floor below.
	local gapNear = geometry.StartPadCenter.Z + geometry.StartPadSize.Z * 0.5
	local gapFar = geometry.GoalPadCenter.Z - geometry.GoalPadSize.Z * 0.5

	local nearDepth = halfDepth + gapNear
	local near = Util.CreatePart(
		"FloorNear",
		Vector3.new(floorSize.X, floorSize.Y, nearDepth),
		CFrame.new(Vector3.new(0, geometry.FloorCenter.Y, gapNear - nearDepth * 0.5)),
		bay
	)
	Util.StylePart(near, COLORS.Floor, Enum.Material.Concrete)

	local farDepth = halfDepth - gapFar
	local far = Util.CreatePart(
		"FloorFar",
		Vector3.new(floorSize.X, floorSize.Y, farDepth),
		CFrame.new(Vector3.new(0, geometry.FloorCenter.Y, gapFar + farDepth * 0.5)),
		bay
	)
	Util.StylePart(far, COLORS.Floor, Enum.Material.Concrete)

	local pit = Util.CreatePart(
		"PitFloor",
		Vector3.new(floorSize.X, floorSize.Y, (gapFar - gapNear) + 16),
		CFrame.new(
			Vector3.new(0, geometry.PitFloorTopY - floorSize.Y * 0.5, (gapNear + gapFar) * 0.5)
		),
		bay
	)
	Util.StylePart(pit, COLORS.Pit, Enum.Material.Slate)

	log(string.format("Trench spans %.1f studs between the pads", gapFar - gapNear))
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

	-- Painted boundary
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

-- Build -----------------------------------------------------------------------

function SaveTheDuckLevel.Build(
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
	Util.CreateBuildBounds(geometry.BuildBoundsCenter, geometry.BuildBoundsSize, bay)

	local duck = Util.CreateDuck(definition.Payload, geometry.DuckSpawn, bay)
	local goal, cap, trigger = Util.CreateGoalButton(geometry.ButtonPosition, bay)

	if RunService:IsStudio() then
		if duck.PrimaryPart == nil then
			warn("[WZ] Diagnostic: Duck has no PrimaryPart after build")
		end
		if trigger.Parent == nil then
			warn("[WZ] Diagnostic: GoalTrigger has no parent after build")
		end
	end

	local duckSpawn = CFrame.new(geometry.DuckSpawn)

	ComponentFactory.SetRuntime(bay)
	local staged = Util.StageParts(definition, bay)

	if RunService:IsStudio() then
		if #staged == 0 then
			warn("[WZ] Diagnostic: zero staged components - check Inventory definition")
		end
		if bay:FindFirstChild("BuildBounds", true) == nil then
			warn("[WZ] Diagnostic: BuildBounds part is missing from ExperimentBay")
		end
	end

	local handles: ExperimentTypes.LevelHandles = {
		Workshop = bay,
		Duck = duck,
		DuckSpawn = duckSpawn,
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

return table.freeze(SaveTheDuckLevel)
