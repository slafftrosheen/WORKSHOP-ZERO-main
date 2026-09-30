--!strict

--[[
	WindyBusinessLevel

	Builds Workspace.Workshop for Experiment 004: WINDY BUSINESS inside
	Workshop.ExperimentBay.

	Geometry layout:
		* Glide track: ultra-low-friction track for the duck running along Z axis
		  with low guard rails to guide aerodynamic sliding.
		* Duck starts at Z = -14 on the track.
		* Staging pad on the side (X = -14, Z = -12) with parts rack.
		* Forbidden central zone marked with hazard warning stripes.
		* Goal pad and red button at Z = 16 at the end of the track.
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

local WindyBusinessLevel = {}

export type Built = {
	Handles: ExperimentTypes.LevelHandles,
	Staged: { ExperimentTypes.StagedComponent },
	Workshop: Instance,
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Level 004] %s", message))
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

local function buildGlideTrack(bay: Instance)
	-- Low-friction polished glide track running along Z
	local trackLength = 32
	local trackCenterZ = 0.5
	local track = Util.CreatePart(
		"GlideTrack",
		Vector3.new(6.4, 0.5, trackLength),
		CFrame.new(0, 0.25, trackCenterZ),
		bay
	)
	Util.StylePart(track, Color3.fromRGB(205, 215, 228), Enum.Material.SmoothPlastic)
	-- Ultra low friction so aerodynamic fan wind effortlessly slides the duck
	track.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.02, 0.02)

	-- Guard rails along the left and right of the track
	for _, x in { -3.3, 3.3 } do
		local rail = Util.CreatePart(
			"GuardRail",
			Vector3.new(0.3, 0.6, trackLength),
			CFrame.new(x, 0.5, trackCenterZ),
			bay
		)
		Util.StylePart(rail, Color3.fromRGB(90, 96, 108), Enum.Material.Metal)
	end

	-- Forbidden central zone hazard striping between Z = -3 and Z = 3
	local hazardZone =
		Util.CreatePart("HazardZone", Vector3.new(16, 0.04, 6), CFrame.new(0, 0.02, 0), bay)
	hazardZone.CanCollide = false
	hazardZone.CanTouch = false
	hazardZone.CanQuery = false
	Util.StylePart(hazardZone, Color3.fromRGB(240, 195, 45), Enum.Material.Neon)
	hazardZone.Transparency = 0.45

	-- Hazard border lines
	for _, z in { -3, 3 } do
		local stripe =
			Util.CreatePart("HazardStripe", Vector3.new(16, 0.06, 0.4), CFrame.new(0, 0.03, z), bay)
		stripe.CanCollide = false
		stripe.CanTouch = false
		stripe.CanQuery = false
		Util.StylePart(stripe, Color3.fromRGB(40, 42, 48), Enum.Material.SmoothPlastic)
	end
end

-- Level builder --------------------------------------------------------------

function WindyBusinessLevel.Build(
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
	buildGlideTrack(bay)
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

return table.freeze(WindyBusinessLevel)
