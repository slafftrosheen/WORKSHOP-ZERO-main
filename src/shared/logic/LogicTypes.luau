--!strict

--[[
	LogicTypes

	The vocabulary of the signal/logic layer.

	Signal ports live in their own namespace, separate from mechanical
	connectors. They are Attachments on component Models and are described by
	explicit attributes so direction is never inferred from a name.

	This module holds types and tiny validators only. It must stay free of
	Roblox engine dependencies so server and client can both require it without
	bruning in behaviour.

	Hard rule: Signal is NOT a mechanical ConnectorType. WiringService owns
	signal topology; ConnectorService owns mechanical topology.
]]

local LogicTypes = {}

export type SignalValue = boolean

export type SignalPortDirection = "Input" | "Output"

--[[
	A signal port as described by a component definition, relative to the root part.
	Direction is explicit; never inferred from the port name.
]]
export type SignalPortDefinition = {
	Name: string,
	Direction: SignalPortDirection,
	Offset: CFrame,
}

--[[
	A stable record of one signal wire joining two ports.

	Source must always be an Output port.
	Destination must always be an Input port.

	Output outputs may fan out to multiple inputs, but each input accepts at
	most one incoming wire (fan-in rule V1).
]]
export type WireRecord = {
	Id: string,
	OutputComponentId: string,
	OutputPort: string,
	InputComponentId: string,
	InputPort: string,
	Beam: Beam?,
}

--[[
	The wire-connection request payload that arrives from a client. It contains
	only semantic IDs so the server never trusts an Instance or a CFrame from
	the client.
]]
export type WireConnectRequest = {
	SourceComponentId: string,
	SourcePortName: string,
	TargetComponentId: string,
	TargetPortName: string,
}

--[[
	The internal runtime state of one signal port.
]]
export type PortState = {
	ComponentId: string,
	PortName: string,
	Direction: SignalPortDirection,
	Value: SignalValue,
}

-- Validators for untrusted client input ---------------------------------------

function LogicTypes.IsValidSignalValue(value: unknown): boolean
	return value == true or value == false
end

function LogicTypes.IsValidSignalPortDirection(value: unknown): boolean
	return value == "Input" or value == "Output"
end

--[[
	Validates a wire-connect request payload arriving from a client.
	Returns nil on rejection.
]]
function LogicTypes.ToWireConnectRequest(value: unknown): WireConnectRequest?
	if type(value) ~= "table" then
		return nil
	end

	local tbl = value :: { [string]: unknown }

	if type(tbl.SourceComponentId) ~= "string" then
		return nil
	end
	if type(tbl.SourcePortName) ~= "string" then
		return nil
	end
	if type(tbl.TargetComponentId) ~= "string" then
		return nil
	end
	if type(tbl.TargetPortName) ~= "string" then
		return nil
	end

	return {
		SourceComponentId = tbl.SourceComponentId,
		SourcePortName = tbl.SourcePortName,
		TargetComponentId = tbl.TargetComponentId,
		TargetPortName = tbl.TargetPortName,
	}
end

--[[
	Validates a wire-disconnect request payload arriving from a client.
	Returns nil on rejection.
]]
function LogicTypes.ToWireDisconnectRequest(value: unknown): WireConnectRequest?
	return LogicTypes.ToWireConnectRequest(value)
end

return table.freeze(LogicTypes)
