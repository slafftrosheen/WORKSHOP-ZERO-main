--!strict

--[[
	MakeRoomLevel

	Builds Workspace.Workshop for Experiment 009: MAKE ROOM inside
	Workshop.ExperimentBay.

	Geometry layout:
		* Start staging area at Z = -20, where cart is built and duck starts.
		* Track bounded by guide walls leading forward to an obstacle zone.
		* Side bay recess on the right side (+X) at Z = 0.
		* Static mounting anchor block on the left wall (-X) facing the obstacle.
		* Heavy movable obstacle (challenge crate) at Z = 0 blocking the track.
		* Goal pad and goal button beyond the obstacle at Z = 16.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local ExperimentLevelUtil = require(script.Parent.ExperimentLevelUtil)
local WorkshopService = require(script.Parent.Parent.world.WorkshopService)

local Util = ExperimentLevelUtil
local COLORS = Util.COLORS

local MakeRoomLevel = {}

export type Built = {
	Handles: ExperimentTypes.LevelHandles & {
		Obstacle: BasePart,
		ObstacleStartCFrame: CFrame,
	},
	Staged: { ExperimentTypes.StagedComponent },
	Workshop: Instance,
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Level 009] %s", message))
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

local function buildTrackWalls(bay: Instance)
	-- Continuous Left Guide Wall
	local wallLeft =
		Util.CreatePart("WallLeft", Vector3.new(1.2, 4.0, 42), CFrame.new(-6.8, 2.0, -2), bay)
	Util.StylePart(wallLeft, Color3.fromRGB(58, 62, 70), Enum.Material.Concrete)

	-- Right Guide Wall - Front section (Z: -22 to -4.5)
	local wallRightA = Util.CreatePart(
		"WallRightFront",
		Vector3.new(1.2, 4.0, 17.5),
		CFrame.new(6.8, 2.0, -13.25),
		bay
	)
	Util.StylePart(wallRightA, Color3.fromRGB(58, 62, 70), Enum.Material.Concrete)

	-- Right Guide Wall - Back section (Z: 4.5 to 22)
	local wallRightB = Util.CreatePart(
		"WallRightBack",
		Vector3.new(1.2, 4.0, 17.5),
		CFrame.new(6.8, 2.0, 13.25),
		bay
	)
	Util.StylePart(wallRightB, Color3.fromRGB(58, 62, 70), Enum.Material.Concrete)

	-- Side Bay (Right side alcove from X: 6.8 to 15.0, Z: -4.5 to 4.5)
	-- Side Bay Back Wall
	local bayBack =
		Util.CreatePart("SideBayBack", Vector3.new(1.2, 4.0, 9.0), CFrame.new(15.0, 2.0, 0), bay)
	Util.StylePart(bayBack, Color3.fromRGB(58, 62, 70), Enum.Material.Concrete)

	-- Side Bay North Wall
	local bayNorth = Util.CreatePart(
		"SideBayNorth",
		Vector3.new(8.0, 4.0, 1.2),
		CFrame.new(11.0, 2.0, -4.5),
		bay
	)
	Util.StylePart(bayNorth, Color3.fromRGB(58, 62, 70), Enum.Material.Concrete)

	-- Side Bay South Wall
	local baySouth =
		Util.CreatePart("SideBaySouth", Vector3.new(8.0, 4.0, 1.2), CFrame.new(11.0, 2.0, 4.5), bay)
	Util.StylePart(baySouth, Color3.fromRGB(58, 62, 70), Enum.Material.Concrete)

	-- Side Bay Floor Indicator
	local bayFloor =
		Util.CreatePart("SideBayFloor", Vector3.new(7.0, 0.05, 7.8), CFrame.new(10.9, 0.03, 0), bay)
	Util.StylePart(bayFloor, Color3.fromRGB(40, 75, 55), Enum.Material.SmoothPlastic)

	-- End safety barrier wall
	local backStop = Util.CreatePart("BackStop", Vector3.new(16, 6, 2), CFrame.new(0, 3, 22), bay)
	Util.StylePart(backStop, Color3.fromRGB(48, 52, 60), Enum.Material.Concrete)
end

--[[
	Creates the heavy movable challenge obstacle.
	It is NOT a draggable component. It is an unanchored physics body during TEST
	and anchored during BUILD.
]]
local function buildObstacle(bay: Instance, startCFrame: CFrame): BasePart
	local crate = Instance.new("Part")
	crate.Name = "MovableObstacle"
	crate.Shape = Enum.PartType.Block
	crate.Size = Vector3.new(3.8, 3.8, 3.8)
	crate.CFrame = startCFrame
	crate.Anchored = true
	crate.CanCollide = true
	crate.CanTouch = true
	crate.CanQuery = true
	crate.CastShadow = true
	crate.TopSurface = Enum.SurfaceType.Smooth
	crate.BottomSurface = Enum.SurfaceType.Smooth
	crate.Color = Color3.fromRGB(165, 115, 65)
	crate.Material = Enum.Material.WoodPlanks
	crate.CustomPhysicalProperties = PhysicalProperties.new(1.4, 0.35, 0.05)
	crate.CollisionGroup = "WorkshopComponents"
	crate:SetAttribute("WZ_ChallengeObstacle", true)
	crate.Parent = bay

	-- Metal corner reinforcements
	local band = Instance.new("Part")
	band.Name = "CrateBanding"
	band.Shape = Enum.PartType.Block
	band.Size = Vector3.new(3.85, 0.6, 3.85)
	band.CFrame = startCFrame
	band.Anchored = true
	band.CanCollide = false
	band.CanTouch = false
	band.CanQuery = false
	band.Color = Color3.fromRGB(70, 75, 85)
	band.Material = Enum.Material.Metal
	band.CollisionGroup = "WorkshopComponents"
	band.Parent = crate

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = crate
	weld.Part1 = band
	weld.Parent = band

	return crate
end

function MakeRoomLevel.Build(
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

	buildTrackWalls(bay)

	-- Static anchor block on the left wall facing the obstacle
	ComponentFactory.SetRuntime(bay)
	local anchorPivot = CFrame.new(-4.8, 1.8, 0)
	local wallAnchorModel = ComponentFactory.Create("Block", anchorPivot)
	if wallAnchorModel ~= nil then
		wallAnchorModel:SetAttribute("WZ_StaticAnchor", true)
		local root = wallAnchorModel.PrimaryPart
		if root ~= nil then
			root.Anchored = true
		end
	end

	-- Movable obstacle blocking the center of the track at Z = 0
	local obstacleStartCFrame = CFrame.new(0, 1.9, 0)
	local obstacle = buildObstacle(bay, obstacleStartCFrame)

	Util.CreateBuildBounds(geometry.BuildBoundsCenter, geometry.BuildBoundsSize, bay)

	local duck = Util.CreateDuck(definition.Payload, geometry.DuckSpawn, bay)
	local goal, cap, trigger = Util.CreateGoalButton(geometry.ButtonPosition, bay)

	duck.Parent = bay
	goal.Parent = bay

	local staged = Util.StageParts(definition, bay)

	log(string.format("Level 009 built: %d staged components", #staged))

	return {
		Handles = {
			Workshop = bay,
			Duck = duck,
			DuckSpawn = CFrame.new(geometry.DuckSpawn),
			Goal = goal,
			GoalCap = cap,
			GoalTrigger = trigger,
			Center = Vector3.new(0, 0, (geometry.DuckSpawn.Z + geometry.ButtonPosition.Z) * 0.5),
			Obstacle = obstacle,
			ObstacleStartCFrame = obstacleStartCFrame,
		},
		Staged = staged,
		Workshop = bay,
	}
end

return table.freeze(MakeRoomLevel)
