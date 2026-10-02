--!strict

--[[
	OpenSesameLevel

	Builds Workspace.Workshop for Experiment 008: OPEN SESAME inside
	Workshop.ExperimentBay.

	Geometry layout:
		* Start pad at Z = -20, where the vehicle is built and duck starts.
		* Corridor bounded by side walls leading forward to the gate posts.
		* Gate posts at Z = 0 (Left and Right).
		* Static mounting anchor block on the gate post for mounting a servo or arm.
		* Goal zone with goal button beyond the gate at Z = 16.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local ExperimentLevelUtil = require(script.Parent.ExperimentLevelUtil)
local WorkshopService = require(script.Parent.Parent.world.WorkshopService)

local Util = ExperimentLevelUtil
local COLORS = Util.COLORS

local OpenSesameLevel = {}

export type Built = {
	Handles: ExperimentTypes.LevelHandles & {
		GatePostLeft: BasePart,
		GatePostRight: BasePart,
	},
	Staged: { ExperimentTypes.StagedComponent },
	Workshop: Instance,
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Level 008] %s", message))
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

local function buildCorridorWalls(bay: Instance)
	-- Left guide wall
	local wallLeft =
		Util.CreatePart("WallLeft", Vector3.new(1.2, 3.5, 42), CFrame.new(-7.5, 1.75, -2), bay)
	Util.StylePart(wallLeft, COLORS.Border or Color3.fromRGB(60, 64, 72), Enum.Material.Concrete)

	-- Right guide wall
	local wallRight =
		Util.CreatePart("WallRight", Vector3.new(1.2, 3.5, 42), CFrame.new(7.5, 1.75, -2), bay)
	Util.StylePart(wallRight, COLORS.Border or Color3.fromRGB(60, 64, 72), Enum.Material.Concrete)

	-- Back safety stop wall behind goal
	local backStop = Util.CreatePart("BackStop", Vector3.new(16, 6, 2), CFrame.new(0, 3, 22), bay)
	Util.StylePart(backStop, Color3.fromRGB(48, 52, 60), Enum.Material.Concrete)
end

local function buildGatePosts(bay: Instance): (BasePart, BasePart)
	-- Left Gate Post
	local postLeft =
		Util.CreatePart("GatePostLeft", Vector3.new(2.4, 7, 2.4), CFrame.new(-6.8, 3.5, 0), bay)
	Util.StylePart(postLeft, Color3.fromRGB(45, 50, 60), Enum.Material.Metal)

	local capLeft = Util.CreatePart(
		"GatePostLeftCap",
		Vector3.new(2.8, 0.6, 2.8),
		CFrame.new(-6.8, 7.2, 0),
		bay
	)
	Util.StylePart(capLeft, Color3.fromRGB(240, 185, 40), Enum.Material.SmoothPlastic)

	-- Right Gate Post
	local postRight =
		Util.CreatePart("GatePostRight", Vector3.new(2.4, 7, 2.4), CFrame.new(6.8, 3.5, 0), bay)
	Util.StylePart(postRight, Color3.fromRGB(45, 50, 60), Enum.Material.Metal)

	local capRight = Util.CreatePart(
		"GatePostRightCap",
		Vector3.new(2.8, 0.6, 2.8),
		CFrame.new(6.8, 7.2, 0),
		bay
	)
	Util.StylePart(capRight, Color3.fromRGB(240, 185, 40), Enum.Material.SmoothPlastic)

	-- Hazard stripes on the posts
	local stripeLeft =
		Util.CreatePart("HazardLeft", Vector3.new(2.45, 1.2, 2.45), CFrame.new(-6.8, 2, 0), bay)
	Util.StylePart(stripeLeft, Color3.fromRGB(240, 185, 40), Enum.Material.Neon)

	local stripeRight =
		Util.CreatePart("HazardRight", Vector3.new(2.45, 1.2, 2.45), CFrame.new(6.8, 2, 0), bay)
	Util.StylePart(stripeRight, Color3.fromRGB(240, 185, 40), Enum.Material.Neon)

	return postLeft, postRight
end

function OpenSesameLevel.Build(
	definition: ExperimentTypes.ExperimentDefinition,
	optionalBay: Instance?
): Built
	local bay = optionalBay or WorkshopService.GetExperimentBay()
	local geometry = definition.Geometry

	buildFloor(bay, geometry)

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

	buildCorridorWalls(bay)
	local postLeft, postRight = buildGatePosts(bay)

	-- Static anchor block on the left gate post providing rigid and axle sockets
	-- for mounting a servo or gate arm
	ComponentFactory.SetRuntime(bay)
	local gateAnchorPivot = CFrame.new(-4.8, 1.5, 0)
	local gateAnchorModel = ComponentFactory.Create("Block", gateAnchorPivot)
	if gateAnchorModel ~= nil then
		gateAnchorModel:SetAttribute("WZ_StaticAnchor", true)
		local root = gateAnchorModel.PrimaryPart
		if root ~= nil then
			root.Anchored = true
		end
	end

	Util.CreateBuildBounds(geometry.BuildBoundsCenter, geometry.BuildBoundsSize, bay)

	local duck = Util.CreateDuck(definition.Payload, geometry.DuckSpawn, bay)
	local goal, cap, trigger = Util.CreateGoalButton(geometry.ButtonPosition, bay)

	duck.Parent = bay
	goal.Parent = bay

	local staged = Util.StageParts(definition, bay)

	log(string.format("Level 008 built: %d staged components", #staged))

	return {
		Handles = {
			Workshop = bay,
			Duck = duck,
			DuckSpawn = CFrame.new(geometry.DuckSpawn),
			Goal = goal,
			GoalCap = cap,
			GoalTrigger = trigger,
			Center = Vector3.new(0, 0, (geometry.DuckSpawn.Z + geometry.ButtonPosition.Z) * 0.5),
			GatePostLeft = postLeft,
			GatePostRight = postRight,
		},
		Staged = staged,
		Workshop = bay,
	}
end

return table.freeze(OpenSesameLevel)
