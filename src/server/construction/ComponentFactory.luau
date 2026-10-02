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
local AssetProvider = require(script.Parent.Parent.assets.AssetProvider)
local SpringBuilder = require(script.Parent.builders.SpringBuilder)
local FanBuilder = require(script.Parent.builders.FanBuilder)
local LogicConfig = require(Shared.logic.LogicConfig)

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

--[[
	Small socket geometry so a child can see where a part will connect.

	Rigid is a flat plate, Axle is a round cap: the difference is a shape, not
	only a colour. Markers are welded to the root, massless, non-colliding and
	invisible to raycasts, so they are presentation and never physics.
]]
local function createConnectorMarker(
	attachment: Attachment,
	connectorType: ConstructionTypes.ConnectorType
)
	if not Config.ShowConnectorMarkers then
		return
	end

	local root = attachment.Parent
	if root == nil or not root:IsA("BasePart") then
		return
	end

	local isRigid = ConnectorTypes.IsRigid(connectorType)
	local isRope = connectorType == "Rope"

	local marker = Instance.new("Part")
	marker.Name = string.format("%s_%s", Config.ConnectorMarkerName, attachment.Name)
	marker.Shape = if isRigid then Enum.PartType.Block else Enum.PartType.Cylinder
	marker.Size = if isRigid
		then Config.RigidMarkerSize
		elseif isRope then Config.RopeMarkerSize
		else Config.AxleMarkerSize
	marker.Color = if isRigid
		then Color3.fromRGB(120, 138, 158)
		elseif isRope then Color3.fromRGB(195, 205, 220)
		else Color3.fromRGB(78, 84, 98)
	marker.Material = if isRigid then Enum.Material.SmoothPlastic else Enum.Material.Metal
	marker.Anchored = false
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Massless = true
	marker.CollisionGroup = Config.CollisionGroupComponents

	-- A flat plate is thin along its own Y axis, so roll it onto the connector's
	-- X axis. A cylinder already spins around X, which is the axle/rope direction.
	local markerCFrame = if isRigid
		then attachment.WorldCFrame * CFrame.Angles(0, 0, math.rad(-90))
		else attachment.WorldCFrame

	marker.CFrame = markerCFrame
	marker:SetAttribute("WZ_ConnectorMarker", true)
	marker:SetAttribute(Config.AttributeConnectorType, connectorType)
	marker.Parent = root.Parent or root

	local weld = Instance.new("WeldConstraint")
	weld.Name = "WZ_SocketWeld"
	weld.Part0 = root
	weld.Part1 = marker
	weld.Parent = marker

	-- For rope, add a contrasting center hole so it visually reads as an eyelet loop
	if isRope then
		local hole = Instance.new("Part")
		hole.Name = "Hole"
		hole.Shape = Enum.PartType.Cylinder
		hole.Size = Vector3.new(
			Config.RopeMarkerSize.X + 0.05,
			Config.RopeMarkerSize.Y * 0.45,
			Config.RopeMarkerSize.Z * 0.45
		)
		hole.Color = Color3.fromRGB(42, 45, 52)
		hole.Material = Enum.Material.Metal
		hole.Anchored = false
		hole.CanCollide = false
		hole.CanQuery = false
		hole.CanTouch = false
		hole.CastShadow = false
		hole.Massless = true
		hole.CollisionGroup = Config.CollisionGroupComponents
		hole.CFrame = markerCFrame
		hole.Parent = marker

		local holeWeld = Instance.new("WeldConstraint")
		holeWeld.Name = "WZ_HoleWeld"
		holeWeld.Part0 = marker
		holeWeld.Part1 = hole
		holeWeld.Parent = hole
	end
end

--[[
	Visible signal socket geometry so a child can see where a signal port lives.
	Shape distinguishes Input (Block) from Output (Cylinder). Markers are welded
	to the root, massless, non-colliding and invisible to raycasts, so they are
	presentation and never physics.
]]
local function createSignalSocketMarker(attachment: Attachment, direction: "Input" | "Output")
	if not LogicConfig.ShowSignalMarkers then
		return
	end

	local root = attachment.Parent
	if root == nil or not root:IsA("BasePart") then
		return
	end

	local isInput = direction == "Input"
	local shape = if isInput
		then LogicConfig.SignalMarkerInputShape
		else LogicConfig.SignalMarkerOutputShape

	local marker = Instance.new("Part")
	marker.Name = string.format("%s_%s", LogicConfig.SignalMarkerName, attachment.Name)
	marker.Shape = shape
	marker.Size = LogicConfig.SignalMarkerSize
	marker.Color = LogicConfig.SignalSocketColor
	marker.Material = Enum.Material.SmoothPlastic
	marker.Anchored = false
	marker.CanCollide = false
	marker.CanQuery = true
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Massless = true
	marker.CollisionGroup = Config.CollisionGroupComponents

	local markerCFrame = attachment.WorldCFrame
	marker.CFrame = markerCFrame
	marker:SetAttribute("WZ_SignalSocketMarker", true)
	marker:SetAttribute(Config.AttributeSignalDirection, direction)
	marker:SetAttribute(Config.AttributeSignalPortName, attachment.Name)
	marker.Parent = root.Parent or root

	local weld = Instance.new("WeldConstraint")
	weld.Name = "WZ_SignalSocketWeld"
	weld.Part0 = root
	weld.Part1 = marker
	weld.Parent = marker

	-- Recessed center hole
	local hole = Instance.new("Part")
	hole.Name = "Hole"
	hole.Shape = shape
	hole.Size = LogicConfig.SignalMarkerSize * Vector3.new(0.5, 1.2, 0.5)
	hole.Color = Color3.fromRGB(15, 20, 35)
	hole.Material = Enum.Material.SmoothPlastic
	hole.Anchored = false
	hole.CanCollide = false
	hole.CanQuery = false
	hole.CanTouch = false
	hole.CastShadow = false
	hole.Massless = true
	hole.CollisionGroup = Config.CollisionGroupComponents
	hole.CFrame = markerCFrame
	hole.Parent = marker

	local holeWeld = Instance.new("WeldConstraint")
	holeWeld.Name = "WZ_SignalSocketHoleWeld"
	holeWeld.Part0 = marker
	holeWeld.Part1 = hole
	holeWeld.Parent = hole
end

local function buildAutomationVisuals(
	model: Model,
	definition: ConstructionTypes.ComponentDefinition,
	root: BasePart
)
	local cType = definition.Type

	if cType == "Switch" then
		model:SetAttribute("WZ_SwitchState", false)

		-- Indicator light
		local indicator = Instance.new("Part")
		indicator.Name = "WZ_SwitchIndicator"
		indicator.Shape = Enum.PartType.Cylinder
		indicator.Size = Vector3.new(0.12, 0.4, 0.4)
		indicator.CFrame = root.CFrame
			* CFrame.new(-0.5, 0.81, 0)
			* CFrame.Angles(0, 0, math.rad(90))
		indicator.Color = Color3.fromRGB(50, 55, 65)
		indicator.Material = Enum.Material.SmoothPlastic
		indicator.Anchored = false
		indicator.CanCollide = false
		indicator.CanQuery = false
		indicator.CanTouch = false
		indicator.Massless = true
		indicator.Parent = model

		local indWeld = Instance.new("WeldConstraint")
		indWeld.Name = "WZ_SwitchIndWeld"
		indWeld.Part0 = root
		indWeld.Part1 = indicator
		indWeld.Parent = indicator

		-- Toggle lever
		local lever = Instance.new("Part")
		lever.Name = "WZ_SwitchLever"
		lever.Size = Vector3.new(0.2, 0.7, 0.2)
		lever.Color = Color3.fromRGB(200, 205, 215)
		lever.Material = Enum.Material.Metal
		lever.Anchored = false
		lever.CanCollide = false
		lever.CanQuery = true
		lever.CanTouch = false
		lever.Massless = true
		lever.CFrame = root.CFrame * CFrame.new(0.2, 0.95, 0) * CFrame.Angles(0, 0, math.rad(-20))
		lever.Parent = model

		local leverWeld = Instance.new("WeldConstraint")
		leverWeld.Name = "WZ_SwitchLeverWeld"
		leverWeld.Part0 = root
		leverWeld.Part1 = lever
		leverWeld.Parent = lever

		-- ProximityPrompt for player interaction
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TogglePrompt"
		prompt.ActionText = "Flip"
		prompt.ObjectText = "Switch"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 12
		prompt.HoldDuration = 0
		prompt.Parent = lever

		prompt.Triggered:Connect(function()
			local current = model:GetAttribute("WZ_SwitchState") == true
			local newState = not current
			model:SetAttribute("WZ_SwitchState", newState)

			indicator.Material = if newState
				then Enum.Material.Neon
				else Enum.Material.SmoothPlastic
			indicator.Color = if newState
				then Color3.fromRGB(80, 240, 120)
				else Color3.fromRGB(50, 55, 65)

			local angle = if newState then math.rad(20) else math.rad(-20)
			lever.CFrame = root.CFrame * CFrame.new(0.2, 0.95, 0) * CFrame.Angles(0, 0, angle)
		end)
	elseif cType == "PressureSensor" then
		-- Movable / visual pressure pad on top
		local pad = Instance.new("Part")
		pad.Name = "Pad"
		pad.Size = Vector3.new(2.6, 0.25, 2.6)
		pad.CFrame = root.CFrame * CFrame.new(0, 0.45, 0)
		pad.Color = Color3.fromRGB(45, 120, 230)
		pad.Material = Enum.Material.SmoothPlastic
		pad.Anchored = false
		pad.CanCollide = true
		pad.CanTouch = true
		pad.Massless = true
		pad.Parent = model

		local padWeld = Instance.new("WeldConstraint")
		padWeld.Name = "WZ_PadWeld"
		padWeld.Part0 = root
		padWeld.Part1 = pad
		padWeld.Parent = pad

		local indicator = Instance.new("Part")
		indicator.Name = "WZ_SensorIndicator"
		indicator.Shape = Enum.PartType.Cylinder
		indicator.Size = Vector3.new(0.08, 0.4, 0.4)
		indicator.CFrame = root.CFrame * CFrame.new(0, 0.58, 0) * CFrame.Angles(0, 0, math.rad(90))
		indicator.Color = Color3.fromRGB(40, 50, 70)
		indicator.Material = Enum.Material.SmoothPlastic
		indicator.Anchored = false
		indicator.CanCollide = false
		indicator.CanTouch = false
		indicator.Massless = true
		indicator.Parent = model

		local indWeld = Instance.new("WeldConstraint")
		indWeld.Name = "WZ_IndWeld"
		indWeld.Part0 = root
		indWeld.Part1 = indicator
		indWeld.Parent = indicator
	elseif cType == "ProximitySensor" then
		-- Front sensor lens window (+X direction)
		local lens = Instance.new("Part")
		lens.Name = "WZ_SensorLens"
		lens.Size = Vector3.new(0.2, 1.2, 1.2)
		lens.CFrame = root.CFrame * CFrame.new(0.95, 0, 0)
		lens.Color = Color3.fromRGB(40, 60, 90)
		lens.Material = Enum.Material.SmoothPlastic
		lens.Anchored = false
		lens.CanCollide = false
		lens.CanTouch = false
		lens.Massless = true
		lens.Parent = model

		local lensWeld = Instance.new("WeldConstraint")
		lensWeld.Name = "WZ_LensWeld"
		lensWeld.Part0 = root
		lensWeld.Part1 = lens
		lensWeld.Parent = lens
	elseif cType == "SignalLamp" then
		-- Translucent / glowing dome lamp bulb on top
		local bulb = Instance.new("Part")
		bulb.Name = "WZ_LampBulb"
		bulb.Shape = Enum.PartType.Ball
		bulb.Size = Vector3.new(1.1, 1.1, 1.1)
		bulb.CFrame = root.CFrame * CFrame.new(0, 0.65, 0)
		bulb.Color = Color3.fromRGB(20, 50, 30)
		bulb.Material = Enum.Material.SmoothPlastic
		bulb.Anchored = false
		bulb.CanCollide = false
		bulb.CanTouch = false
		bulb.Massless = true
		bulb.Parent = model

		local bulbWeld = Instance.new("WeldConstraint")
		bulbWeld.Name = "WZ_BulbWeld"
		bulbWeld.Part0 = root
		bulbWeld.Part1 = bulb
		bulbWeld.Parent = bulb
	elseif cType == "AND" or cType == "OR" or cType == "NOT" or cType == "Timer" then
		-- Large readable typography SurfaceGui on top face (+Y)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "LabelGui"
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Adornee = root
		gui.Parent = model

		local label = Instance.new("TextLabel")
		label.Name = "GateName"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 36
		label.TextColor3 = Color3.fromRGB(40, 44, 52)
		label.Text = cType
		label.Parent = gui
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

-- Signal ports ---------------------------------------------------------------

function ComponentFactory.GetSignalPorts(model: Model): { Attachment }
	local result: { Attachment } = {}
	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("Attachment")
			and descendant:GetAttribute(Config.AttributeSignalPort) == true
		then
			table.insert(result, descendant)
		end
	end

	return result
end

function ComponentFactory.GetSignalPortDirection(attachment: Attachment): "Input" | "Output"?
	local value = attachment:GetAttribute(Config.AttributeSignalDirection)
	if type(value) == "string" then
		return ConstructionTypes.ToSignalPortDirection(value)
	end

	return nil
end

function ComponentFactory.GetSignalPort(model: Model, portName: string): Attachment?
	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("Attachment")
			and descendant:GetAttribute(Config.AttributeSignalPort) == true
			and descendant:GetAttribute(Config.AttributeSignalPortName) == portName
		then
			return descendant
		end
	end

	return nil
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
	if RunService:IsStudio() and registry[componentId] ~= nil then
		warn(string.format("[WZ] Diagnostic: duplicate ComponentId %s detected", componentId))
	end

	local model = Instance.new("Model")
	model.Name = string.format("WZ_%s_%s", definition.DisplayName, string.sub(componentId, 1, 6))
	model:SetAttribute(Config.AttributeComponent, true)
	model:SetAttribute(Config.AttributeComponentId, componentId)
	model:SetAttribute(Config.AttributeComponentType, definition.Type)
	model:SetAttribute("WZ_SpawnPivot", pivot)

	local root: Part
	if definition.Type == "Spring" then
		root = SpringBuilder.Build(model, componentId, definition)
	elseif definition.Type == "Fan" then
		root = FanBuilder.Build(model, componentId, definition)
	else
		local part = Instance.new("Part")
		part.Name = Config.RootPartName
		part.Shape = definition.Shape
		part.Size = definition.Size
		part.Color = definition.Color
		part.Material = definition.Material
		part.Anchored = true
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = false
		part.CastShadow = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CustomPhysicalProperties =
			PhysicalProperties.new(definition.Density, definition.Friction, definition.Elasticity)
		part.Parent = model

		for _, connector in definition.Connectors do
			local attachment = Instance.new("Attachment")
			attachment.Name = connector.Name
			attachment.CFrame = connector.Offset
			attachment:SetAttribute(Config.AttributeConnector, true)
			attachment:SetAttribute(Config.AttributeConnectorType, connector.Type)
			attachment:SetAttribute(Config.AttributeOccupied, false)
			attachment.Parent = part
		end

		root = part
	end

	root.CollisionGroup = Config.CollisionGroupComponents
	model.PrimaryPart = root

	-- Signal ports (for automation-layer components). Mechanical-only
	-- components omit this field, so the loop is skipped entirely.
	if definition.SignalPorts ~= nil then
		for _, signalPort in definition.SignalPorts do
			local attachment = Instance.new("Attachment")
			attachment.Name = signalPort.Name
			attachment.CFrame = signalPort.Offset
			attachment:SetAttribute(Config.AttributeSignalPort, true)
			attachment:SetAttribute(Config.AttributeSignalDirection, signalPort.Direction)
			attachment:SetAttribute(Config.AttributeSignalPortName, signalPort.Name)
			attachment.Parent = root
		end
	end

	-- Optional visual asset bridge: if a custom imported model exists for this
	-- component, weld it over the Root collider, then hide the primitive.  The
	-- Root stays the authoritative physics body and the DragDetector target.
	local visual = AssetProvider.Get("Components", definition.DisplayName)
	if visual ~= nil then
		-- Align before welding: a WeldConstraint captures the offset it finds and
		-- would undo an alignment applied afterwards.  Measuring the mesh means
		-- the exporter's pivot choice cannot float the art off its sockets.
		if AssetProvider.AlignVisual(visual, root.CFrame, "Center") then
			visual.Parent = model

			for _, descendant in visual:GetDescendants() do
				if descendant:IsA("BasePart") then
					local weld = Instance.new("WeldConstraint")
					weld.Name = "WZ_VisualWeld"
					weld.Part0 = root
					weld.Part1 = descendant
					weld.Parent = descendant
				end
			end

			AssetProvider.HidePrimitives(model)
		else
			visual:Destroy()
			log(
				string.format(
					"%s custom visual has no visible geometry, using primitive",
					definition.DisplayName
				)
			)
		end
	end

	if visual == nil or visual.Parent == nil then
		-- Procedural accents when custom visual is not present
		if definition.Type == "Hook" then
			local hookClaw = Instance.new("Part")
			hookClaw.Name = "HookClaw"
			hookClaw.Shape = Enum.PartType.Wedge
			hookClaw.Size = Vector3.new(0.6, 1.2, 0.8)
			hookClaw.Color = Color3.fromRGB(65, 70, 80)
			hookClaw.Material = Enum.Material.Metal
			hookClaw.CFrame = root.CFrame
				* CFrame.new(0, -0.2, 0.7)
				* CFrame.Angles(math.rad(180), 0, 0)
			hookClaw.Anchored = false
			hookClaw.CanCollide = false
			hookClaw.CanQuery = false
			hookClaw.CanTouch = false
			hookClaw.Massless = true
			hookClaw.CollisionGroup = Config.CollisionGroupComponents
			hookClaw.Parent = model

			local clawWeld = Instance.new("WeldConstraint")
			clawWeld.Name = "WZ_HookWeld"
			clawWeld.Part0 = root
			clawWeld.Part1 = hookClaw
			clawWeld.Parent = hookClaw
		elseif definition.Type == "Winch" then
			local drum = Instance.new("Part")
			drum.Name = "SpoolDrum"
			drum.Shape = Enum.PartType.Cylinder
			drum.Size = Vector3.new(1.0, 1.6, 1.6)
			drum.Color = Color3.fromRGB(50, 54, 62)
			drum.Material = Enum.Material.Metal
			drum.CFrame = root.CFrame * CFrame.new(0.6, 0, 0)
			drum.Anchored = false
			drum.CanCollide = false
			drum.CanQuery = false
			drum.CanTouch = false
			drum.Massless = true
			drum.CollisionGroup = Config.CollisionGroupComponents
			drum.Parent = model

			local drumWeld = Instance.new("WeldConstraint")
			drumWeld.Name = "WZ_DrumWeld"
			drumWeld.Part0 = root
			drumWeld.Part1 = drum
			drumWeld.Parent = drum

			local led = Instance.new("Part")
			led.Name = "WZ_WinchIndicator"
			led.Shape = Enum.PartType.Cylinder
			led.Size = Vector3.new(0.2, 0.5, 0.5)
			led.Color = Color3.fromRGB(50, 55, 65)
			led.Material = Enum.Material.SmoothPlastic
			led.CFrame = root.CFrame * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90))
			led.Anchored = false
			led.CanCollide = false
			led.CanQuery = false
			led.CanTouch = false
			led.Massless = true
			led.CollisionGroup = Config.CollisionGroupComponents
			led.Parent = model

			local ledWeld = Instance.new("WeldConstraint")
			ledWeld.Name = "WZ_IndicatorWeld"
			ledWeld.Part0 = root
			ledWeld.Part1 = led
			ledWeld.Parent = led
		end
	end

	-- Markers need the model's parts in place first, so they are created after
	-- the connectors and before the model is moved into the world.
	if Config.ShowConnectorMarkers then
		for _, connector in definition.Connectors do
			local attachment = root:FindFirstChild(connector.Name)
			if attachment ~= nil and attachment:IsA("Attachment") then
				createConnectorMarker(attachment, connector.Type)
			end
		end
	end

	-- Signal socket markers (for automation-layer components).
	if LogicConfig.ShowSignalMarkers and definition.SignalPorts ~= nil then
		for _, signalPort in definition.SignalPorts do
			local attachment = root:FindFirstChild(signalPort.Name)
			if attachment ~= nil and attachment:IsA("Attachment") then
				createSignalSocketMarker(attachment, signalPort.Direction)
			end
		end
	end

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

	-- Indicator for Motor components so powered status is visually readable in TEST.
	if definition.Type == "Motor" then
		local indicator = Instance.new("Part")
		indicator.Name = "WZ_MotorIndicator"
		indicator.Shape = Enum.PartType.Cylinder
		indicator.Size = Vector3.new(0.18, 0.7, 0.7)
		indicator.CFrame = root.CFrame * CFrame.new(0, 1.01, 0) * CFrame.Angles(0, 0, math.rad(90))
		indicator.Color = Color3.fromRGB(50, 55, 65)
		indicator.Material = Enum.Material.SmoothPlastic
		indicator.Anchored = false
		indicator.CanCollide = false
		indicator.CanQuery = false
		indicator.CanTouch = false
		indicator.CastShadow = false
		indicator.Massless = true
		indicator.CollisionGroup = Config.CollisionGroupComponents
		indicator.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Name = "WZ_IndicatorWeld"
		weld.Part0 = root
		weld.Part1 = indicator
		weld.Parent = indicator
	end

	buildAutomationVisuals(model, definition, root)

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
		if model:GetAttribute("WZ_StaticAnchor") == true then
			continue
		end

		local dragDetector = ComponentFactory.GetDragDetector(model)
		if dragDetector ~= nil then
			dragDetector.Enabled = enabled
		end
	end
end

-- Only Workshop Zero components are anchored or unanchored. The floor, the
-- build bounds and everything else in the world are left alone.
-- Components with internal mechanics (like Spring) handle internal moving parts appropriately.
function ComponentFactory.SetComponentsAnchored(anchored: boolean)
	for _, model in ComponentFactory.GetComponents() do
		if model:GetAttribute("WZ_StaticAnchor") == true then
			local primary = model.PrimaryPart
			if primary ~= nil then
				primary.Anchored = true
			end
			continue
		end

		local compType = model:GetAttribute(Config.AttributeComponentType)
		if compType == "Spring" then
			SpringBuilder.SetAnchored(model, anchored)
		else
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = anchored
				end
			end
		end
	end
end

-- Resets internal moving parts (such as Spring plungers) without affecting
-- user placement or construction connections.
function ComponentFactory.ResetInternalState(model: Model)
	local compType = model:GetAttribute(Config.AttributeComponentType)
	if compType == "Spring" then
		SpringBuilder.ResetInternalState(model)
	end
end

function ComponentFactory.ResetAllInternalState()
	for _, model in ComponentFactory.GetComponents() do
		ComponentFactory.ResetInternalState(model)
	end
end

-- Toggles socket marker visibility between BUILD and TEST modes.
function ComponentFactory.SetConnectorMarkersVisible(visible: boolean)
	for _, model in ComponentFactory.GetComponents() do
		for _, descendant in model:GetDescendants() do
			if
				descendant:IsA("BasePart")
				and string.find(descendant.Name, "^" .. Config.ConnectorMarkerName) ~= nil
			then
				descendant.Transparency = if visible then 0 else 1
			end
		end
	end
end

-- Clears the component registry and destroys any remaining components.
-- Used when transitioning between experiments.
function ComponentFactory.Clear()
	for _, model in registry do
		if model.Parent ~= nil then
			model:Destroy()
		end
	end
	table.clear(registry)
end

return table.freeze(ComponentFactory)
