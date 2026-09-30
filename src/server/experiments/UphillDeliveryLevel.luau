--!strict

--[[
	UphillDeliveryLevel

	Builds Workspace.Workshop for Experiment 002: UPHILL DELIVERY.

	Geometry layout:
		* Lower start pad at ground level where the machine is built.
		* Duck starts at the lower area (not inside the cart).
		* A clear 23-stud incline ramp rising 10 studs up to an elevated goal platform.
		* Wide ramp (~22 studs) so machine design, not steering precision, is tested.
		* Goal button sits atop the upper platform.
		* Solid support structures anchor the ramp and platform to the workshop floor.
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

	-- Painted boundary tape
	local top = center.Y + size.Y * 0.5 + 0.06
	local inset = 0.6
	local thickness = 0.35
	local alongX = size.X * 0.5 - inset
	local alongZ = size.Z * 0.5 - inset

	local function tape(partName: string, barSize: Vector3, position: Vector3)
		local bar = Util.CreatePart(partName, barSize, CFrame.new(position), workshop)
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
	workshop: Instance,
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
		workshop
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
			workshop
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
		workshop
	)
	Util.StylePart(foundation, COLORS.Pit, Enum.Material.Concrete)

	-- Under-ramp support block so the ramp is physically anchored
	local supportCenter = Vector3.new(0, rampMidY * 0.45, rampMidZ + 2)
	local support = Util.CreatePart(
		"RampUnderSupport",
		Vector3.new(rampWidth - 2, rampMidY * 0.9, deltaZ * 0.65),
		CFrame.new(supportCenter),
		workshop
	)
	Util.StylePart(support, COLORS.Pit, Enum.Material.Slate)
end

local function buildDressing(workshop: Instance, geometry: ExperimentTypes.LevelGeometry)
	-- Back wall: timber planks
	local wall = Util.CreatePart(
		"BackWall",
		geometry.BackWallSize,
		CFrame.new(geometry.BackWallCenter),
		workshop
	)
	Util.StylePart(wall, COLORS.Wall, Enum.Material.WoodPlanks)

	-- Work shelves on back wall
	local shelfZ = geometry.BackWallCenter.Z + 2.5
	for index = 1, 2 do
		local y = geometry.BackWallCenter.Y + 4 + (index - 1) * 5.5
		local shelf = Util.CreatePart(
			string.format("Shelf%d", index),
			Vector3.new(56, 0.5, 3.5),
			CFrame.new(Vector3.new(0, y, shelfZ)),
			workshop
		)
		Util.StylePart(shelf, COLORS.Shelf, Enum.Material.Wood)

		for _, slot in { -3, -2, 2, 3 } do
			local crate = Util.CreatePart(
				string.format("Crate%d_%d", index, slot),
				Vector3.new(2.8, 2.2, 2.8),
				CFrame.new(Vector3.new(slot * 7, y + 1.35, shelfZ)),
				workshop
			)
			Util.StylePart(crate, COLORS.Crate, Enum.Material.Wood)
		end
	end

	-- Workbench to the left of the start pad
	local benchX = -22
	local benchZ = -22
	local benchTopY = 3.25
	local benchTopSize = Vector3.new(10, 0.5, 5)
	local benchTop = Util.CreatePart(
		"BenchTop",
		benchTopSize,
		CFrame.new(Vector3.new(benchX, benchTopY, benchZ)),
		workshop
	)
	Util.StylePart(benchTop, COLORS.BenchTop, Enum.Material.Wood)

	local legSize = Vector3.new(0.7, 3, 0.7)
	for _, xOff in { -4.5, 4.5 } do
		for _, zOff in { -2, 2 } do
			local leg = Util.CreatePart(
				"BenchLeg",
				legSize,
				CFrame.new(Vector3.new(benchX + xOff, 1.5, benchZ + zOff)),
				workshop
			)
			Util.StylePart(leg, COLORS.Bench, Enum.Material.Wood)
		end
	end

	-- Parts rack beside the spawn area
	local rackX = 22
	local rackZ = -20
	local rackHeight = 4

	for _, side in { -1, 1 } do
		local post = Util.CreatePart(
			"RackPost",
			Vector3.new(0.8, rackHeight, 0.8),
			CFrame.new(Vector3.new(rackX + side * 5, rackHeight * 0.5, rackZ)),
			workshop
		)
		Util.StylePart(post, COLORS.RackFrame, Enum.Material.Metal)
	end

	for barIndex = 0, 3 do
		local barY = 1.0 + barIndex * 1.0
		local bar = Util.CreatePart(
			string.format("RackBar%d", barIndex),
			Vector3.new(10.8, 0.35, 0.35),
			CFrame.new(Vector3.new(rackX, barY, rackZ)),
			workshop
		)
		Util.StylePart(bar, COLORS.RackBar, Enum.Material.Metal)
	end
end

-- Level construction ---------------------------------------------------------

function UphillDeliveryLevel.Build(definition: ExperimentTypes.ExperimentDefinition): Built?
	local existing = Workspace:FindFirstChild(Config.AuthoredWorkshopName)
	if existing ~= nil then
		if existing:GetAttribute(Config.AttributeGenerated) == true then
			existing:Destroy()
		else
			log(
				string.format(
					"Workspace.%s already exists and was not generated by Luau - leaving it alone",
					Config.AuthoredWorkshopName
				)
			)
			return nil
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
	buildInclineAndPlatform(
		workshop,
		geometry.StartPadCenter,
		geometry.StartPadSize,
		geometry.GoalPadCenter,
		geometry.GoalPadSize
	)
	buildDressing(workshop, geometry)
	Util.CreateBuildBounds(geometry.BuildBoundsCenter, geometry.BuildBoundsSize, workshop)
	Util.CreateSpawn(geometry.PlayerSpawn, Vector3.new(0, 0, 1), workshop)

	local duck = Util.CreateDuck(definition.Payload, geometry.DuckSpawn, workshop)
	local goal, cap, trigger = Util.CreateGoalButton(geometry.ButtonPosition, workshop)

	local duckSpawn = CFrame.new(geometry.DuckSpawn)

	workshop.Parent = Workspace

	ComponentFactory.SetRuntime(workshop)
	local staged = Util.StageParts(definition)

	local handles: ExperimentTypes.LevelHandles = {
		Workshop = workshop,
		Duck = duck,
		DuckSpawn = duckSpawn,
		Goal = goal,
		GoalTrigger = trigger,
		GoalCap = cap,
		Center = Vector3.new(0, 5, (geometry.DuckSpawn.Z + geometry.ButtonPosition.Z) * 0.5),
	}

	log(string.format("%s loaded with %d staged parts", definition.Name, #staged))

	return {
		Handles = handles,
		Staged = staged,
		Workshop = workshop,
	}
end

return table.freeze(UphillDeliveryLevel)
