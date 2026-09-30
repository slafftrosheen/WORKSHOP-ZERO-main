--!strict

--[[
	ConnectorTypes

	Connector kinds and the one rule that matters this batch: a connection is
	only allowed between connectors of the same kind.

		Rigid + Rigid  -> WeldConstraint
		Axle  + Axle   -> HingeConstraint

	Electrical, data and fluid connectors are explicitly not part of WZ-001.
	Adding them later means adding a kind here and a constraint mapping in the
	server's ConnectorService - not rewriting the kernel.
]]

local ConstructionTypes = require(script.Parent.ConstructionTypes)

export type ConnectorType = ConstructionTypes.ConnectorType

local ConnectorTypes = {}

function ConnectorTypes.ToConnectorType(value: unknown): ConnectorType?
	if type(value) ~= "string" then
		return nil
	end

	if value == "Rigid" or value == "Axle" or value == "Rope" then
		return value
	end

	return nil
end

function ConnectorTypes.AreCompatible(a: ConnectorType, b: ConnectorType): boolean
	return a == b
end

function ConnectorTypes.IsRigid(connectorType: ConnectorType): boolean
	return connectorType == "Rigid"
end

function ConnectorTypes.IsAxle(connectorType: ConnectorType): boolean
	return connectorType == "Axle"
end

function ConnectorTypes.IsRope(connectorType: ConnectorType): boolean
	return connectorType == "Rope"
end

return table.freeze(ConnectorTypes)
