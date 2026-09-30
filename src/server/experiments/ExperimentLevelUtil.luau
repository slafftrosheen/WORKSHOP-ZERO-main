--!strict

--[[
	ExperimentLevelUtil

	Concrete level-building and payload helpers shared between experiments.
	Contains no challenge-specific layout logic or game rules.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ComponentDefinitions = require(Shared.construction.ComponentDefinitions)
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local AssetProvider = require(script.Parent.Parent.assets.AssetProvider)

local Config = ConstructionConfig

local ExperimentLevelUtil = {}

ExperimentLevelUtil.COLORS = {
	Floor = Color3.fromRGB(88, 80, 70),
	Pit = Color3.fromRGB(44, 40, 36),
	Pad = Color3.fromRGB(140, 122, 96),
	Tape = Color3.fromRGB(248, 210, 60),
	Ramp = Color3.fromRGB(120, 105, 85),
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
		print(string.format("[WZ Level] %s", message))
	end
end

function ExperimentLevelUtil.CreatePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	parent: Instance
): Part
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

function ExperimentLevelUtil.StylePart(part: BasePart, color: Color3, material: Enum.Material)
	part.Color = color
	part.Material = material
end

function ExperimentLevelUtil.WeldParts(
	part0: BasePart,
	part1: BasePart,
	name: string?
): WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Name = name or "WZ_LevelWeld"
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1

	return weld
end

--[[
	Constructs the authoritative physics Duck payload.
]]
function ExperimentLevelUtil.CreateDuck(
	spec: ExperimentTypes.PayloadSpec,
	spawn: Vector3,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = "Duck"
	model:SetAttribute(Config.AttributePayload, true)
	model:SetAttribute(Config.AttributePayloadType, spec.Type)

	local body = ExperimentLevelUtil.CreatePart("Body", spec.BodySize, CFrame.new(spawn), model)
	ExperimentLevelUtil.StylePart(
		body,
		ExperimentLevelUtil.COLORS.DuckBody,
		Enum.Material.SmoothPlastic
	)
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
		local part = ExperimentLevelUtil.CreatePart(name, size, CFrame.new(spawn + offset), model)
		part.Shape = shape
		ExperimentLevelUtil.StylePart(part, color, material or Enum.Material.SmoothPlastic)
		part.CollisionGroup = Config.CollisionGroupPayloads
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = false
		ExperimentLevelUtil.WeldParts(body, part, "WZ_PayloadWeld")

		return part
	end

	decor(
		"BodyBall",
		Enum.PartType.Ball,
		Vector3.new(2.6, 2.6, 2.6),
		Vector3.new(0, 0.5, 0),
		ExperimentLevelUtil.COLORS.Duck,
		Enum.Material.SmoothPlastic
	)
	decor(
		"Head",
		Enum.PartType.Ball,
		Vector3.new(1.8, 1.8, 1.8),
		Vector3.new(0, 1.4, 0.9),
		ExperimentLevelUtil.COLORS.Duck,
		Enum.Material.SmoothPlastic
	)
	decor(
		"Beak",
		Enum.PartType.Wedge,
		Vector3.new(0.8, 0.5, 1.0),
		Vector3.new(0, 1.2, 1.95),
		ExperimentLevelUtil.COLORS.DuckBeak,
		Enum.Material.SmoothPlastic
	)
	decor(
		"EyeLeft",
		Enum.PartType.Ball,
		Vector3.new(0.35, 0.35, 0.35),
		Vector3.new(-0.48, 1.58, 1.48),
		ExperimentLevelUtil.COLORS.DuckEye,
		Enum.Material.Neon
	)
	decor(
		"EyeRight",
		Enum.PartType.Ball,
		Vector3.new(0.35, 0.35, 0.35),
		Vector3.new(0.48, 1.58, 1.48),
		ExperimentLevelUtil.COLORS.DuckEye,
		Enum.Material.Neon
	)

	model.Parent = parent

	return model
end

--[[
	Constructs the GoalButton model, returning (GoalModel, CapPart, TriggerPart).
]]
function ExperimentLevelUtil.CreateGoalButton(
	position: Vector3,
	parent: Instance
): (Model, BasePart, BasePart)
	local goal = Instance.new("Model")
	goal.Name = "GoalButton"
	goal:SetAttribute(Config.AttributeGoal, true)

	local base = ExperimentLevelUtil.CreatePart(
		"Base",
		Vector3.new(7, 1.2, 7),
		CFrame.new(position + Vector3.new(0, 0.6, 0)),
		goal
	)
	ExperimentLevelUtil.StylePart(base, ExperimentLevelUtil.COLORS.DarkMetal, Enum.Material.Metal)

	local plate = ExperimentLevelUtil.CreatePart(
		"Plate",
		Vector3.new(6, 0.4, 6),
		CFrame.new(position + Vector3.new(0, 1.4, 0)),
		goal
	)
	ExperimentLevelUtil.StylePart(
		plate,
		ExperimentLevelUtil.COLORS.Metal,
		Enum.Material.CorrodedMetal
	)

	for _, xOff in { -2.4, 2.4 } do
		for _, zOff in { -2.4, 2.4 } do
			local bolt = ExperimentLevelUtil.CreatePart(
				"Bolt",
				Vector3.new(0.55, 0.55, 0.55),
				CFrame.new(position + Vector3.new(xOff, 1.7, zOff)),
				goal
			)
			bolt.Shape = Enum.PartType.Cylinder
			ExperimentLevelUtil.StylePart(
				bolt,
				ExperimentLevelUtil.COLORS.DarkMetal,
				Enum.Material.Metal
			)
		end
	end

	local cap = ExperimentLevelUtil.CreatePart(
		"Cap",
		Vector3.new(1.8, 5.8, 5.8),
		CFrame.new(position + Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		goal
	)
	cap.Shape = Enum.PartType.Cylinder
	ExperimentLevelUtil.StylePart(
		cap,
		ExperimentLevelUtil.COLORS.ButtonCap,
		Enum.Material.SmoothPlastic
	)

	local ring = ExperimentLevelUtil.CreatePart(
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
	ExperimentLevelUtil.StylePart(ring, ExperimentLevelUtil.COLORS.Button, Enum.Material.Neon)
	ring.Transparency = 0.55

	local trigger = ExperimentLevelUtil.CreatePart(
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

	goal.Parent = parent

	return goal, cap, trigger
end

function ExperimentLevelUtil.CreateSpawn(
	spawnPosition: Vector3,
	lookDirection: Vector3?,
	parent: Instance
): SpawnLocation
	local cframe = CFrame.new(spawnPosition)
	if lookDirection ~= nil and lookDirection.Magnitude > 0.01 then
		cframe = CFrame.lookAt(spawnPosition, spawnPosition + lookDirection)
	else
		cframe = cframe * CFrame.Angles(0, math.rad(180), 0)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "WorkshopSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = cframe
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Color = ExperimentLevelUtil.COLORS.Spawn
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Transparency = 0.55
	spawn.CollisionGroup = Config.CollisionGroupEnvironment
	spawn.Parent = parent

	return spawn
end

function ExperimentLevelUtil.CreateBuildBounds(
	center: Vector3,
	size: Vector3,
	parent: Instance
): Part
	local bounds = ExperimentLevelUtil.CreatePart("BuildBounds", size, CFrame.new(center), parent)
	bounds.Transparency = 1
	bounds.CanCollide = false
	bounds.CanQuery = false
	bounds.CanTouch = false
	bounds.CastShadow = false

	return bounds
end

--[[
	Spawns parts on the rack according to the experiment's inventory definition.
]]
function ExperimentLevelUtil.StageParts(
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

--[[
	Applies a custom visual asset over a primitive collider, welding all
	descendants to the primary physics part and hiding the primitive children.
]]
function ExperimentLevelUtil.ApplyCustomVisual(
	container: Model,
	attachToPart: BasePart,
	category: string,
	assetName: string,
	keepTransparentExcept: BasePart?
)
	local visual = AssetProvider.Get(category, assetName)
	if visual == nil then
		return
	end

	visual:PivotTo(container:GetPivot())
	visual.Parent = container

	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			ExperimentLevelUtil.WeldParts(attachToPart, descendant, "WZ_VisualWeld")
		end
	end

	for _, child in container:GetChildren() do
		if child:IsA("BasePart") and child ~= keepTransparentExcept then
			child.Transparency = 1
		end
	end
end

return table.freeze(ExperimentLevelUtil)
