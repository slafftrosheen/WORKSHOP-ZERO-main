--!strict

--[[
	PistonBuilder

	Builds and manages the internal assembly of a Piston component.
	A Piston is a multi-part mechanical linear actuator:
		Piston
		├── Root (Housing mounting block)
		│   └── Rigid connector on bottom (-Y)
		│   └── Rigid connector on back (-X)
		│   └── Control signal port on top (+Y)
		│   └── DragDetector
		│   └── BaseAttachment (+X)
		│   └── PrismaticConstraint -> PlungerAttachment
		│   └── Indicator (WZ_PistonIndicator)
		└── WZ_PistonPlunger (moving push plate)
		    └── PlungerAttachment
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ComponentDefinitions = require(Shared.construction.ComponentDefinitions)
local ConstructionConfig = require(Shared.construction.ConstructionConfig)

local Config = ConstructionConfig

local PistonBuilder = {}

local HOUSING_SIZE = Vector3.new(3.0, 2.0, 2.0)
local PLUNGER_SIZE = Vector3.new(0.6, 1.8, 1.8)
local REST_PLUNGER_OFFSET = CFrame.new(HOUSING_SIZE.X * 0.5 + PLUNGER_SIZE.X * 0.5, 0, 0)

function PistonBuilder.Build(
	model: Model,
	_componentId: string,
	definition: ComponentDefinitions.ComponentDefinition
): Part
	local root = Instance.new("Part")
	root.Name = Config.RootPartName
	root.Shape = Enum.PartType.Block
	root.Size = HOUSING_SIZE
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

	-- Connectors from definition
	for _, connector in definition.Connectors do
		local attachment = Instance.new("Attachment")
		attachment.Name = connector.Name
		attachment.CFrame = connector.Offset
		attachment:SetAttribute(Config.AttributeConnector, true)
		attachment:SetAttribute(Config.AttributeConnectorType, connector.Type)
		attachment:SetAttribute(Config.AttributeOccupied, false)
		attachment.Parent = root
	end

	-- Signal ports from definition
	if definition.SignalPorts ~= nil then
		for _, port in definition.SignalPorts do
			local attachment = Instance.new("Attachment")
			attachment.Name = port.Name
			attachment.CFrame = port.Offset
			attachment:SetAttribute(Config.AttributeSignalPort, true)
			attachment:SetAttribute(Config.AttributeSignalDirection, port.Direction)
			attachment:SetAttribute(Config.AttributeSignalPortName, port.Name)
			attachment.Parent = root
		end
	end

	-- Internal attachment on Housing front face (+X)
	local baseAttachment = Instance.new("Attachment")
	baseAttachment.Name = "WZ_PistonBaseAttachment"
	baseAttachment.Position = Vector3.new(HOUSING_SIZE.X * 0.5, 0, 0)
	baseAttachment.Axis = Vector3.new(1, 0, 0)
	baseAttachment.SecondaryAxis = Vector3.new(0, 1, 0)
	baseAttachment.Parent = root

	-- Moving Plunger push plate
	local plunger = Instance.new("Part")
	plunger.Name = "WZ_PistonPlunger"
	plunger.Shape = Enum.PartType.Block
	plunger.Size = PLUNGER_SIZE
	plunger.Color = Color3.fromRGB(210, 215, 225)
	plunger.Material = Enum.Material.Metal
	plunger.Anchored = true
	plunger.CanCollide = true
	plunger.CanQuery = true
	plunger.CanTouch = true
	plunger.CastShadow = true
	plunger.TopSurface = Enum.SurfaceType.Smooth
	plunger.BottomSurface = Enum.SurfaceType.Smooth
	plunger.CustomPhysicalProperties = PhysicalProperties.new(1.0, 0.7, 0.05)
	plunger.CollisionGroup = Config.CollisionGroupComponents
	plunger:SetAttribute("WZ_PistonPlunger", true)
	plunger.CFrame = root.CFrame * REST_PLUNGER_OFFSET
	plunger.Parent = model

	local plungerAttachment = Instance.new("Attachment")
	plungerAttachment.Name = "WZ_PistonPlungerAttachment"
	plungerAttachment.Position = Vector3.new(-PLUNGER_SIZE.X * 0.5, 0, 0)
	plungerAttachment.Axis = Vector3.new(1, 0, 0)
	plungerAttachment.SecondaryAxis = Vector3.new(0, 1, 0)
	plungerAttachment.Parent = plunger

	-- PrismaticConstraint restricts motion along +X axis and provides servo drive
	local prismatic = Instance.new("PrismaticConstraint")
	prismatic.Name = "WZ_PistonConstraint"
	prismatic.Attachment0 = baseAttachment
	prismatic.Attachment1 = plungerAttachment
	prismatic.LimitsEnabled = true
	prismatic.LowerLimit = 0
	prismatic.UpperLimit = Config.PistonStroke
	prismatic.ActuatorType = Enum.ActuatorType.None
	prismatic.TargetPosition = 0
	prismatic.Speed = Config.PistonSpeed
	prismatic.ServoMaxForce = Config.PistonServoMaxForce
	prismatic.LinearResponsiveness = Config.PistonLinearResponsiveness
	prismatic.Size = 0.2
	prismatic.Parent = root

	-- Indicator for visual signal feedback
	local indicator = Instance.new("Part")
	indicator.Name = "WZ_PistonIndicator"
	indicator.Shape = Enum.PartType.Cylinder
	indicator.Size = Vector3.new(0.18, 0.5, 0.5)
	indicator.CFrame = root.CFrame * CFrame.new(0.6, 1.01, 0) * CFrame.Angles(0, 0, math.rad(90))
	indicator.Color = Color3.fromRGB(30, 45, 65)
	indicator.Material = Enum.Material.SmoothPlastic
	indicator.Anchored = false
	indicator.CanCollide = false
	indicator.CanQuery = false
	indicator.CanTouch = false
	indicator.CastShadow = false
	indicator.Massless = true
	indicator.CollisionGroup = Config.CollisionGroupComponents
	indicator.Parent = model

	local indWeld = Instance.new("WeldConstraint")
	indWeld.Name = "WZ_IndicatorWeld"
	indWeld.Part0 = root
	indWeld.Part1 = indicator
	indWeld.Parent = indicator

	return root
end

function PistonBuilder.ResetInternalState(model: Model)
	local root = model.PrimaryPart
	local plunger = model:FindFirstChild("WZ_PistonPlunger")
	if root == nil or plunger == nil or not plunger:IsA("BasePart") then
		return
	end

	local prismatic = root:FindFirstChild("WZ_PistonConstraint")
	if prismatic ~= nil and prismatic:IsA("PrismaticConstraint") then
		prismatic.ActuatorType = Enum.ActuatorType.None
		prismatic.TargetPosition = 0
	end

	plunger.AssemblyLinearVelocity = Vector3.zero
	plunger.AssemblyAngularVelocity = Vector3.zero
	plunger.CFrame = root.CFrame * REST_PLUNGER_OFFSET
	plunger.Anchored = true
end

function PistonBuilder.SetAnchored(model: Model, anchored: boolean)
	local root = model.PrimaryPart
	local plunger = model:FindFirstChild("WZ_PistonPlunger")
	if root == nil or plunger == nil or not plunger:IsA("BasePart") then
		return
	end

	root.Anchored = anchored
	plunger.Anchored = anchored
end

return table.freeze(PistonBuilder)
