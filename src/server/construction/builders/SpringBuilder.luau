--!strict

--[[
	SpringBuilder

	Builds and manages the internal assembly of a Spring component.
	A Spring is a multi-part mechanical component:
		Spring
		├── Root (Base mounting plate)
		│   └── Rigid connector on bottom (-Y)
		│   └── DragDetector
		│   └── BaseAttachment
		│   └── PrismaticConstraint -> PlungerAttachment
		│   └── SpringConstraint -> PlungerAttachment
		└── Plunger (moving top impact/launch plate)
		    └── PlungerAttachment
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ComponentDefinitions = require(Shared.construction.ComponentDefinitions)
local ConstructionConfig = require(Shared.construction.ConstructionConfig)

local Config = ConstructionConfig

local SpringBuilder = {}

local BASE_SIZE = Vector3.new(3, 0.6, 3)
local PLUNGER_SIZE = Vector3.new(2.6, 0.5, 2.6)
local REST_EXTENSION = 1.6
local SPRING_STIFFNESS = 6000
local SPRING_DAMPING = 90
local SPRING_MAX_FORCE = 25000

function SpringBuilder.Build(
	model: Model,
	_componentId: string,
	definition: ComponentDefinitions.ComponentDefinition
): Part
	local root = Instance.new("Part")
	root.Name = Config.RootPartName
	root.Shape = Enum.PartType.Block
	root.Size = BASE_SIZE
	root.Color = Color3.fromRGB(72, 76, 84)
	root.Material = Enum.Material.Metal
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
	root.CFrame = CFrame.new(0, -0.95, 0)
	root.Parent = model

	-- Connector attachment on bottom (-Y)
	for _, connector in definition.Connectors do
		local attachment = Instance.new("Attachment")
		attachment.Name = connector.Name
		attachment.CFrame = connector.Offset
		attachment:SetAttribute(Config.AttributeConnector, true)
		attachment:SetAttribute(Config.AttributeConnectorType, connector.Type)
		attachment:SetAttribute(Config.AttributeOccupied, false)
		attachment.Parent = root
	end

	-- Internal attachment on Base (top face)
	local baseAttachment = Instance.new("Attachment")
	baseAttachment.Name = "WZ_BaseAttachment"
	baseAttachment.Position = Vector3.new(0, BASE_SIZE.Y * 0.5, 0)
	baseAttachment.Axis = Vector3.new(0, 1, 0)
	baseAttachment.SecondaryAxis = Vector3.new(0, 0, 1)
	baseAttachment.Parent = root

	-- Plunger: moving impact/launch plate
	local plunger = Instance.new("Part")
	plunger.Name = "WZ_Plunger"
	plunger.Shape = Enum.PartType.Block
	plunger.Size = PLUNGER_SIZE
	plunger.Color = Color3.fromRGB(240, 150, 40)
	plunger.Material = Enum.Material.SmoothPlastic
	plunger.Anchored = true
	plunger.CanCollide = true
	plunger.CanQuery = true
	plunger.CanTouch = true
	plunger.CastShadow = true
	plunger.TopSurface = Enum.SurfaceType.Smooth
	plunger.BottomSurface = Enum.SurfaceType.Smooth
	plunger.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.7, 0.05)
	plunger.CollisionGroup = Config.CollisionGroupComponents
	plunger:SetAttribute("WZ_Plunger", true)
	plunger.CFrame = root.CFrame
		* CFrame.new(0, BASE_SIZE.Y * 0.5 + REST_EXTENSION + PLUNGER_SIZE.Y * 0.5, 0)
	plunger.Parent = model

	local plungerAttachment = Instance.new("Attachment")
	plungerAttachment.Name = "WZ_PlungerAttachment"
	plungerAttachment.Position = Vector3.new(0, -PLUNGER_SIZE.Y * 0.5, 0)
	plungerAttachment.Axis = Vector3.new(0, 1, 0)
	plungerAttachment.SecondaryAxis = Vector3.new(0, 0, 1)
	plungerAttachment.Parent = plunger

	-- PrismaticConstraint restricts motion purely along Y axis
	local prismatic = Instance.new("PrismaticConstraint")
	prismatic.Name = "WZ_PrismaticConstraint"
	prismatic.Attachment0 = baseAttachment
	prismatic.Attachment1 = plungerAttachment
	prismatic.LimitsEnabled = true
	prismatic.LowerLimit = 0.1
	prismatic.UpperLimit = REST_EXTENSION
	prismatic.Size = 0.2
	prismatic.Parent = root

	-- SpringConstraint provides restoring/launching force
	local spring = Instance.new("SpringConstraint")
	spring.Name = "WZ_SpringConstraint"
	spring.Attachment0 = baseAttachment
	spring.Attachment1 = plungerAttachment
	spring.FreeLength = REST_EXTENSION
	spring.Stiffness = SPRING_STIFFNESS
	spring.Damping = SPRING_DAMPING
	spring.MaxForce = SPRING_MAX_FORCE
	spring.Coils = 4
	spring.Radius = 0.75
	spring.Color = BrickColor.new("Bright yellow")
	spring.Visible = true
	spring.Parent = root

	return root
end

function SpringBuilder.ResetInternalState(model: Model)
	local root = model.PrimaryPart
	local plunger = model:FindFirstChild("WZ_Plunger")
	if root == nil or plunger == nil or not plunger:IsA("BasePart") then
		return
	end

	plunger.AssemblyLinearVelocity = Vector3.zero
	plunger.AssemblyAngularVelocity = Vector3.zero
	plunger.CFrame = root.CFrame
		* CFrame.new(0, BASE_SIZE.Y * 0.5 + REST_EXTENSION + PLUNGER_SIZE.Y * 0.5, 0)
	plunger.Anchored = true
end

function SpringBuilder.SetAnchored(model: Model, anchored: boolean)
	local root = model.PrimaryPart
	local plunger = model:FindFirstChild("WZ_Plunger")
	if root == nil or plunger == nil or not plunger:IsA("BasePart") then
		return
	end

	root.Anchored = anchored
	plunger.Anchored = anchored
end

return table.freeze(SpringBuilder)
