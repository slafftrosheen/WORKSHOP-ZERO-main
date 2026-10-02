--!strict

--[[
	WiringService

	Owns the control-signal wiring topology and wire visuals in Workshop Zero.

	Hard rules:
		* Control wiring is strictly separate from mechanical joints (ConnectorService).
		  A control wire NEVER creates a physical weld, constraint, or mass.
		* Source is always an Output port; Destination is always an Input port.
		* Fan-in rule V1: each input port accepts at most ONE incoming wire.
		* Fan-out: an output port may connect to multiple input ports.
		* Distance between ports must not exceed LogicConfig.MaxSignalWireLength.
		* Wire visuals use Beam instances between signal-port Attachments.
		* Server owns authoritative validation and lifecycle.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)
local LogicConfig = require(Shared.logic.LogicConfig)
local LogicTypes = require(Shared.logic.LogicTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)

local WiringService = {}

local wires: { [string]: LogicTypes.WireRecord } = {}
-- Key: "ComponentId:PortName" -> wireId (for inputs, enforcing max 1 incoming wire)
local inputToWire: { [string]: string } = {}
-- ComponentId -> set of wireIds
local componentWires: { [string]: { [string]: boolean } } = {}

local remotes: ExperimentTypes.ExperimentRemotes? = nil

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Wiring] %s", message))
	end
end

local function makeInputKey(componentId: string, portName: string): string
	return string.format("%s:%s", componentId, portName)
end

-- Visual beam creation --------------------------------------------------------

local function createWireBeam(sourceAttachment: Attachment, targetAttachment: Attachment): Beam
	local beam = Instance.new("Beam")
	beam.Name = "WZ_SignalWire"
	beam.Attachment0 = sourceAttachment
	beam.Attachment1 = targetAttachment
	beam.Width0 = LogicConfig.WireThickness
	beam.Width1 = LogicConfig.WireThickness
	beam.Color = ColorSequence.new(LogicConfig.WireColorInactive)
	beam.LightEmission = LogicConfig.WireLightEmissiveInactive
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new(LogicConfig.WireTransparency)
	beam.FaceCamera = true
	beam.Segments = 10
	beam.CurveSize0 = 0.4
	beam.CurveSize1 = -0.4
	beam.Parent = sourceAttachment.Parent or sourceAttachment

	return beam
end

-- Reads ----------------------------------------------------------------------

function WiringService.GetAllWires(): { LogicTypes.WireRecord }
	local result: { LogicTypes.WireRecord } = {}
	for _, record in wires do
		table.insert(result, record)
	end
	return result
end

function WiringService.GetWire(wireId: string): LogicTypes.WireRecord?
	return wires[wireId]
end

function WiringService.GetIncomingWire(
	componentId: string,
	inputPortName: string
): LogicTypes.WireRecord?
	local key = makeInputKey(componentId, inputPortName)
	local wireId = inputToWire[key]
	if wireId ~= nil then
		return wires[wireId]
	end
	return nil
end

function WiringService.GetOutgoingWires(
	componentId: string,
	outputPortName: string
): { LogicTypes.WireRecord }
	local result: { LogicTypes.WireRecord } = {}
	for _, record in wires do
		if record.OutputComponentId == componentId and record.OutputPort == outputPortName then
			table.insert(result, record)
		end
	end
	return result
end

function WiringService.GetWiresForComponent(componentId: string): { LogicTypes.WireRecord }
	local result: { LogicTypes.WireRecord } = {}
	local set = componentWires[componentId]
	if set ~= nil then
		for wireId in set do
			local record = wires[wireId]
			if record ~= nil then
				table.insert(result, record)
			end
		end
	end
	return result
end

function WiringService.GetCount(): number
	local count = 0
	for _ in wires do
		count += 1
	end
	return count
end

-- State visual ---------------------------------------------------------------

function WiringService.SetWireActive(wireId: string, active: boolean)
	local record = wires[wireId]
	if record == nil or record.Beam == nil or record.Beam.Parent == nil then
		return
	end

	local color = if active then LogicConfig.WireColorActive else LogicConfig.WireColorInactive
	local emissive = if active
		then LogicConfig.WireLightEmissiveActive
		else LogicConfig.WireLightEmissiveInactive

	record.Beam.Color = ColorSequence.new(color)
	record.Beam.LightEmission = emissive
end

-- Connection -----------------------------------------------------------------

--[[
	Attempts to connect an Output port on sourceComponent to an Input port on
	targetComponent. Returns (success, optionalErrorMessage).
]]
function WiringService.Connect(
	sourceComponentId: string,
	sourcePortName: string,
	targetComponentId: string,
	targetPortName: string
): (boolean, string?)
	if sourceComponentId == targetComponentId then
		return false, "CANNOT WIRE COMPONENT TO ITSELF"
	end

	local sourceModel = ComponentFactory.FindComponentById(sourceComponentId)
	local targetModel = ComponentFactory.FindComponentById(targetComponentId)
	if sourceModel == nil or targetModel == nil then
		return false, "COMPONENT NOT FOUND"
	end

	local sourceAttachment = ComponentFactory.GetSignalPort(sourceModel, sourcePortName)
	local targetAttachment = ComponentFactory.GetSignalPort(targetModel, targetPortName)
	if sourceAttachment == nil or targetAttachment == nil then
		return false, "PORT NOT FOUND"
	end

	local sourceDir = ComponentFactory.GetSignalPortDirection(sourceAttachment)
	local targetDir = ComponentFactory.GetSignalPortDirection(targetAttachment)

	if sourceDir ~= "Output" or targetDir ~= "Input" then
		return false, "OUTPUT -> INPUT ONLY"
	end

	-- Fan-in rule: one input port = maximum one incoming wire
	local targetKey = makeInputKey(targetComponentId, targetPortName)
	if inputToWire[targetKey] ~= nil then
		return false, "INPUT ALREADY CONNECTED"
	end

	local distance = (sourceAttachment.WorldPosition - targetAttachment.WorldPosition).Magnitude
	if distance > LogicConfig.MaxSignalWireLength then
		return false, "WIRE TOO LONG"
	end
	if distance < LogicConfig.MinSignalWireLength then
		return false, "WIRE TOO SHORT"
	end

	local wireId = HttpService:GenerateGUID(false)
	local beam = createWireBeam(sourceAttachment, targetAttachment)

	local record: LogicTypes.WireRecord = {
		Id = wireId,
		OutputComponentId = sourceComponentId,
		OutputPort = sourcePortName,
		InputComponentId = targetComponentId,
		InputPort = targetPortName,
		Beam = beam,
	}

	wires[wireId] = record
	inputToWire[targetKey] = wireId

	if componentWires[sourceComponentId] == nil then
		componentWires[sourceComponentId] = {}
	end
	componentWires[sourceComponentId][wireId] = true

	if componentWires[targetComponentId] == nil then
		componentWires[targetComponentId] = {}
	end
	componentWires[targetComponentId][wireId] = true

	log(
		string.format(
			"connected %s.%s -> %s.%s (wire %s, %.1f studs)",
			string.sub(sourceComponentId, 1, 6),
			sourcePortName,
			string.sub(targetComponentId, 1, 6),
			targetPortName,
			string.sub(wireId, 1, 6),
			distance
		)
	)

	return true, nil
end

-- Disconnection --------------------------------------------------------------

function WiringService.Disconnect(wireId: string): boolean
	local record = wires[wireId]
	if record == nil then
		return false
	end

	if record.Beam ~= nil then
		record.Beam:Destroy()
	end

	local targetKey = makeInputKey(record.InputComponentId, record.InputPort)
	inputToWire[targetKey] = nil

	if componentWires[record.OutputComponentId] ~= nil then
		componentWires[record.OutputComponentId][wireId] = nil
	end
	if componentWires[record.InputComponentId] ~= nil then
		componentWires[record.InputComponentId][wireId] = nil
	end

	wires[wireId] = nil

	log(string.format("disconnected wire %s", string.sub(wireId, 1, 6)))
	return true
end

function WiringService.DisconnectPort(componentId: string, portName: string): boolean
	local targetKey = makeInputKey(componentId, portName)
	local incomingWireId = inputToWire[targetKey]
	if incomingWireId ~= nil then
		return WiringService.Disconnect(incomingWireId)
	end

	-- Also disconnect if it is an output with outgoing wires
	local outgoing = WiringService.GetOutgoingWires(componentId, portName)
	local anyDisconnected = false
	for _, record in outgoing do
		if WiringService.Disconnect(record.Id) then
			anyDisconnected = true
		end
	end

	return anyDisconnected
end

function WiringService.DisconnectComponent(componentId: string): number
	local set = componentWires[componentId]
	if set == nil then
		return 0
	end

	local wireIdsToDisconnect: { string } = {}
	for wireId in set do
		table.insert(wireIdsToDisconnect, wireId)
	end

	local removed = 0
	for _, wireId in wireIdsToDisconnect do
		if WiringService.Disconnect(wireId) then
			removed += 1
		end
	end

	componentWires[componentId] = nil
	return removed
end

function WiringService.Clear()
	for _, record in wires do
		if record.Beam ~= nil then
			record.Beam:Destroy()
		end
	end

	table.clear(wires)
	table.clear(inputToWire)
	table.clear(componentWires)

	log("all signal wires cleared")
end

-- Setup and Remotes ----------------------------------------------------------

function WiringService.SetRemotes(remoteSet: ExperimentTypes.ExperimentRemotes)
	remotes = remoteSet

	remotes.RequestWireConnect.OnServerEvent:Connect(function(player: Player, payload: unknown)
		local request = LogicTypes.ToWireConnectRequest(payload)
		if request == nil then
			return
		end

		local success, err = WiringService.Connect(
			request.SourceComponentId,
			request.SourcePortName,
			request.TargetComponentId,
			request.TargetPortName
		)

		if not success and err ~= nil and remotes ~= nil then
			remotes.FailureToast:FireClient(player, err)
		end
	end)

	remotes.RequestWireDisconnect.OnServerEvent:Connect(function(_player: Player, payload: unknown)
		local request = LogicTypes.ToWireDisconnectRequest(payload)
		if request == nil then
			return
		end

		-- Target is usually the input port to disconnect
		local key = makeInputKey(request.TargetComponentId, request.TargetPortName)
		local wireId = inputToWire[key]
		if wireId ~= nil then
			WiringService.Disconnect(wireId)
		else
			-- Try source port
			WiringService.DisconnectPort(request.SourceComponentId, request.SourcePortName)
		end
	end)
end

return table.freeze(WiringService)
