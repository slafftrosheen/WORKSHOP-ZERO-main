--!strict

--[[
	OpenWorkshopLevel

	Builds the free-build bay inside Workshop.ExperimentBay: a flat floor, one
	wide wooden pad, the duck, and every component type staged on it.

	There is no trench, no gap and no goal button, so nothing here can be
	solved or failed - which is the entire point of the place.

	Everything is built with the same shared helpers the numbered experiments
	use, so the ground behaves identically in both.
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

local OpenWorkshopLevel = {}

export type Built = {
	Workshop: Instance,
	Duck: Model,
	DuckSpawn: CFrame,
	Center: Vector3,
	Staged: { ExperimentTypes.StagedComponent },
}

local COLORS = {
	Floor = Color3.fromRGB(88, 80, 70),
	Pad = Color3.fromRGB(140, 122, 96),
	Tape = Color3.fromRGB(248, 210, 60),
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ OpenWorkshop] %s", message))
	end
end

-- One wooden floor marking, tape painted round the edge, so the bay reads as
-- "build here" without being a platform to fall off.
local function buildPad(bay: Instance, size: Vector3, center: Vector3)
	local pad = Util.CreatePart("BuildPad", size, CFrame.new(center), bay)
	Util.StylePart(pad, COLORS.Pad, Enum.Material.WoodPlanks)

	local top = center.Y + size.Y * 0.5 + 0.06
	local inset = 0.6
	local thickness = 0.35
	local alongX = size.X * 0.5 - inset
	local alongZ = size.Z * 0.5 - inset

	local function tape(partName: string, barSize: Vector3, position: Vector3)
		local bar = Util.CreatePart(partName, barSize, CFrame.new(position), bay)
		Util.StylePart(bar, COLORS.Tape, Enum.Material.SmoothPlastic)
		bar.CanCollide = false
		bar.CanQuery = false
		bar.CanTouch = false
		bar.CastShadow = false
	end

	tape(
		"PadTapeFar",
		Vector3.new(size.X - inset * 2, 0.12, thickness),
		Vector3.new(center.X, top, center.Z - alongZ)
	)
	tape(
		"PadTapeNear",
		Vector3.new(size.X - inset * 2, 0.12, thickness),
		Vector3.new(center.X, top, center.Z + alongZ)
	)
	tape(
		"PadTapeLeft",
		Vector3.new(thickness, 0.12, alongZ * 2),
		Vector3.new(center.X - alongX, top, center.Z)
	)
	tape(
		"PadTapeRight",
		Vector3.new(thickness, 0.12, alongZ * 2),
		Vector3.new(center.X + alongX, top, center.Z)
	)
end

function OpenWorkshopLevel.Build(
	definition: ExperimentTypes.ExperimentDefinition,
	optionalBay: Instance?
): Built?
	local bay: Instance = optionalBay or WorkshopService.GetExperimentBay()
	bay:ClearAllChildren()
	bay:SetAttribute(Config.AttributeExperiment, definition.Id)

	local geometry = definition.Geometry

	local floor =
		Util.CreatePart("Floor", geometry.FloorSize, CFrame.new(geometry.FloorCenter), bay)
	Util.StylePart(floor, COLORS.Floor, Enum.Material.Concrete)

	buildPad(bay, geometry.StartPadSize, geometry.StartPadCenter)

	Util.CreateBuildBounds(geometry.BuildBoundsCenter, geometry.BuildBoundsSize, bay)

	-- The duck is a toy here, not a challenge: it exists to be launched, and
	-- with no goal button it can never finish anything.
	local duck = Util.CreateDuck(definition.Payload, geometry.DuckSpawn, bay)

	ComponentFactory.SetRuntime(bay)
	local staged = Util.StageParts(definition, bay)

	if RunService:IsStudio() then
		if #staged == 0 then
			warn("[WZ] Diagnostic: zero staged components in Open Workshop")
		end
		if bay:FindFirstChild("BuildBounds", true) == nil then
			warn("[WZ] Diagnostic: BuildBounds is missing from Open Workshop")
		end
		if duck.PrimaryPart == nil then
			warn("[WZ] Diagnostic: Duck has no PrimaryPart in Open Workshop")
		end
	end

	log(string.format("Open Workshop loaded with %d staged part(s)", #staged))

	return {
		Workshop = bay,
		Duck = duck,
		DuckSpawn = CFrame.new(geometry.DuckSpawn),
		Center = Vector3.new(0, 0, geometry.StartPadCenter.Z),
		Staged = staged,
	}
end

return table.freeze(OpenWorkshopLevel)
