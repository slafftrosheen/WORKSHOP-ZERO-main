--!strict

--[[
	WireController

	The client controller for control-signal wiring interaction:
		* Click/tap an Output socket to enter wiring mode
		* Shows live preview beam following the cursor to candidate inputs
		* Highlights compatible inputs and dims non-compatible sockets
		* Click an Input socket to request wire connection
		* Click an already-connected Input socket to request disconnect
		* Escape / right-click / background click cancels wiring mode
		* Shows small hover/tap tooltips on sockets ("OUTPUT", "CONTROL", etc.)
		* Adjusts socket visibility between BUILD (visible) and TEST (subtle)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)
local LogicConfig = require(Shared.logic.LogicConfig)

local Config = ConstructionConfig
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local WireController = {}

type WireSource = {
	ComponentId: string,
	PortName: string,
	Attachment: Attachment,
	Marker: BasePart,
}

local wireSource: WireSource? = nil
local simulationState = "Build"

-- Preview visual elements
local previewBeam: Beam? = nil
local previewTargetPart: Part? = nil

-- Hover tooltip
local socketTooltip: BillboardGui? = nil
local socketTooltipLabel: TextLabel? = nil

-- Helper to find a signal socket marker from a hit part
local function getSocketMarker(instance: Instance?): (BasePart?, string?, string?, string?)
	local current: Instance? = instance
	while current ~= nil do
		if current:IsA("BasePart") and current:GetAttribute("WZ_SignalSocketMarker") == true then
			local direction = current:GetAttribute(Config.AttributeSignalDirection)
			local portName = current:GetAttribute(Config.AttributeSignalPortName)
			-- Find component model
			local model = current:FindFirstAncestorOfClass("Model")
			local compId: string? = nil
			if model ~= nil then
				compId = model:GetAttribute(Config.AttributeComponentId)
			end
			if
				type(direction) == "string"
				and type(portName) == "string"
				and type(compId) == "string"
			then
				return current, compId, portName, direction
			end
		end
		current = current.Parent
	end

	return nil, nil, nil, nil
end

local function findPortAttachment(marker: BasePart): Attachment?
	local model = marker:FindFirstAncestorOfClass("Model")
	local portName = marker:GetAttribute(Config.AttributeSignalPortName)
	if model ~= nil and type(portName) == "string" then
		for _, descendant in model:GetDescendants() do
			if
				descendant:IsA("Attachment")
				and descendant:GetAttribute(Config.AttributeSignalPort) == true
				and descendant:GetAttribute(Config.AttributeSignalPortName) == portName
			then
				return descendant
			end
		end
	end
	return nil
end

local function cancelWiring()
	wireSource = nil
	if previewBeam ~= nil then
		previewBeam.Enabled = false
	end
	if previewTargetPart ~= nil then
		previewTargetPart.Transparency = 1
	end
end

local function setSocketsPresentation(isBuild: boolean)
	local container = Workspace:FindFirstChild("Workshop", true)
	if container == nil then
		return
	end

	for _, descendant in container:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and descendant:GetAttribute("WZ_SignalSocketMarker") == true
		then
			descendant.Transparency = if isBuild then 0 else 0.7
			local hole = descendant:FindFirstChild("Hole")
			if hole ~= nil and hole:IsA("BasePart") then
				hole.Transparency = if isBuild then 0 else 0.7
			end
		end
	end
end

function WireController.Start(remoteSet: ExperimentTypes.ExperimentRemotes)
	-- Create preview beam and movable target anchor
	local targetPart = Instance.new("Part")
	targetPart.Name = "WZ_WirePreviewTarget"
	targetPart.Size = Vector3.new(0.4, 0.4, 0.4)
	targetPart.Shape = Enum.PartType.Ball
	targetPart.Color = LogicConfig.WireColorActive
	targetPart.Material = Enum.Material.Neon
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.CastShadow = false
	targetPart.Transparency = 1
	targetPart.Parent = Workspace
	previewTargetPart = targetPart

	local targetAtt = Instance.new("Attachment")
	targetAtt.Name = "TargetAtt"
	targetAtt.Parent = targetPart

	local beam = Instance.new("Beam")
	beam.Name = "WZ_WirePreviewBeam"
	beam.Width0 = LogicConfig.WireThickness * 1.5
	beam.Width1 = LogicConfig.WireThickness * 1.5
	beam.Color = ColorSequence.new(LogicConfig.WireColorActive)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new(0.2)
	beam.FaceCamera = true
	beam.Segments = 10
	beam.Attachment1 = targetAtt
	beam.Enabled = false
	beam.Parent = targetPart
	previewBeam = beam

	-- Create Socket Tooltip
	local tooltip = Instance.new("BillboardGui")
	tooltip.Name = "WZ_SocketTooltip"
	tooltip.Size = UDim2.fromOffset(120, 24)
	tooltip.StudsOffset = Vector3.new(0, 0.8, 0)
	tooltip.AlwaysOnTop = true
	tooltip.Enabled = false
	tooltip.Parent = Workspace
	socketTooltip = tooltip

	local tooltipLabel = Instance.new("TextLabel")
	tooltipLabel.Name = "Label"
	tooltipLabel.Size = UDim2.fromScale(1, 1)
	tooltipLabel.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	tooltipLabel.BackgroundTransparency = 0.2
	tooltipLabel.TextColor3 = Color3.fromRGB(230, 240, 255)
	tooltipLabel.Font = Enum.Font.GothamBold
	tooltipLabel.TextSize = 11
	tooltipLabel.Text = ""
	tooltipLabel.Parent = tooltip
	socketTooltipLabel = tooltipLabel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = tooltipLabel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 140, 240)
	stroke.Thickness = 1
	stroke.Parent = tooltipLabel

	-- Simulation state listener
	simulationState = remoteSet.SimulationState.Value
	setSocketsPresentation(simulationState == "Build")

	remoteSet.SimulationState:GetPropertyChangedSignal("Value"):Connect(function()
		simulationState = remoteSet.SimulationState.Value
		setSocketsPresentation(simulationState == "Build")
		if simulationState ~= "Build" then
			cancelWiring()
			if socketTooltip ~= nil then
				socketTooltip.Enabled = false
			end
		end
	end)

	-- Input Handling
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or simulationState ~= "Build" then
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape then
			cancelWiring()
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			cancelWiring()
			return
		end

		local isPointerDown = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch

		if not isPointerDown then
			return
		end

		camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end

		local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local char = player.Character
		if char ~= nil then
			raycastParams.FilterDescendantsInstances = { char, targetPart }
		else
			raycastParams.FilterDescendantsInstances = { targetPart }
		end

		local result = Workspace:Raycast(ray.Origin, ray.Direction * 200, raycastParams)
		local hitInstance = if result ~= nil then result.Instance else nil

		local marker, compId, portName, direction = getSocketMarker(hitInstance)

		if marker ~= nil and compId ~= nil and portName ~= nil and direction ~= nil then
			local att = findPortAttachment(marker)
			if att == nil then
				return
			end

			if wireSource == nil then
				-- Initial click: if Output, start wiring!
				if direction == "Output" then
					wireSource = {
						ComponentId = compId,
						PortName = portName,
						Attachment = att,
						Marker = marker,
					}
					if previewBeam ~= nil and previewTargetPart ~= nil then
						previewBeam.Attachment0 = att
						previewBeam.Enabled = true
						previewTargetPart.Position = marker.Position
						previewTargetPart.Transparency = 0.3
					end
				elseif direction == "Input" then
					-- Clicked input while not wiring: request disconnect if wired
					remoteSet.RequestWireDisconnect:FireServer({
						SourceComponentId = compId,
						SourcePortName = portName,
						TargetComponentId = compId,
						TargetPortName = portName,
					})
				end
			else
				-- Currently wiring: second click
				if direction == "Input" then
					if compId ~= wireSource.ComponentId then
						-- Complete wire connection
						remoteSet.RequestWireConnect:FireServer({
							SourceComponentId = wireSource.ComponentId,
							SourcePortName = wireSource.PortName,
							TargetComponentId = compId,
							TargetPortName = portName,
						})
					end
					cancelWiring()
				elseif direction == "Output" then
					if compId == wireSource.ComponentId and portName == wireSource.PortName then
						-- Clicked same output again: cancel
						cancelWiring()
					else
						-- Switch to this output
						wireSource = {
							ComponentId = compId,
							PortName = portName,
							Attachment = att,
							Marker = marker,
						}
						if previewBeam ~= nil then
							previewBeam.Attachment0 = att
						end
					end
				end
			end
		else
			-- Clicked outside
			if wireSource ~= nil then
				cancelWiring()
			end
		end
	end)

	-- Update preview beam and tooltips on render step
	RunService.RenderStepped:Connect(function()
		if simulationState ~= "Build" then
			return
		end

		camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end

		local mousePos = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local char = player.Character
		if char ~= nil then
			raycastParams.FilterDescendantsInstances = { char, targetPart }
		else
			raycastParams.FilterDescendantsInstances = { targetPart }
		end

		local result = Workspace:Raycast(ray.Origin, ray.Direction * 200, raycastParams)
		local hitInstance = if result ~= nil then result.Instance else nil

		local marker, _, portName, direction = getSocketMarker(hitInstance)

		-- Update Tooltip
		if marker ~= nil and portName ~= nil and direction ~= nil and socketTooltip ~= nil then
			socketTooltip.Adornee = marker
			socketTooltip.Enabled = true
			if socketTooltipLabel ~= nil then
				socketTooltipLabel.Text = string.format("%s: %s", direction:upper(), portName)
			end
		elseif socketTooltip ~= nil then
			socketTooltip.Enabled = false
		end

		-- Update Preview Beam Position
		if wireSource ~= nil and previewTargetPart ~= nil and previewBeam ~= nil then
			if marker ~= nil and direction == "Input" then
				previewTargetPart.Position = marker.Position
			elseif result ~= nil then
				previewTargetPart.Position = result.Position
			else
				previewTargetPart.Position = ray.Origin + ray.Direction * 15
			end
		end
	end)
end

return table.freeze(WireController)
