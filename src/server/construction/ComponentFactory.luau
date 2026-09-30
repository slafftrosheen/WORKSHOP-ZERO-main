--!strict

--[[
	ComponentFactory

	Everything that knows how a Workshop Zero component is built: geometry,
	attributes, connectors and the DragDetector that lets a player pick it up.

	It deliberately knows nothing about simulation state, snapping rules or
	challenges. Other modules ask it for components and connectors; those
	modules decide what the components mean.

	Component contract (see docs/ARCHITECTURE.md):

		Model             WZ_Component = true
		                  WZ_ComponentId = unique per server session
		                  WZ_ComponentType = "Plank" | "Block" | "Wheel" | ...
		                  PrimaryPart = Root

		Root (BasePart)   the visible geometry for prototype components
		                  holds the connector Attachments and the DragDetector

		Attachment        WZ_Connector = true
		                  WZ_ConnectorType = "Rigid" | "Axle"
		                  WZ_Occupied = true once it is part of a connection

	Connector orientation is defined by the Attachment's own CFrame, so the
	kernel never invents a second transform representation.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ComponentDefinitions = require(Shared.construction.ComponentDefinitions)
local ConnectorTypes = require(Shared.construction.ConnectorTypes)
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)

local Config = ConstructionConfig

local ComponentFactory = {}

local componentsContainer: Instance? = nil
local connectionsContainer: Instance? = nil

-- Live components for this server session, so a component can be resolved from
-- an id a client sent us instead of from an instance a client sent us.
local registry: { [string]: Model } = {}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ] %s", message))
	end
end

local function ensureFolder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing ~= nil then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Scene wiring ---------------------------------------------------------------

function ComponentFactory.SetRuntime(runtime: Instance)
	componentsContainer = ensureFolder(runtime, Config.ComponentsFolderName)
	connectionsContainer = ensureFolder(runtime, Config.ConnectionsFolderName)
end

function ComponentFactory.GetConnectionsContainer(): Instance?
	return connectionsContainer
end

-- Lookups --------------------------------------------------------------------

function ComponentFactory.IsComponent(value: Instance?): boolean
	if value == nil then
		return false
	end

	return value:GetAttribute(Config.AttributeComponent) == true
end

function ComponentFactory.GetComponent(instance: Instance?): Model?
	local current: Instance? = instance
	while current ~= nil do
		if current:IsA("Model") and ComponentFactory.IsComponent(current) then
			return current
		end

		current = current.Parent
	end

	return nil
end

function ComponentFactory.GetComponentId(model: Model): string?
	return ComponentFactory.GetStringAttribute(model, Config.AttributeComponentId)
end

function ComponentFactory.GetComponentType(model: Model): ConstructionTypes.ComponentType?
	return ConstructionTypes.ToComponentType(model:GetAttribute(Config.AttributeComponentType))
end

function ComponentFactory.GetStringAttribute(instance: Instance, attribute: string): string?
	local value = instance:GetAttribute(attribute)
	if type(value) == "string" then
		return value
	end

	return nil
end

function ComponentFactory.FindComponentById(componentId: string): Model?
	local model = registry[componentId]
	if model ~= nil and model.Parent ~= nil then
		return model
	end

	return nil
end

function ComponentFactory.GetComponents(): { Model }
	local result: { Model } = {}
	for _, model in registry do
		if model.Parent ~= nil then
			table.insert(result, model)
		end
	end

	return result
end

function ComponentFactory.GetRoot(model: Model): BasePart?
	return model.PrimaryPart
end

function ComponentFactory.GetDragDetector(model: Model): DragDetector?
	local root = model.PrimaryPart
	if root == nil then
		return nil
	end

	local detector = root:FindFirstChild(Config.DragDetectorName)
	if detector ~= nil and detector:IsA("DragDetector") then
		return detector
	end

	return nil
end

-- Connectors -----------------------------------------------------------------

function ComponentFactory.GetConnectors(model: Model): { Attachment }
	local result: { Attachment } = {}
	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("Attachment")
			and descendant:GetAttribute(Config.AttributeConnector) == true
		then
			table.insert(result, descendant)
		end
	end

	return result
end

function ComponentFactory.GetConnector(model: Model, connectorName: string): Attachment?
	local descendant = model:FindFirstChild(connectorName, true)
	if descendant ~= nil and descendant:IsA("Attachment") then
		return descendant
	end

	return nil
end

function ComponentFactory.GetConnectorType(attachment: Attachment): ConstructionTypes.ConnectorType?
	return ConnectorTypes.ToConnectorType(attachment:GetAttribute(Config.AttributeConnectorType))
end

function ComponentFactory.IsConnectorOccupied(attachment: Attachment): boolean
	return attachment:GetAttribute(Config.AttributeOccupied) == true
end

function ComponentFactory.SetConnectorOccupied(attachment: Attachment, occupied: boolean)
	attachment:SetAttribute(Config.AttributeOccupied, occupied)
end

function ComponentFactory.GetFreeConnectors(
	model: Model,
	connectorType: ConstructionTypes.ConnectorType?
): { Attachment }
	local result: { Attachment } = {}
	for _, attachment in ComponentFactory.GetConnectors(model) do
		if not ComponentFactory.IsConnectorOccupied(attachment) then
			local attachmentType = ComponentFactory.GetConnectorType(attachment)
			if connectorType == nil or attachmentType == connectorType then
				table.insert(result, attachment)
			end
		end
	end

	return result
end

-- Creation -------------------------------------------------------------------

function ComponentFactory.Create(
	componentType: ConstructionTypes.ComponentType,
	pivot: CFrame
): Model?
	local definition = ComponentDefinitions.Get(componentType)
	if definition == nil then
		log(string.format("Refused to create unknown component type %q", componentType))
		return nil
	end

	if not definition.Spawnable then
		log(string.format("Refused to create %s: not spawnable yet", definition.DisplayName))
		return nil
	end

	if componentsContainer == nil then
		log("Refused to create a component: no runtime container was set")
		return nil
	end

	local componentId = HttpService:GenerateGUID(false)
	local model = Instance.new("Model")
	model.Name = string.format("WZ_%s_%s", definition.DisplayName, string.sub(componentId, 1, 6))
	model:SetAttribute(Config.AttributeComponent, true)
	model:SetAttribute(Config.AttributeComponentId, componentId)
	model:SetAttribute(Config.AttributeComponentType, definition.Type)

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
	root.Parent = model

	for _, connector in definition.Connectors do
		local attachment = Instance.new("Attachment")
		attachment.Name = connector.Name
		attachment.CFrame = connector.Offset
		attachment:SetAttribute(Config.AttributeConnector, true)
		attachment:SetAttribute(Config.AttributeConnectorType, connector.Type)
		attachment:SetAttribute(Config.AttributeOccupied, false)
		attachment.Parent = root
	end

	model.PrimaryPart = root

	-- RunLocally = false means the drag is performed by the server and all drag
	-- events fire in server scripts, so placement stays authoritative.
	local dragDetector = Instance.new("DragDetector")
	dragDetector.Name = Config.DragDetectorName
	dragDetector.RunLocally = false
	dragDetector.PermissionPolicy = Enum.DragDetectorPermissionPolicy.Everybody
	dragDetector.DragStyle = Enum.DragDetectorDragStyle.TranslatePlaneOrLine
	dragDetector.ResponseStyle = Enum.DragDetectorResponseStyle.Geometric
	dragDetector.Enabled = true
	dragDetector.Parent = root

	model:PivotTo(pivot)
	model.Parent = componentsContainer

	registry[componentId] = model
	model.Destroying:Connect(function()
		if registry[componentId] == model then
			registry[componentId] = nil
		end
	end)

	log(string.format("Created %s (%s)", model.Name, definition.DisplayName))

	return model
end

-- State helpers used by the simulation ---------------------------------------

function ComponentFactory.SetDraggingEnabled(enabled: boolean)
	for _, model in ComponentFactory.GetComponents() do
		local dragDetector = ComponentFactory.GetDragDetector(model)
		if dragDetector ~= nil then
			dragDetector.Enabled = enabled
		end
	end
end

-- Only Workshop Zero components are anchored or unanchored. The floor, the
-- build bounds and everything else in the world are left alone.
function ComponentFactory.SetComponentsAnchored(anchored: boolean)
	for _, model in ComponentFactory.GetComponents() do
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = anchored
			end
		end
	end
end

return table.freeze(ComponentFactory)
