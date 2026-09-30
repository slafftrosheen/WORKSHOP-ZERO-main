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
	Floor = Color3.fromRGB(96, 88, 78),
	Pit = Color3.fromRGB(58, 54, 50),
	Pad = Color3.fromRGB(150, 132, 104),
	Tape = Color3.fromRGB(240, 200, 70),
	Wall = Color3.fromRGB(122, 96, 72),
	Shelf = Color3.fromRGB(104, 80, 60),
	Crate = Color3.fromRGB(168, 132, 88),
	Bench = Color3.fromRGB(120, 92, 66),
	Metal = Color3.fromRGB(120, 124, 132),
	DarkMetal = Color3.fromRGB(74, 78, 86),
	Button = Color3.fromRGB(214, 62, 52),
	Duck = Color3.fromRGB(255, 205, 60),
	DuckBeak = Color3.fromRGB(248, 148, 40),
	DuckEye = Color3.fromRGB(32, 32, 38),
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
	local wall =
		newPart("BackWall", geometry.BackWallSize, CFrame.new(geometry.BackWallCenter), workshop)
	style(wall, COLORS.Wall, Enum.Material.WoodPlanks)

	local shelfY = geometry.BackWallCenter.Y + 3
	for index = 1, 2 do
		local y = shelfY + (index - 1) * 6
		local shelf = newPart(
			string.format("Shelf%d", index),
			Vector3.new(64, 0.6, 4),
			CFrame.new(Vector3.new(0, y, geometry.BackWallCenter.Z + 3)),
			workshop
		)
		style(shelf, COLORS.Shelf, Enum.Material.Wood)

		for slot = -2, 2 do
			local crate = newPart(
				string.format("Crate%d_%d", index, slot),
				Vector3.new(3, 2.4, 3),
				CFrame.new(Vector3.new(slot * 8, y + 1.5, geometry.BackWallCenter.Z + 3)),
				workshop
			)
			style(crate, COLORS.Crate, Enum.Material.Wood)
		end
	end

	-- A bench the player walks past on the way to the build area.
	local benchCenter = Vector3.new(-24, 0, -20)
	local benchTop = newPart(
		"Bench",
		Vector3.new(4, 4, 12),
		CFrame.new(benchCenter + Vector3.new(0, 10, 0)),
		workshop
	)
	style(benchTop, COLORS.Bench, Enum.Material.Wood)

	for _, offset in { -4, 4 } do
		local leg = newPart(
			"BenchLeg",
			Vector3.new(3, 10, 3),
			CFrame.new(benchCenter + Vector3.new(0, 5, offset)),
			workshop
		)
		style(leg, COLORS.Shelf, Enum.Material.Wood)
	end

	for slot = 0, 2 do
		local box = newPart(
			string.format("Toolbox%d", slot),
			Vector3.new(3, 2, 3),
			CFrame.new(benchCenter + Vector3.new(0, 13, -4 + slot * 4)),
			workshop
		)
		style(box, COLORS.Metal, Enum.Material.CorrodedMetal)
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
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "WorkshopSpawn"
	spawn.Size = Vector3.new(7, 1, 7)
	spawn.CFrame = CFrame.new(geometry.PlayerSpawn)
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(120, 200, 140)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
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
	style(body, COLORS.Duck, Enum.Material.SmoothPlastic)
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
		color: Color3
	): BasePart
		local part = newPart(name, size, CFrame.new(spawn + offset), model)
		part.Shape = shape
		style(part, color, Enum.Material.SmoothPlastic)
		part.CollisionGroup = Config.CollisionGroupPayloads
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = false
		weldTo(body, part)

		return part
	end

	decor(
		"Head",
		Enum.PartType.Ball,
		Vector3.new(1.7, 1.7, 1.7),
		Vector3.new(0, 1.25, 0.85),
		COLORS.Duck
	)
	decor(
		"Beak",
		Enum.PartType.Block,
		Vector3.new(0.9, 0.45, 1.1),
		Vector3.new(0, 1.15, 1.85),
		COLORS.DuckBeak
	)
	decor(
		"EyeLeft",
		Enum.PartType.Ball,
		Vector3.new(0.3, 0.3, 0.3),
		Vector3.new(-0.45, 1.5, 1.4),
		COLORS.DuckEye
	)
	decor(
		"EyeRight",
		Enum.PartType.Ball,
		Vector3.new(0.3, 0.3, 0.3),
		Vector3.new(0.45, 1.5, 1.4),
		COLORS.DuckEye
	)

	return model
end

-- The goal --------------------------------------------------------------------

local function buildGoal(position: Vector3): (Model, BasePart, BasePart)
	local goal = Instance.new("Model")
	goal.Name = "GoalButton"
	goal:SetAttribute(Config.AttributeGoal, true)

	local base =
		newPart("Base", Vector3.new(7, 1, 7), CFrame.new(position + Vector3.new(0, 0.5, 0)), goal)
	style(base, COLORS.Metal, Enum.Material.CorrodedMetal)

	local collar = newPart(
		"Collar",
		Vector3.new(6.2, 0.4, 6.2),
		CFrame.new(position + Vector3.new(0, 1.2, 0)),
		goal
	)
	style(collar, COLORS.DarkMetal, Enum.Material.Metal)

	-- A cylinder spins around X, so rolling it 90 degrees stands the cap up.
	local cap = newPart(
		"Cap",
		Vector3.new(1.6, 5.5, 5.5),
		CFrame.new(position + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		goal
	)
	cap.Shape = Enum.PartType.Cylinder
	style(cap, COLORS.Button, Enum.Material.SmoothPlastic)

	local trigger = newPart(
		"GoalTrigger",
		Vector3.new(7, 5, 7),
		CFrame.new(position + Vector3.new(0, 2.2, 0)),
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

	local duckSpawn = CFrame.new(geometry.DuckSpawn)

	workshop.Parent = Workspace

	-- Components and connections live inside the workshop folder, so the
	-- construction kernel needs to know about it before anything is created.
	ComponentFactory.SetRuntime(workshop)
	local staged = stageParts(definition)

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

	return {
		Handles = handles,
		Staged = staged,
		Workshop = workshop,
	}
end

return table.freeze(SaveTheDuckLevel)
