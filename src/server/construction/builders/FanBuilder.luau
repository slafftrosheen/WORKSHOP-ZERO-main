--!strict

--[[
	FanBuilder

	Builds the Fan component with toy-industrial visual detailing:
		Fan
		├── Root (authoritative cylinder physics body & axle hub)
		│   ├── Axle_Input connector on back (-X)
		│   ├── Rigid_Base connector on bottom (-Y)
		│   └── DragDetector
		└── Decorative visual parts (welded, massless, non-colliding):
		    ├── Center hub
		    ├── 4 angled propeller blades
		    ├── Protective outer shroud frame
		    └── Airflow direction indicator arrow (+X)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)

local Config = ConstructionConfig

local FanBuilder = {}

local function createVisualPart(
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material,
	root: BasePart,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.CollisionGroup = Config.CollisionGroupComponents
	part.CFrame = root.CFrame * localCFrame
	part.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Name = "WZ_VisualWeld"
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part

	return part
end

function FanBuilder.Build(
	model: Model,
	_componentId: string,
	definition: ConstructionTypes.ComponentDefinition
): Part
	local root = Instance.new("Part")
	root.Name = Config.RootPartName
	root.Shape = definition.Shape
	root.Size = definition.Size
	root.Color = definition.Color
	root.Material = definition.Material
	root.Anchored = true
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = false
	root.CastShadow = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.CustomPhysicalProperties =
		PhysicalProperties.new(definition.Density, definition.Friction, definition.Elasticity)
	root.CollisionGroup = Config.CollisionGroupComponents
	root.Parent = model

	-- Create connectors from definition
	for _, connector in definition.Connectors do
		local attachment = Instance.new("Attachment")
		attachment.Name = connector.Name
		attachment.CFrame = connector.Offset
		attachment:SetAttribute(Config.AttributeConnector, true)
		attachment:SetAttribute(Config.AttributeConnectorType, connector.Type)
		attachment:SetAttribute(Config.AttributeOccupied, false)
		attachment.Parent = root
	end

	-- Center hub (cylinder along X)
	createVisualPart(
		"WZ_FanHub",
		Enum.PartType.Cylinder,
		Vector3.new(0.9, 1.2, 1.2),
		CFrame.new(0.05, 0, 0),
		Color3.fromRGB(38, 42, 50),
		Enum.Material.Metal,
		root,
		model
	)

	-- 4 Angled propeller blades radiating from the hub
	local bladeColor = Color3.fromRGB(72, 148, 220)
	for i = 0, 3 do
		local angle = math.rad(i * 90)
		local bladeCFrame = CFrame.Angles(angle, 0, 0)
			* CFrame.new(0.05, 1.05, 0)
			* CFrame.Angles(math.rad(28), 0, 0)
		createVisualPart(
			string.format("WZ_FanBlade_%d", i + 1),
			Enum.PartType.Block,
			Vector3.new(0.12, 1.1, 0.75),
			bladeCFrame,
			bladeColor,
			Enum.Material.SmoothPlastic,
			root,
			model
		)
	end

	-- Outer protective shroud frame (4 perimeter bars)
	local shroudColor = Color3.fromRGB(48, 52, 60)
	local shroudOffsets = {
		CFrame.new(0, 1.6, 0),
		CFrame.new(0, -1.6, 0),
		CFrame.new(0, 0, 1.6),
		CFrame.new(0, 0, -1.6),
	}
	local shroudSizes = {
		Vector3.new(0.85, 0.22, 2.2),
		Vector3.new(0.85, 0.22, 2.2),
		Vector3.new(0.85, 2.2, 0.22),
		Vector3.new(0.85, 2.2, 0.22),
	}
	for i = 1, 4 do
		createVisualPart(
			string.format("WZ_FanShroud_%d", i),
			Enum.PartType.Block,
			shroudSizes[i],
			shroudOffsets[i],
			shroudColor,
			Enum.Material.Metal,
			root,
			model
		)
	end

	-- Airflow direction indicator arrow on the top shroud (+X direction)
	createVisualPart(
		"WZ_AirflowIndicator",
		Enum.PartType.Wedge,
		Vector3.new(0.35, 0.2, 0.25),
		CFrame.new(0.1, 1.8, 0) * CFrame.Angles(0, math.rad(-90), math.rad(-90)),
		Color3.fromRGB(245, 205, 50),
		Enum.Material.Neon,
		root,
		model
	)

	return root
end

return table.freeze(FanBuilder)
