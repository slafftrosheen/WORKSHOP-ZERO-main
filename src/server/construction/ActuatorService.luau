--!strict

--[[
	ActuatorService

	The power and actuator runtime layer for Workshop Zero.

	Responsibilities:
		* discovers powered connections (Motor <-> axle-capable component)
		* configures HingeConstraints as motors during TEST
		* ensures Attachment0 is always the motor's own connector so that
		  rotational physics and constraints are deterministic
		* derives motor rotational signs from connector geometry so that
		  symmetrically placed motors drive cooperatively instead of fighting
		* disables all actuators and stops applying torque before RESET restoration
		* provides visual feedback (power indicator LED) during TEST
		* maintains clean lifecycle: no orphan records on disconnect or experiment restart

	Hard rules:
		* Server authoritative: Roblox physics runs the hinge, no manual CFraming.
		* Inactive during BUILD and during RESETTING.
		* Does not duplicate the connection registry; holds actuator state keyed
		  by ConnectionId.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)
local ConstructionMath = require(Shared.construction.ConstructionMath)

local ComponentFactory = require(script.Parent.ComponentFactory)

local Config = ConstructionConfig

local ActuatorService = {}

export type ActuatorEntry = {
	ConnectionId: string,
	MotorComponentId: string,
	OtherComponentId: string,
	Hinge: HingeConstraint,
	MotorConnector: Attachment,
	OtherConnector: Attachment,
}

local actuators: { [string]: ActuatorEntry } = {}

local INDICATOR_OFF_COLOR = Color3.fromRGB(50, 55, 65)
local INDICATOR_ON_COLOR = Color3.fromRGB(80, 240, 120)

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Motor] %s", message))
	end
end

local function setIndicatorPowered(motorId: string, powered: boolean)
	local model = ComponentFactory.FindComponentById(motorId)
	if model == nil then
		return
	end

	local indicator = model:FindFirstChild("WZ_MotorIndicator", true)
	if indicator ~= nil and indicator:IsA("BasePart") then
		indicator.Material = if powered then Enum.Material.Neon else Enum.Material.SmoothPlastic
		indicator.Color = if powered then INDICATOR_ON_COLOR else INDICATOR_OFF_COLOR
	end
end

-- Reads ----------------------------------------------------------------------

function ActuatorService.GetCount(): number
	local count = 0
	for _ in actuators do
		count += 1
	end

	return count
end

function ActuatorService.IsPowered(connectionId: string): boolean
	return actuators[connectionId] ~= nil
end

function ActuatorService.GetActuatorForComponent(componentId: string): ActuatorEntry?
	for _, entry in actuators do
		if entry.OtherComponentId == componentId or entry.MotorComponentId == componentId then
			return entry
		end
	end

	return nil
end

-- Registration ---------------------------------------------------------------

--[[
	Registers a connection record if one of the connected components is a Motor
	and the joint type is an Axle.

	Ensures the HingeConstraint's Attachment0 is the Motor connector, so that
	torque and angular velocity reference frames are deterministic.
]]
function ActuatorService.Register(record: ConstructionTypes.ConnectionRecord): boolean
	if record.Type ~= "Axle" then
		return false
	end

	if not (record.Constraint:IsA("HingeConstraint")) then
		return false
	end

	local hinge = record.Constraint :: HingeConstraint

	local modelA = ComponentFactory.FindComponentById(record.ComponentA)
	local modelB = ComponentFactory.FindComponentById(record.ComponentB)
	if modelA == nil or modelB == nil then
		return false
	end

	local typeA = ComponentFactory.GetComponentType(modelA)
	local typeB = ComponentFactory.GetComponentType(modelB)

	local isMotorA = typeA == "Motor"
	local isMotorB = typeB == "Motor"

	if not isMotorA and not isMotorB then
		return false
	end

	local motorId: string
	local otherId: string
	local motorConnectorName: string
	local otherConnectorName: string
	local motorModel: Model
	local otherModel: Model

	if isMotorA then
		motorId = record.ComponentA
		otherId = record.ComponentB
		motorConnectorName = record.ConnectorA
		otherConnectorName = record.ConnectorB
		motorModel = modelA
		otherModel = modelB
	else
		motorId = record.ComponentB
		otherId = record.ComponentA
		motorConnectorName = record.ConnectorB
		otherConnectorName = record.ConnectorA
		motorModel = modelB
		otherModel = modelA
	end

	local motorConnector = ComponentFactory.GetConnector(motorModel, motorConnectorName)
	local otherConnector = ComponentFactory.GetConnector(otherModel, otherConnectorName)

	if motorConnector == nil or otherConnector == nil then
		return false
	end

	-- Crucial invariant: Attachment0 is ALWAYS the Motor connector.
	-- This makes Attachment0.WorldAxis the authoritative motor axle.
	hinge.Attachment0 = motorConnector
	hinge.Attachment1 = otherConnector
	hinge.ActuatorType = Enum.ActuatorType.None
	hinge.AngularVelocity = 0
	hinge.MotorMaxTorque = 0
	hinge:SetAttribute(Config.AttributePowered, true)

	local entry: ActuatorEntry = {
		ConnectionId = record.Id,
		MotorComponentId = motorId,
		OtherComponentId = otherId,
		Hinge = hinge,
		MotorConnector = motorConnector,
		OtherConnector = otherConnector,
	}

	actuators[record.Id] = entry
	setIndicatorPowered(motorId, false)

	log(
		string.format(
			"registered Motor %s -> connection %s",
			string.sub(motorId, 1, 6),
			string.sub(record.Id, 1, 6)
		)
	)

	return true
end

function ActuatorService.Unregister(connectionId: string): boolean
	local entry = actuators[connectionId]
	if entry == nil then
		return false
	end

	if entry.Hinge.Parent ~= nil then
		entry.Hinge.ActuatorType = Enum.ActuatorType.None
		entry.Hinge.AngularVelocity = 0
		entry.Hinge.MotorMaxTorque = 0
		entry.Hinge:SetAttribute(Config.AttributePowered, false)
	end

	setIndicatorPowered(entry.MotorComponentId, false)
	actuators[connectionId] = nil

	log(string.format("unregistered actuator connection %s", string.sub(connectionId, 1, 6)))
	return true
end

-- Lifecycle: Test / Reset / Restart ------------------------------------------

--[[
	Calculates the cooperative rotation sign for an actuator.

	For a single motor, sign is 1. If rotated 180°, its axle inverts and the
	wheel rotation logically inverts with it (Section 41).

	For multiple motors (e.g. left motor + right motor on a symmetrical cart),
	their outward axle vectors point in opposite directions. To ensure both sides
	drive in the same direction instead of fighting each other, we derive the
	travel direction D = Axle X Up for each motor and ensure all motors align
	with a consistent reference direction (Section 42).
]]
local function computeMotorSign(entry: ActuatorEntry, refDirection: Vector3?): (number, Vector3)
	local axle = entry.MotorConnector.WorldCFrame.XVector
	local up = entry.MotorConnector.WorldCFrame.YVector
	return ConstructionMath.ComputeMotorSign(axle, up, refDirection)
end

--[[
	BUILD -> TEST
	Activates all registered powered HingeConstraints.
]]
function ActuatorService.EnableActuators(): number
	local entries: { ActuatorEntry } = {}
	for _, entry in actuators do
		if entry.Hinge.Parent ~= nil then
			table.insert(entries, entry)
		end
	end

	if #entries == 0 then
		return 0
	end

	-- Pick the reference drive direction from the first motor.
	local _, refDirection = computeMotorSign(entries[1], nil)

	local enabledCount = 0
	for _, entry in entries do
		local sign = computeMotorSign(entry, refDirection)
		local targetSpeed = Config.MotorAngularVelocity * sign

		entry.Hinge.ActuatorType = Enum.ActuatorType.Motor
		entry.Hinge.AngularVelocity = targetSpeed
		entry.Hinge.MotorMaxTorque = Config.MotorMaxTorque
		entry.Hinge.AngularResponsiveness = Config.MotorAngularResponsiveness

		setIndicatorPowered(entry.MotorComponentId, true)
		enabledCount += 1
	end

	log(string.format("%d actuator(s) enabled", enabledCount))
	return enabledCount
end

--[[
	TEST -> RESETTING
	CRITICAL: Actuators must be disabled FIRST, before anchoring or zeroing
	velocities, so a powered hinge never applies torque during restoration.
]]
function ActuatorService.DisableActuators(): number
	local count = 0
	for _, entry in actuators do
		if entry.Hinge.Parent ~= nil then
			entry.Hinge.ActuatorType = Enum.ActuatorType.None
			entry.Hinge.AngularVelocity = 0
			entry.Hinge.MotorMaxTorque = 0
		end

		setIndicatorPowered(entry.MotorComponentId, false)
		count += 1
	end

	if count > 0 then
		log("actuators disabled")
	end

	return count
end

--[[
	Cleans all actuator state on experiment restart or level switch.
]]
function ActuatorService.Clear()
	for connectionId, entry in actuators do
		if entry.Hinge.Parent ~= nil then
			entry.Hinge.ActuatorType = Enum.ActuatorType.None
			entry.Hinge.AngularVelocity = 0
			entry.Hinge.MotorMaxTorque = 0
			entry.Hinge:SetAttribute(Config.AttributePowered, false)
		end

		setIndicatorPowered(entry.MotorComponentId, false)
		actuators[connectionId] = nil
	end

	table.clear(actuators)
end

return table.freeze(ActuatorService)
