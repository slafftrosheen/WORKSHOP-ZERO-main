--!strict

--[[
	SaveTheDuckLevel

	Builds Workspace.Workshop for Experiment 001.

	The layout was chosen for the player, not for the screenshot:

		* the workshop floor is at ground level, so nobody has to climb
		  anything and nobody can get stranded on a platform
		* the gap is a real trench cut into that floor, four studs deep, which
		  the player can jump out of and a duck cannot climb out of
		* the start pad and goal pad are only a step high: they read as
		  platforms without becoming obstacles
		* everything is Roblox primitives, chunky and exaggerated

	This module only builds. It does not decide when anything is a success,
	and it never touches the construction kernel's rules.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ComponentDefinitions = require(Shared.construction.ComponentDefinitions)
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)

local Config = ConstructionConfig

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
	Wall = Color3.fromRGB(110, 86, 64),
	Shelf = Color3.fromRGB(90, 68, 48),
	Crate = Color3.fromRGB(158, 120, 76),
	Bench = Color3.fromRGB(108, 80, 54),
	BenchTop = Color3.fromRGB(128, 98, 68),
	Metal = Color3.fromRGB(108, 112, 122),
	DarkMetal = Color3.fromRGB(60, 64, 74),
	Button = Color3.fromRGB(210, 50, 44),
	ButtonCap = Color3.fromRGB(232, 64, 54),
	Duck = Color3.fromRGB(255, 210, 55),
	DuckBeak = Color3.fromRGB(248, 148, 40),
	DuckEye = Color3.fromRGB(28, 28, 36),
	DuckBody = Color3.fromRGB(248, 198, 48),
	RackFrame = Color3.fromRGB(80, 76, 70),
	RackBar = Color3.fromRGB(96, 90, 82),
	Spawn = Color3.fromRGB(90, 180, 120),
}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ] %s", message))
	end
end

local function newPart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CollisionGroup = Config.CollisionGroupEnvironment
	part.Parent = parent

	return part
end

local function style(part: BasePart, color: Color3, material: Enum.Material)
	part.Color = color
	part.Material = material
end

local function weldTo(body: BasePart, other: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "WZ_PayloadWeld"
	weld.Part0 = body
	weld.Part1 = other
	weld.Parent = other
end

-- Environment -----------------------------------------------------------------

local function buildFloor(workshop: Instance, geometry: ExperimentTypes.LevelGeometry)
	local floorSize = geometry.FloorSize
	local halfDepth = floorSize.Z * 0.5

	-- Two slabs with a trench between them, plus the trench floor below.
	local gapNear = geometry.StartPadCenter.Z + geometry.StartPadSize.Z * 0.5
	local gapFar = geometry.GoalPadCenter.Z - geometry.GoalPadSize.Z * 0.5

	local nearDepth = halfDepth + gapNear
	local near = newPart(
		"Floor",
		Vector3.new(floorSize.X, floorSize.Y, nearDepth),
		CFrame.new(Vector3.new(0, geometry.FloorCenter.Y, gapNear - nearDepth * 0.5)),
		workshop
	)
	style(near, COLORS.Floor, Enum.Material.Concrete)

	local farDepth = halfDepth - gapFar
	local far = newPart(
		"FloorFar",
		Vector3.new(floorSize.X, floorSize.Y, farDepth),
		CFrame.new(Vector3.new(0, geometry.FloorCenter.Y, gapFar + farDepth * 0.5)),
		workshop
	)
	style(far, COLORS.Floor, Enum.Material.Concrete)

	local pit = newPart(
		"PitFloor",
		Vector3.new(floorSize.X, floorSize.Y, (gapFar - gapNear) + 16),
		CFrame.new(
			Vector3.new(0, geometry.PitFloorTopY - floorSize.Y * 0.5, (gapNear + gapFar) * 0.5)
		),
		workshop
	)
	style(pit, COLORS.Pit, Enum.Material.Slate)

	log(string.format("Trench spans %.1f studs between the pads", gapFar - gapNear))
end

local function buildPad(
	workshop: Instance,
	name: string,
	size: Vector3,
	center: Vector3,
	tapeColor: Color3
)
	local pad = newPart(name, size, CFrame.new(center), workshop)
	style(pad, COLORS.Pad, Enum.Material.WoodPlanks)

	-- Painted boundary instead of a glowing debug box.
	local top = center.Y + size.Y * 0.5 + 0.06
	local inset = 0.6
	local thickness = 0.35
	local alongX = size.X * 0.5 - inset
	local alongZ = size.Z * 0.5 - inset

	local function tape(partName: string, barSize: Vector3, position: Vector3)
		local bar = newPart(partName, barSize, CFrame.new(position), workshop)
		style(bar, tapeColor, Enum.Material.SmoothPlastic)
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

local function buildWorkshopDressing(workshop: Instance, geometry: ExperimentTypes.LevelGeometry)
	-- Back wall: warm timber planks, readable silhouette behind the action.
	local wall =
		newPart("BackWall", geometry.BackWallSize, CFrame.new(geometry.BackWallCenter), workshop)
	style(wall, COLORS.Wall, Enum.Material.WoodPlanks)

	-- Two shelves with a few crates. Kept narrow so they don't compete with
	-- the build area. The crates thin out near centre to keep the duck visible.
	local shelfZ = geometry.BackWallCenter.Z + 2.5
	for index = 1, 2 do
		local y = geometry.BackWallCenter.Y + 4 + (index - 1) * 5.5
		local shelf = newPart(
			string.format("Shelf%d", index),
			Vector3.new(56, 0.5, 3.5),
			CFrame.new(Vector3.new(0, y, shelfZ)),
			workshop
		)
		style(shelf, COLORS.Shelf, Enum.Material.Wood)

		-- Crates only on the outer thirds so the centre stays clear.
		for _, slot in { -3, -2, 2, 3 } do
			local crate = newPart(
				string.format("Crate%d_%d", index, slot),
				Vector3.new(2.8, 2.2, 2.8),
				CFrame.new(Vector3.new(slot * 7, y + 1.35, shelfZ)),
				workshop
			)
			style(crate, COLORS.Crate, Enum.Material.Wood)
		end
	end

	-- Workbench: properly human-scaled (top at ~3 studs, 10 studs wide).
	-- Placed to the left of the start pad so the player passes it naturally.
	-- benchTop Y = floor (0) + legs (3) + top (0.5/2) = 3.25
	local benchX = -22
	local benchZ = -22
	local benchTopY = 3.25
	local benchTopSize = Vector3.new(10, 0.5, 5)
	local benchTop = newPart(
		"BenchTop",
		benchTopSize,
		CFrame.new(Vector3.new(benchX, benchTopY, benchZ)),
		workshop
	)
	style(benchTop, COLORS.BenchTop, Enum.Material.Wood)

	-- Four legs, one at each corner, 3 studs tall.
	local legSize = Vector3.new(0.7, 3, 0.7)
	for _, xOff in { -4.5, 4.5 } do
		for _, zOff in { -2, 2 } do
			local leg = newPart(
				"BenchLeg",
				legSize,
				CFrame.new(Vector3.new(benchX + xOff, 1.5, benchZ + zOff)),
				workshop
			)
			style(leg, COLORS.Bench, Enum.Material.Wood)
		end
	end

	-- A couple of toolboxes on the bench top.
	for slot = 0, 1 do
		local box = newPart(
			string.format("Toolbox%d", slot),
			Vector3.new(2.5, 1.8, 2),
			CFrame.new(Vector3.new(benchX - 3 + slot * 4.5, benchTopY + 1.15, benchZ - 0.5)),
			workshop
		)
		style(box, COLORS.Metal, Enum.Material.CorrodedMetal)
	end

	-- A parts rack beside the spawn pad — distinct from the benches.
	-- Horizontal bars hold the staged parts visually.
	local rackX = 22
	local rackZ = -18
	local rackHeight = 4

	for _, side in { -1, 1 } do
		local post = newPart(
			"RackPost",
			Vector3.new(0.8, rackHeight, 0.8),
			CFrame.new(Vector3.new(rackX + side * 5, rackHeight * 0.5, rackZ)),
			workshop
		)
		style(post, COLORS.RackFrame, Enum.Material.Metal)
	end

	for barIndex = 0, 2 do
		local barY = 1.2 + barIndex * 1.2
		local bar = newPart(
			string.format("RackBar%d", barIndex),
			Vector3.new(10.8, 0.35, 0.35),
			CFrame.new(Vector3.new(rackX, barY, rackZ)),
			workshop
		)
		style(bar, COLORS.RackBar, Enum.Material.Metal)
	end
end

local function buildBounds(workshop: Instance, geometry: ExperimentTypes.LevelGeometry)
	-- The legal build volume: invisible, no collision, never a debug box.
	local bounds = newPart(
		"BuildBounds",
		geometry.BuildBoundsSize,
		CFrame.new(geometry.BuildBoundsCenter),
		workshop
	)
	bounds.Transparency = 1
	bounds.CanCollide = false
	bounds.CanQuery = false
	bounds.CanTouch = false
	bounds.CastShadow = false
end

local function buildSpawn(workshop: Instance, geometry: ExperimentTypes.LevelGeometry)
	-- Face the player toward the duck and gap on spawn.
	-- The gap is forward (positive Z), so look roughly in that direction.
	local spawnCFrame = CFrame.new(geometry.PlayerSpawn) * CFrame.Angles(0, math.rad(180), 0)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "WorkshopSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = spawnCFrame
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Color = COLORS.Spawn
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Transparency = 0.55
	spawn.CollisionGroup = Config.CollisionGroupEnvironment
	spawn.Parent = workshop
end

-- The duck --------------------------------------------------------------------

local function buildDuck(definition: ExperimentTypes.ExperimentDefinition, spawn: Vector3): Model
	local spec = definition.Payload
	local model = Instance.new("Model")
	model.Name = "Duck"
	model:SetAttribute(Config.AttributePayload, true)
	model:SetAttribute(Config.AttributePayloadType, spec.Type)

	local body = newPart("Body", spec.BodySize, CFrame.new(spawn), model)
	style(body, COLORS.DuckBody, Enum.Material.SmoothPlastic)
	body.CollisionGroup = Config.CollisionGroupPayloads
	body.CanTouch = true
	body.CustomPhysicalProperties =
		PhysicalProperties.new(spec.Density, spec.Friction, spec.Elasticity)
	body:SetAttribute(Config.AttributePayload, true)
	body:SetAttribute(Config.AttributePayloadType, spec.Type)
	model.PrimaryPart = body

	local function decor(
		name: string,
		shape: Enum.PartType,
		size: Vector3,
		offset: Vector3,
		color: Color3,
		material: Enum.Material?
	): BasePart
		local part = newPart(name, size, CFrame.new(spawn + offset), model)
		part.Shape = shape
		style(part, color, material or Enum.Material.SmoothPlastic)
		part.CollisionGroup = Config.CollisionGroupPayloads
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = false
		weldTo(body, part)

		return part
	end

	-- Rounded body bump for a more distinct duck silhouette.
	decor(
		"BodyBall",
		Enum.PartType.Ball,
		Vector3.new(2.6, 2.6, 2.6),
		Vector3.new(0, 0.5, 0),
		COLORS.Duck,
		Enum.Material.SmoothPlastic
	)
	decor(
		"Head",
		Enum.PartType.Ball,
		Vector3.new(1.8, 1.8, 1.8),
		Vector3.new(0, 1.4, 0.9),
		COLORS.Duck,
		Enum.Material.SmoothPlastic
	)
	decor(
		"Beak",
		Enum.PartType.Wedge,
		Vector3.new(0.8, 0.5, 1.0),
		Vector3.new(0, 1.2, 1.95),
		COLORS.DuckBeak,
		Enum.Material.SmoothPlastic
	)
	decor(
		"EyeLeft",
		Enum.PartType.Ball,
		Vector3.new(0.35, 0.35, 0.35),
		Vector3.new(-0.48, 1.58, 1.48),
		COLORS.DuckEye,
		Enum.Material.Neon
	)
	decor(
		"EyeRight",
		Enum.PartType.Ball,
		Vector3.new(0.35, 0.35, 0.35),
		Vector3.new(0.48, 1.58, 1.48),
		COLORS.DuckEye,
		Enum.Material.Neon
	)

	return model
end

-- The goal --------------------------------------------------------------------

local function buildGoal(position: Vector3): (Model, BasePart, BasePart)
	local goal = Instance.new("Model")
	goal.Name = "GoalButton"
	goal:SetAttribute(Config.AttributeGoal, true)

	-- Chunky metal base with visible bolts (represented by small round nubs).
	local base =
		newPart("Base", Vector3.new(7, 1.2, 7), CFrame.new(position + Vector3.new(0, 0.6, 0)), goal)
	style(base, COLORS.DarkMetal, Enum.Material.Metal)

	-- Mounting plate: slightly wider, contrasting colour.
	local plate = newPart(
		"Plate",
		Vector3.new(6, 0.4, 6),
		CFrame.new(position + Vector3.new(0, 1.4, 0)),
		goal
	)
	style(plate, COLORS.Metal, Enum.Material.CorrodedMetal)

	-- Four corner bolts for visual weight.
	for _, xOff in { -2.4, 2.4 } do
		for _, zOff in { -2.4, 2.4 } do
			local bolt = newPart(
				"Bolt",
				Vector3.new(0.55, 0.55, 0.55),
				CFrame.new(position + Vector3.new(xOff, 1.7, zOff)),
				goal
			)
			bolt.Shape = Enum.PartType.Cylinder
			style(bolt, COLORS.DarkMetal, Enum.Material.Metal)
		end
	end

	-- The big red cap: a cylinder standing up (rolled 90 degrees around Z).
	local cap = newPart(
		"Cap",
		Vector3.new(1.8, 5.8, 5.8),
		CFrame.new(position + Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		goal
	)
	cap.Shape = Enum.PartType.Cylinder
	style(cap, COLORS.ButtonCap, Enum.Material.SmoothPlastic)

	-- A thin neon ring so the button reads clearly from a distance.
	local ring = newPart(
		"Ring",
		Vector3.new(0.18, 6.2, 6.2),
		CFrame.new(position + Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		goal
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	style(ring, COLORS.Button, Enum.Material.Neon)
	ring.Transparency = 0.55

	local trigger = newPart(
		"GoalTrigger",
		Vector3.new(7, 5, 7),
		CFrame.new(position + Vector3.new(0, 2.8, 0)),
		goal
	)
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.CanTouch = true
	trigger.CastShadow = false
	trigger.CollisionGroup = Config.CollisionGroupGoalTrigger
	trigger:SetAttribute(Config.AttributeGoalTrigger, true)

	return goal, cap, trigger
end

-- Staging ---------------------------------------------------------------------

local function stageParts(
	definition: ExperimentTypes.ExperimentDefinition
): { ExperimentTypes.StagedComponent }
	local staged: { ExperimentTypes.StagedComponent } = {}
	local geometry = definition.Geometry
	local padTop = geometry.StartPadCenter.Y + geometry.StartPadSize.Y * 0.5

	for index, requirement in definition.Inventory do
		local componentDefinition = ComponentDefinitions.Get(requirement.ComponentType)
		if componentDefinition == nil then
			log(
				string.format("Inventory names an unknown component: %s", requirement.ComponentType)
			)
		else
			local rowZ = geometry.StagingRows[index]
			if rowZ == nil then
				rowZ = geometry.StagingRows[#geometry.StagingRows] - 2.5
			end

			-- A wheel is yawed to stand upright, so its axle lines up with the
			-- axle sockets on planks and blocks.
			local upright = requirement.ComponentType == "Wheel"
			local yaw = if upright then CFrame.Angles(0, math.rad(90), 0) else CFrame.new()
			local spread = if upright
				then componentDefinition.Size.Z
				else math.max(componentDefinition.Size.X, componentDefinition.Size.Z)
			local step = spread + geometry.StagingSpacing
			local height = componentDefinition.Size.Y * 0.5 + 0.05

			for slot = 1, requirement.Count do
				local offset = (slot - (requirement.Count + 1) * 0.5) * step
				local pivot = CFrame.new(Vector3.new(offset, padTop + height, rowZ)) * yaw
				local model = ComponentFactory.Create(requirement.ComponentType, pivot)

				if model ~= nil then
					local componentId = ComponentFactory.GetComponentId(model)
					if componentId ~= nil then
						table.insert(staged, {
							Model = model,
							ComponentId = componentId,
							SpawnPivot = pivot,
						})
					end
				end
			end
		end
	end

	return staged
end

-- Build -----------------------------------------------------------------------

function SaveTheDuckLevel.Build(definition: ExperimentTypes.ExperimentDefinition): Built?
	local existing = Workspace:FindFirstChild(Config.AuthoredWorkshopName)
	if existing ~= nil then
		if existing:GetAttribute(Config.AttributeGenerated) == true then
			-- Ours from an earlier load in this session: safe to replace.
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

	-- Guard: warn if a duplicate-named generated workshop exists (should never happen).
	if RunService:IsStudio() then
		for _, child in Workspace:GetChildren() do
			if child.Name == Config.AuthoredWorkshopName and child ~= existing then
				warn(
					string.format(
						"[WZ] Diagnostic: duplicate Workshop found before build: %s",
						child:GetFullName()
					)
				)
			end
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
	buildWorkshopDressing(workshop, geometry)
	buildBounds(workshop, geometry)
	buildSpawn(workshop, geometry)

	local duck = buildDuck(definition, geometry.DuckSpawn)
	local goal, cap, trigger = buildGoal(geometry.ButtonPosition)

	-- -----------------------------------------------------------------------
	-- WZ-002 fix: parent duck and goal into the workshop BEFORE the workshop
	-- itself enters Workspace.  This guarantees that every Instance that
	-- participates in physics, Touched, or raycasting is in the DataModel
	-- the moment the folder becomes visible to the engine.
	-- -----------------------------------------------------------------------
	duck.Parent = workshop
	goal.Parent = workshop

	-- Guards: these should never be nil after construction above.
	if RunService:IsStudio() then
		if duck.PrimaryPart == nil then
			warn("[WZ] Diagnostic: Duck has no PrimaryPart after build")
		end
		if trigger.Parent == nil then
			warn("[WZ] Diagnostic: GoalTrigger has no parent after build")
		end
	end

	local duckSpawn = CFrame.new(geometry.DuckSpawn)

	workshop.Parent = Workspace

	-- Components and connections live inside the workshop folder, so the
	-- construction kernel needs to know about it before anything is created.
	ComponentFactory.SetRuntime(workshop)
	local staged = stageParts(definition)

	if RunService:IsStudio() then
		if #staged == 0 then
			warn("[WZ] Diagnostic: zero staged components - check Inventory definition")
		end
		if workshop:FindFirstChild("BuildBounds") == nil then
			warn("[WZ] Diagnostic: BuildBounds part is missing from Workshop")
		end
	end

	local handles: ExperimentTypes.LevelHandles = {
		Workshop = workshop,
		Duck = duck,
		DuckSpawn = duckSpawn,
		Goal = goal,
		GoalTrigger = trigger,
		GoalCap = cap,
		Center = Vector3.new(0, 0, (geometry.DuckSpawn.Z + geometry.ButtonPosition.Z) * 0.5),
	}

	log(string.format("%s loaded with %d staged parts", definition.Name, #staged))
	log(
		string.format(
			"Workspace.%s hierarchy: Duck=%s, GoalButton=%s, GoalTrigger parent=%s",
			Config.AuthoredWorkshopName,
			tostring(duck.Parent ~= nil),
			tostring(goal.Parent ~= nil),
			tostring(trigger.Parent ~= nil)
		)
	)

	return {
		Handles = handles,
		Staged = staged,
		Workshop = workshop,
	}
end

return table.freeze(SaveTheDuckLevel)
