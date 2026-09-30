--!strict

--[[
	ConstructionTypes

	The vocabulary of the construction kernel: states, connector kinds,
	component kinds and the record shapes that flow between modules.

	This module holds types and tiny validators only. It must stay free of
	gameplay rules so that server and client can both require it without
	pulling any behaviour along.

	Validators are deliberately hand written instead of clever: they are the
	boundary where data arrives from a player, so they should be boring to read.
]]

export type SimulationState = "Build" | "Testing" | "Resetting"

export type SimulationAction = "Test" | "Reset"

export type ConnectorType = "Rigid" | "Axle"

export type ComponentType = "Plank" | "Block" | "Wheel" | "Spring" | "Motor" | "Fan"

export type RotationOperation = "YawLeft" | "YawRight" | "Flip"

-- A connector as described by a component definition, relative to the root part.
export type ConnectorDefinition = {
	Name: string,
	Type: ConnectorType,
	Offset: CFrame,
}

-- Everything ComponentFactory needs to build one prototype component.
export type ComponentDefinition = {
	Type: ComponentType,
	DisplayName: string,
	Shape: Enum.PartType,
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	Density: number,
	Friction: number,
	Elasticity: number,
	-- False for components that exist as placeholders but cannot be spawned yet.
	Spawnable: boolean,
	Connectors: { ConnectorDefinition },
}

-- One logical joint between two components. The physical constraint is only one
-- field of the record; the rest is what future features (analysis, motors,
-- saving, educational explanations) will read instead of guessing from parts.
export type ConnectionRecord = {
	Id: string,
	Type: ConnectorType,
	ComponentA: string,
	ConnectorA: string,
	ComponentB: string,
	ConnectorB: string,
	Constraint: Constraint,
	PoweredBy: string?,
}

-- A connector pair the kernel is willing to join.
export type SnapCandidate = {
	Moving: Attachment,
	Target: Attachment,
	TargetComponent: Model,
	Distance: number,
}

-- Captured immediately before TEST so RESET can restore the exact build.
export type ComponentSnapshot = {
	ComponentId: string,
	Pivot: CFrame,
	LinearVelocity: Vector3,
	AngularVelocity: Vector3,
	Anchored: boolean,
}

-- The client-facing network surface, created once by the server.
-- SimulationState is a replicated value rather than an event so that late
-- joiners always read the current truth instead of missing a broadcast.
export type ConstructionRemotes = {
	RequestSimulationAction: RemoteEvent,
	RequestRotation: RemoteEvent,
	RequestDisconnect: RemoteEvent,
	DragStateChanged: RemoteEvent,
	SimulationState: StringValue,
}

local ConstructionTypes = {}

function ConstructionTypes.ToSimulationState(value: unknown): SimulationState?
	if type(value) ~= "string" then
		return nil
	end

	if value == "Build" or value == "Testing" or value == "Resetting" then
		return value
	end

	return nil
end

function ConstructionTypes.ToSimulationAction(value: unknown): SimulationAction?
	if type(value) ~= "string" then
		return nil
	end

	if value == "Test" or value == "Reset" then
		return value
	end

	return nil
end

function ConstructionTypes.ToRotationOperation(value: unknown): RotationOperation?
	if type(value) ~= "string" then
		return nil
	end

	if value == "YawLeft" or value == "YawRight" or value == "Flip" then
		return value
	end

	return nil
end

function ConstructionTypes.ToComponentType(value: unknown): ComponentType?
	if type(value) ~= "string" then
		return nil
	end

	if value == "Plank" or value == "Block" or value == "Wheel" then
		return value
	end

	if value == "Spring" or value == "Motor" or value == "Fan" then
		return value
	end

	return nil
end

return table.freeze(ConstructionTypes)
