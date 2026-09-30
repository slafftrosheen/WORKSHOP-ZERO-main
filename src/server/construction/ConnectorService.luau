--!strict

--[[
	ConnectorService

	Owns the logical machine: which connectors are joined, by what kind of
	joint, and which physical constraint implements that joint.

	Two deliberate choices:

		1. The machine is never inferred from Roblox descendants. A connection
		   record is the truth and the WeldConstraint / HingeConstraint is one
		   field of it. Future features (motors, machine analysis, saving,
		   educational explanations) read records instead of guessing from
		   parts.

		2. Snapping aligns the moving component so its connector matches the
		   target connector, then welds or hinges the two. Rigid joints become
		   WeldConstraints, axle joints become HingeConstraints, and an axle is
		   never welded.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ConnectorTypes = require(Shared.construction.ConnectorTypes)
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)

local ComponentFactory = require(script.Parent.ComponentFactory)

local Config = ConstructionConfig

local ConnectorService = {}

-- Rotating the moving connector by this amount makes two outward-facing
-- connectors face each other, which is what "put these together" means.
local FACING_FLIP = CFrame.Angles(0, math.pi, 0)

local connections: { [string]: ConstructionTypes.ConnectionRecord } = {}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ] %s", message))
	end
end

local function displayName(componentId: string): string
	local model = ComponentFactory.FindComponentById(componentId)
	if model == nil then
		return componentId
	end

	local componentType = ComponentFactory.GetComponentType(model)
	if componentType ~= nil then
		return componentType
	end

	return model.Name
end

-- Reads ----------------------------------------------------------------------

function ConnectorService.GetAll(): { ConstructionTypes.ConnectionRecord }
	local result: { ConstructionTypes.ConnectionRecord } = {}
	for _, record in connections do
		table.insert(result, record)
	end

	return result
end

function ConnectorService.GetFor(componentId: string): { ConstructionTypes.ConnectionRecord }
	local result: { ConstructionTypes.ConnectionRecord } = {}
	for _, record in connections do
		if record.ComponentA == componentId or record.ComponentB == componentId then
			table.insert(result, record)
		end
	end

	return result
end

function ConnectorService.GetCount(): number
	local count = 0
	for _ in connections do
		count += 1
	end

	return count
end

-- Snap search ----------------------------------------------------------------

local function alignmentOf(target: Attachment, moving: Attachment): number
	local desired = target.WorldCFrame * FACING_FLIP
	return math.abs(desired.XVector:Dot(moving.WorldCFrame.XVector))
end

--[[
	Finds the best connector pair for a component that was just released.

	A candidate must be:

		* on a different component
		* the same connector kind
		* unoccupied on both sides
		* within SnapDistance
		* roughly facing the target (so a plank laid across a socket at right
		  angles does not quietly snap into it)

	Score favours proximity first and alignment second.
]]
function ConnectorService.FindCandidate(movingModel: Model): ConstructionTypes.SnapCandidate?
	local movingConnectors = ComponentFactory.GetFreeConnectors(movingModel)
	if #movingConnectors == 0 then
		return nil
	end

	local minAlignment = math.cos(math.rad(Config.SnapAngleToleranceDegrees))
	local best: ConstructionTypes.SnapCandidate? = nil
	local bestScore = math.huge

	for _, component in ComponentFactory.GetComponents() do
		if component ~= movingModel then
			for _, target in ComponentFactory.GetFreeConnectors(component) do
				local targetType = ComponentFactory.GetConnectorType(target)
				if targetType ~= nil then
					local targetPosition = target.WorldCFrame.Position

					for _, moving in movingConnectors do
						local movingType = ComponentFactory.GetConnectorType(moving)
						if
							movingType ~= nil
							and ConnectorTypes.AreCompatible(movingType, targetType)
						then
							local distance = (moving.WorldCFrame.Position - targetPosition).Magnitude
							if distance <= Config.SnapDistance then
								local alignment = alignmentOf(target, moving)
								if alignment >= minAlignment then
									local score = distance + (1 - alignment)
									if score < bestScore then
										bestScore = score
										best = {
											Moving = moving,
											Target = target,
											TargetComponent = component,
											Distance = distance,
										}
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

-- Joint creation -------------------------------------------------------------

local function createConstraint(
	connectorType: ConstructionTypes.ConnectorType,
	componentA: Model,
	connectorA: Attachment,
	componentB: Model,
	connectorB: Attachment,
	connectionId: string
): Constraint?
	local rootA = ComponentFactory.GetRoot(componentA)
	local rootB = ComponentFactory.GetRoot(componentB)
	if rootA == nil or rootB == nil then
		return nil
	end

	local constraint: Constraint

	if ConnectorTypes.IsRigid(connectorType) then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootA
		weld.Part1 = rootB
		constraint = weld
	else
		local hinge = Instance.new("HingeConstraint")
		-- Hinges spin around the connector attachments themselves, so the wheel
		-- keeps the axle the player snapped it to.
		hinge.Attachment0 = connectorA
		hinge.Attachment1 = connectorB
		hinge.ActuatorType = Enum.ActuatorType.None
		hinge.LimitsEnabled = false
		constraint = hinge
	end

	constraint.Name = string.format("WZ_%s_%s", connectorType, string.sub(connectionId, 1, 6))

	local container = ComponentFactory.GetConnectionsContainer()
	if container ~= nil then
		constraint.Parent = container
	else
		constraint.Parent = rootA
	end

	return constraint
end

--[[
	Joins a candidate pair: aligns the moving component, marks both connectors
	occupied and registers the connection record.

	Returns the new record, or nil when the pair is no longer valid (for example
	because something else grabbed the connector first).
]]
function ConnectorService.Snap(
	movingModel: Model,
	candidate: ConstructionTypes.SnapCandidate
): ConstructionTypes.ConnectionRecord?
	local targetModel = candidate.TargetComponent
	local movingConnector = candidate.Moving
	local targetConnector = candidate.Target

	if targetModel == movingModel then
		return nil
	end

	if ComponentFactory.IsConnectorOccupied(movingConnector) then
		return nil
	end

	if ComponentFactory.IsConnectorOccupied(targetConnector) then
		return nil
	end

	local connectorType = ComponentFactory.GetConnectorType(movingConnector)
	if connectorType == nil then
		return nil
	end

	local targetType = ComponentFactory.GetConnectorType(targetConnector)
	if targetType == nil or not ConnectorTypes.AreCompatible(targetType, connectorType) then
		return nil
	end

	local componentA = ComponentFactory.GetComponentId(targetModel)
	local componentB = ComponentFactory.GetComponentId(movingModel)
	local connectorAName = targetConnector.Name
	local connectorBName = movingConnector.Name
	if componentA == nil or componentB == nil then
		return nil
	end

	-- Align: the moving connector is rotated onto the target's facing frame.
	local desiredCFrame = targetConnector.WorldCFrame * FACING_FLIP
	local delta = desiredCFrame * movingConnector.WorldCFrame:Inverse()
	movingModel:PivotTo(delta * movingModel:GetPivot())

	local connectionId = HttpService:GenerateGUID(false)
	local constraint = createConstraint(
		connectorType,
		targetModel,
		targetConnector,
		movingModel,
		movingConnector,
		connectionId
	)
	if constraint == nil then
		return nil
	end

	ComponentFactory.SetConnectorOccupied(targetConnector, true)
	ComponentFactory.SetConnectorOccupied(movingConnector, true)

	local record: ConstructionTypes.ConnectionRecord = {
		Id = connectionId,
		Type = connectorType,
		ComponentA = componentA,
		ConnectorA = connectorAName,
		ComponentB = componentB,
		ConnectorB = connectorBName,
		Constraint = constraint,
	}

	connections[connectionId] = record

	log(
		string.format(
			"Connected %s.%s -> %s.%s (%s)",
			displayName(componentA),
			connectorAName,
			displayName(componentB),
			connectorBName,
			connectorType
		)
	)

	return record
end

-- Disconnection --------------------------------------------------------------

local function releaseConnector(componentId: string, connectorName: string)
	local model = ComponentFactory.FindComponentById(componentId)
	if model == nil then
		return
	end

	local attachment = ComponentFactory.GetConnector(model, connectorName)
	if attachment ~= nil then
		ComponentFactory.SetConnectorOccupied(attachment, false)
	end
end

local function removeConnection(connectionId: string): boolean
	local record = connections[connectionId]
	if record == nil then
		return false
	end

	record.Constraint:Destroy()
	releaseConnector(record.ComponentA, record.ConnectorA)
	releaseConnector(record.ComponentB, record.ConnectorB)
	connections[connectionId] = nil

	return true
end

--[[
	Removes every connection that touches a component. Intentionally coarse for
	this batch: later batches can offer "disconnect this joint" on a specific
	connector instead.

	The component itself is never deleted.
]]
function ConnectorService.Disconnect(componentId: string): number
	local doomed: { string } = {}
	for connectionId, record in connections do
		if record.ComponentA == componentId or record.ComponentB == componentId then
			table.insert(doomed, connectionId)
		end
	end

	for _, connectionId in doomed do
		local record = connections[connectionId]
		if record ~= nil then
			local description = string.format(
				"%s.%s - %s.%s",
				displayName(record.ComponentA),
				record.ConnectorA,
				displayName(record.ComponentB),
				record.ConnectorB
			)

			if removeConnection(connectionId) then
				log(string.format("Disconnected %s", description))
			end
		end
	end

	return #doomed
end

--[[
	Removes every connection between every component.

	This is what "start the experiment again" means, and it is deliberately not
	what RESET means: RESET keeps the machine exactly as the player built it.
]]
function ConnectorService.DisconnectAll(): number
	local doomed: { string } = {}
	for connectionId in connections do
		table.insert(doomed, connectionId)
	end

	local removed = 0
	for _, connectionId in doomed do
		if removeConnection(connectionId) then
			removed += 1
		end
	end

	if removed > 0 then
		log(string.format("Disconnected every joint (%d)", removed))
	end

	return removed
end

return table.freeze(ConnectorService)
