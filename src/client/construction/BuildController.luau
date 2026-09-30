--!strict

--[[
	BuildController

	The client half of BUILD: pick a component, keep it highlighted, ask the
	server to rotate or disconnect it, and show where a snap would happen while
	something is being dragged.

	It decides nothing. Rotation and disconnection are requests that the server
	validates, and the snap preview is a local guess that deliberately uses the
	same distance and angle numbers as the server's real snap search, so the
	green marker rarely promises something the server refuses.

	The preview exists because a server-run drag has no local feedback of its
	own: without it, the player would be aligning connectors blind.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)

local Config = ConstructionConfig
local player = Players.LocalPlayer

local BuildController = {}

-- Structural shape of the control panel. Declared here rather than imported so
-- the client's construction code never depends on the client's UI code.
export type ControlsHandle = {
	SetState: (state: ConstructionTypes.SimulationState) -> (),
	SetSelection: (name: string?) -> (),
	IsPointerOverPanel: (position: Vector3) -> boolean,
}

type Preview = {
	Position: Vector3,
	Target: Model,
}

local FACING_FLIP = CFrame.Angles(0, math.pi, 0)

local KEY_OPERATIONS: { [Enum.KeyCode]: ConstructionTypes.RotationOperation } = {
	[Enum.KeyCode.Q] = "YawLeft",
	[Enum.KeyCode.E] = "YawRight",
	[Enum.KeyCode.R] = "Flip",
}

local state: ConstructionTypes.SimulationState = "Build"
local selection: Model? = nil
local draggingComponentId: string? = nil
local remotes: ConstructionTypes.ConstructionRemotes? = nil
local controls: ControlsHandle? = nil
local highlight: Highlight? = nil
local previewHighlight: Highlight? = nil
local previewSphere: Part? = nil

-- Reading the world ----------------------------------------------------------

local function findComponent(instance: Instance?): Model?
	local current: Instance? = instance
	while current ~= nil do
		if current:IsA("Model") and current:GetAttribute(Config.AttributeComponent) == true then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function componentIdOf(model: Model): string?
	local value = model:GetAttribute(Config.AttributeComponentId)
	if type(value) == "string" then
		return value
	end

	return nil
end

local function componentName(model: Model): string
	local value = model:GetAttribute(Config.AttributeComponentType)
	if type(value) == "string" then
		return value
	end

	return model.Name
end

local function getRuntimeComponents(): { Model }
	local result: { Model } = {}

	local runtime = Workspace:FindFirstChild(Config.RuntimeFolderName)
	if runtime == nil then
		return result
	end

	local container = runtime:FindFirstChild(Config.ComponentsFolderName)
	if container == nil then
		return result
	end

	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			table.insert(result, child)
		end
	end

	return result
end

local function findComponentById(componentId: string): Model?
	for _, model in getRuntimeComponents() do
		if componentIdOf(model) == componentId then
			return model
		end
	end

	return nil
end

local function connectorsOf(model: Model): { Attachment }
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

local function connectorTypeOf(attachment: Attachment): ConstructionTypes.ConnectorType?
	local value = attachment:GetAttribute(Config.AttributeConnectorType)
	if value == "Rigid" or value == "Axle" then
		return value
	end

	return nil
end

local function isFreeConnector(attachment: Attachment): boolean
	return attachment:GetAttribute(Config.AttributeOccupied) ~= true
end

--[[
	Same search the server performs in ConnectorService.FindCandidate, using the
	same configuration. The server still decides; this only decides what to draw.
]]
local function findPreview(movingModel: Model): Preview?
	local minAlignment = math.cos(math.rad(Config.SnapAngleToleranceDegrees))
	local best: Preview? = nil
	local bestScore = math.huge
	local components = getRuntimeComponents()

	for _, moving in connectorsOf(movingModel) do
		if isFreeConnector(moving) then
			local movingType = connectorTypeOf(moving)

			if movingType ~= nil then
				for _, component in components do
					if component ~= movingModel then
						for _, target in connectorsOf(component) do
							if
								isFreeConnector(target)
								and connectorTypeOf(target) == movingType
							then
								local targetPosition = target.WorldCFrame.Position
								local distance = (moving.WorldCFrame.Position - targetPosition).Magnitude

								if distance <= Config.SnapDistance then
									local desired = target.WorldCFrame * FACING_FLIP
									local alignment =
										math.abs(desired.XVector:Dot(moving.WorldCFrame.XVector))

									if alignment >= minAlignment then
										local score = distance + (1 - alignment)
										if score < bestScore then
											bestScore = score
											best = { Position = targetPosition, Target = component }
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	return best
end

-- Visuals --------------------------------------------------------------------

local function hidePreview()
	if previewSphere ~= nil then
		previewSphere.Transparency = 1
	end

	if previewHighlight ~= nil then
		previewHighlight.Enabled = false
	end
end

local function updatePreview()
	local sphere = previewSphere
	local marker = previewHighlight
	if sphere == nil or marker == nil then
		return
	end

	if state ~= "Build" or draggingComponentId == nil then
		hidePreview()
		return
	end

	local moving = findComponentById(draggingComponentId)
	local preview = if moving ~= nil then findPreview(moving) else nil

	if preview == nil then
		hidePreview()
		return
	end

	sphere.Position = preview.Position
	sphere.Transparency = 0.45
	marker.Adornee = preview.Target
	marker.Enabled = true
end

local function setSelection(model: Model?)
	selection = model

	if highlight ~= nil then
		highlight.Adornee = model
		highlight.Enabled = model ~= nil and state == "Build"
	end

	if controls ~= nil then
		controls.SetSelection(if model ~= nil then componentName(model) else nil)
	end
end

-- Requests -------------------------------------------------------------------

local function requestOnSelection(operation: ConstructionTypes.RotationOperation?)
	local remoteSet = remotes
	local model = selection

	if remoteSet == nil or model == nil or model.Parent == nil then
		return
	end

	local componentId = componentIdOf(model)
	if componentId == nil then
		return
	end

	if operation ~= nil then
		remoteSet.RequestRotation:FireServer({ ComponentId = componentId, Operation = operation })
	else
		remoteSet.RequestDisconnect:FireServer({ ComponentId = componentId })
	end
end

local function pickComponentAt(position: Vector3): Model?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end

	local ray = camera:ViewportPointToRay(position.X, position.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local character = player.Character
	if character ~= nil then
		params.FilterDescendantsInstances = { character }
	end

	local result = Workspace:Raycast(ray.Origin, ray.Direction * Config.SelectionRayLength, params)
	if result == nil then
		return nil
	end

	return findComponent(result.Instance)
end

-- Wiring ---------------------------------------------------------------------

function BuildController.Start(
	remoteSet: ConstructionTypes.ConstructionRemotes,
	controlsHandle: ControlsHandle
)
	remotes = remoteSet
	controls = controlsHandle

	local selectionHighlight = Instance.new("Highlight")
	selectionHighlight.Name = "WZ_SelectionHighlight"
	selectionHighlight.FillColor = Color3.fromRGB(90, 180, 255)
	selectionHighlight.FillTransparency = 0.75
	selectionHighlight.OutlineColor = Color3.fromRGB(200, 235, 255)
	selectionHighlight.Enabled = false
	selectionHighlight.Parent = Workspace
	highlight = selectionHighlight

	local snapHighlight = Instance.new("Highlight")
	snapHighlight.Name = "WZ_SnapHighlight"
	snapHighlight.FillColor = Color3.fromRGB(120, 230, 140)
	snapHighlight.FillTransparency = 0.8
	snapHighlight.OutlineColor = Color3.fromRGB(190, 255, 200)
	snapHighlight.Enabled = false
	snapHighlight.Parent = Workspace
	previewHighlight = snapHighlight

	local sphere = Instance.new("Part")
	sphere.Name = "WZ_SnapPreview"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.one * Config.PreviewSphereDiameter
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.CastShadow = false
	sphere.Color = Color3.fromRGB(130, 240, 150)
	sphere.Material = Enum.Material.Neon
	sphere.Transparency = 1
	sphere.Parent = Workspace
	previewSphere = sphere

	local function applyState(value: string)
		state = ConstructionTypes.ToSimulationState(value) or "Build"
		controlsHandle.SetState(state)

		if highlight ~= nil then
			highlight.Enabled = selection ~= nil and state == "Build"
		end

		if state ~= "Build" then
			setSelection(nil)
			hidePreview()
		end
	end

	applyState(remoteSet.SimulationState.Value)

	remoteSet.SimulationState:GetPropertyChangedSignal("Value"):Connect(function()
		applyState(remoteSet.SimulationState.Value)
	end)

	-- The server tells this player which component it is dragging, so the
	-- preview only appears for the player actually holding something.
	remoteSet.DragStateChanged.OnClientEvent:Connect(function(componentId: unknown)
		-- Validate at the wire, exactly like the server validates its own inputs.
		if type(componentId) == "string" then
			draggingComponentId = componentId :: string
		else
			draggingComponentId = nil
		end

		updatePreview()
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or state ~= "Build" then
			return
		end

		local operation = KEY_OPERATIONS[input.KeyCode]
		if operation ~= nil then
			requestOnSelection(operation)
			return
		end

		if input.KeyCode == Enum.KeyCode.X then
			requestOnSelection(nil)
			return
		end

		local isPointerDown = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch

		if isPointerDown then
			if controlsHandle.IsPointerOverPanel(input.Position) then
				return
			end

			setSelection(pickComponentAt(input.Position))
		end
	end)

	RunService.RenderStepped:Connect(function()
		if state ~= "Build" then
			return
		end

		if draggingComponentId ~= nil then
			updatePreview()
		end
	end)
end

return table.freeze(BuildController)
