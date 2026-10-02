--!strict

--[[
	ActuatorService

	The power and actuator runtime layer for Workshop Zero.

	Responsibilities:
		* discovers powered connections:
		    - Motor <-> axle-capable component (RotaryMotor)
		    - Winch <-> rope-capable component (RopeWinch)
		* configures HingeConstraints as motors during TEST
		* configures RopeConstraints as powered winches during TEST
		* ensures Attachment0 is always the actuator's own connector so that
		  rotational and linear force reference frames are deterministic
		* derives motor rotational signs from connector geometry so that
		  symmetrically placed motors drive cooperatively instead of fighting
		* disables all actuators and stops applying forces before RESET restoration
		* restores initial rope lengths on RESET so winches do not progressively shrink
		* provides visual feedback (power indicator LED) during TEST
		* maintains clean lifecycle: no orphan records on disconnect or experiment restart

	Hard rules:
		* Server authoritative: Roblox physics runs constraints, no manual CFraming.
		* Inactive during BUILD and during RESETTING.
		* Does not duplicate the connection registry; holds actuator state keyed
		  by ConnectionId.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionMath = require(Shared.construction.ConstructionMath)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)

local ComponentFactory = require(script.Parent.ComponentFactory)

local Config = ConstructionConfig

local ActuatorService = {}

export type RotaryMotorEntry = {
	Kind: "RotaryMotor",
	ConnectionId: string,
	MotorComponentId: string,
	OtherComponentId: string,
	Hinge: HingeConstraint,
	MotorConnector: Attachment,
	OtherConnector: Attachment,
}

export type RopeWinchEntry = {
	Kind: "RopeWinch",
	ConnectionId: string,
	WinchComponentId: string,
	OtherComponentId: string,
	Rope: RopeConstraint,
	InitialLength: number,
	WinchConnector: Attachment,
	OtherConnector: Attachment,
}

export type ActuatorEntry = RotaryMotorEntry | RopeWinchEntry

export type ControlProvider = (componentId: string) -> (boolean, boolean)

local actuators: { [string]: ActuatorEntry } = {}
local controlProvider: ControlProvider? = nil

local INDICATOR_OFF_COLOR = Color3.fromRGB(50, 55, 65)
local INDICATOR_ON_COLOR = Color3.fromRGB(80, 240, 120)

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Actuator] %s", message))
	end
end

local function setIndicatorPowered(componentId: string, powered: boolean)
	local model = ComponentFactory.FindComponentById(componentId)
	if model == nil then
		return
	end

	local indicator = model:FindFirstChild("WZ_MotorIndicator", true)
		or model:FindFirstChild("WZ_WinchIndicator", true)
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
		if entry.Kind == "RotaryMotor" then
			if entry.OtherComponentId == componentId or entry.MotorComponentId == componentId then
				return entry
			end
		elseif entry.Kind == "RopeWinch" then
			if entry.OtherComponentId == componentId or entry.WinchComponentId == componentId then
				return entry
			end
		end
	end

	return nil
end

-- Registration ---------------------------------------------------------------

local function registerMotor(record: ConstructionTypes.ConnectionRecord): boolean
	if not record.Constraint:IsA("HingeConstraint") then
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
	hinge.Attachment0 = motorConnector
	hinge.Attachment1 = otherConnector
	hinge.ActuatorType = Enum.ActuatorType.None
	hinge.AngularVelocity = 0
	hinge.MotorMaxTorque = 0
	hinge:SetAttribute(Config.AttributePowered, true)

	local entry: RotaryMotorEntry = {
		Kind = "RotaryMotor",
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

local function registerWinch(record: ConstructionTypes.ConnectionRecord): boolean
	if not record.Constraint:IsA("RopeConstraint") then
		return false
	end

	local rope = record.Constraint :: RopeConstraint

	local modelA = ComponentFactory.FindComponentById(record.ComponentA)
	local modelB = ComponentFactory.FindComponentById(record.ComponentB)
	if modelA == nil or modelB == nil then
		return false
	end

	local typeA = ComponentFactory.GetComponentType(modelA)
	local typeB = ComponentFactory.GetComponentType(modelB)

	local isWinchA = typeA == "Winch"
	local isWinchB = typeB == "Winch"

	if not isWinchA and not isWinchB then
		return false
	end

	local winchId: string
	local otherId: string
	local winchConnectorName: string
	local otherConnectorName: string
	local winchModel: Model
	local otherModel: Model

	if isWinchA then
		winchId = record.ComponentA
		otherId = record.ComponentB
		winchConnectorName = record.ConnectorA
		otherConnectorName = record.ConnectorB
		winchModel = modelA
		otherModel = modelB
	else
		winchId = record.ComponentB
		otherId = record.ComponentA
		winchConnectorName = record.ConnectorB
		otherConnectorName = record.ConnectorA
		winchModel = modelB
		otherModel = modelA
	end

	local winchConnector = ComponentFactory.GetConnector(winchModel, winchConnectorName)
	local otherConnector = ComponentFactory.GetConnector(otherModel, otherConnectorName)

	if winchConnector == nil or otherConnector == nil then
		return false
	end

	-- Crucial invariant: Attachment0 is ALWAYS the Winch connector.
	rope.Attachment0 = winchConnector
	rope.Attachment1 = otherConnector
	rope.WinchEnabled = false
	rope:SetAttribute(Config.AttributePowered, true)

	local initialLength = rope.Length

	local entry: RopeWinchEntry = {
		Kind = "RopeWinch",
		ConnectionId = record.Id,
		WinchComponentId = winchId,
		OtherComponentId = otherId,
		Rope = rope,
		InitialLength = initialLength,
		WinchConnector = winchConnector,
		OtherConnector = otherConnector,
	}

	actuators[record.Id] = entry
	setIndicatorPowered(winchId, false)

	log(
		string.format(
			"registered Winch %s -> connection %s (initial length %.1f)",
			string.sub(winchId, 1, 6),
			string.sub(record.Id, 1, 6),
			initialLength
		)
	)

	return true
end

function ActuatorService.Register(record: ConstructionTypes.ConnectionRecord): boolean
	if record.Type == "Axle" then
		return registerMotor(record)
	elseif record.Type == "Rope" then
		return registerWinch(record)
	end

	return false
end

function ActuatorService.Unregister(connectionId: string): boolean
	local entry = actuators[connectionId]
	if entry == nil then
		return false
	end

	if entry.Kind == "RotaryMotor" then
		if entry.Hinge.Parent ~= nil then
			entry.Hinge.ActuatorType = Enum.ActuatorType.None
			entry.Hinge.AngularVelocity = 0
			entry.Hinge.MotorMaxTorque = 0
			entry.Hinge:SetAttribute(Config.AttributePowered, false)
		end
		setIndicatorPowered(entry.MotorComponentId, false)
	elseif entry.Kind == "RopeWinch" then
		if entry.Rope.Parent ~= nil then
			entry.Rope.WinchEnabled = false
			entry.Rope.Length = entry.InitialLength
			entry.Rope:SetAttribute(Config.AttributePowered, false)
		end
		setIndicatorPowered(entry.WinchComponentId, false)
	end

	actuators[connectionId] = nil
	log(string.format("unregistered actuator connection %s", string.sub(connectionId, 1, 6)))
	return true
end

-- Lifecycle: Test / Reset / Restart ------------------------------------------

local function computeMotorSign(entry: RotaryMotorEntry, refDirection: Vector3?): (number, Vector3)
	local axle = entry.MotorConnector.WorldCFrame.XVector
	local up = entry.MotorConnector.WorldCFrame.YVector
	return ConstructionMath.ComputeMotorSign(axle, up, refDirection)
end

function ActuatorService.SetControlProvider(provider: ControlProvider)
	controlProvider = provider
end

function ActuatorService.SetActuatorSignal(componentId: string, enabled: boolean)
	local entry = ActuatorService.GetActuatorForComponent(componentId)
	if entry == nil then
		return
	end

	if entry.Kind == "RotaryMotor" then
		if entry.Hinge.Parent ~= nil then
			if enabled then
				local sign = computeMotorSign(entry, nil)
				local targetSpeed = Config.MotorAngularVelocity * sign
				entry.Hinge.ActuatorType = Enum.ActuatorType.Motor
				entry.Hinge.AngularVelocity = targetSpeed
				entry.Hinge.MotorMaxTorque = Config.MotorMaxTorque
				entry.Hinge.AngularResponsiveness = Config.MotorAngularResponsiveness
			else
				entry.Hinge.ActuatorType = Enum.ActuatorType.None
				entry.Hinge.AngularVelocity = 0
				entry.Hinge.MotorMaxTorque = 0
			end
		end
		setIndicatorPowered(entry.MotorComponentId, enabled)
	elseif entry.Kind == "RopeWinch" then
		if entry.Rope.Parent ~= nil then
			entry.Rope.WinchEnabled = enabled
		end
		setIndicatorPowered(entry.WinchComponentId, enabled)
	end
end

--[[
	BUILD -> TEST
	Activates all registered powered HingeConstraints and RopeConstraints.
	Actuators with a connected Control signal are only enabled if signal is true.
	Unconnected actuators retain automatic legacy behaviour.
]]
function ActuatorService.EnableActuators(): number
	local motorEntries: { RotaryMotorEntry } = {}
	local winchEntries: { RopeWinchEntry } = {}

	for _, entry in actuators do
		if entry.Kind == "RotaryMotor" and entry.Hinge.Parent ~= nil then
			table.insert(motorEntries, entry)
		elseif entry.Kind == "RopeWinch" and entry.Rope.Parent ~= nil then
			table.insert(winchEntries, entry)
		end
	end

	local enabledCount = 0

	-- 1. Enable rotary motors
	if #motorEntries > 0 then
		local _, refDirection = computeMotorSign(motorEntries[1], nil)
		for _, entry in motorEntries do
			local isControlled = false
			local signal = false
			if controlProvider ~= nil then
				isControlled, signal = controlProvider(entry.MotorComponentId)
			end

			local sign = computeMotorSign(entry, refDirection)
			local targetSpeed = Config.MotorAngularVelocity * sign

			if isControlled then
				if signal then
					entry.Hinge.ActuatorType = Enum.ActuatorType.Motor
					entry.Hinge.AngularVelocity = targetSpeed
					entry.Hinge.MotorMaxTorque = Config.MotorMaxTorque
					entry.Hinge.AngularResponsiveness = Config.MotorAngularResponsiveness
					setIndicatorPowered(entry.MotorComponentId, true)
					enabledCount += 1
				else
					entry.Hinge.ActuatorType = Enum.ActuatorType.None
					entry.Hinge.AngularVelocity = 0
					entry.Hinge.MotorMaxTorque = 0
					setIndicatorPowered(entry.MotorComponentId, false)
				end
			else
				-- Unconnected: legacy automatic behaviour
				entry.Hinge.ActuatorType = Enum.ActuatorType.Motor
				entry.Hinge.AngularVelocity = targetSpeed
				entry.Hinge.MotorMaxTorque = Config.MotorMaxTorque
				entry.Hinge.AngularResponsiveness = Config.MotorAngularResponsiveness
				setIndicatorPowered(entry.MotorComponentId, true)
				enabledCount += 1
			end
		end
	end

	-- 2. Enable powered rope winches
	for _, entry in winchEntries do
		local isControlled = false
		local signal = false
		if controlProvider ~= nil then
			isControlled, signal = controlProvider(entry.WinchComponentId)
		end

		entry.Rope.WinchSpeed = Config.WinchSpeed
		entry.Rope.WinchForce = Config.WinchForce
		entry.Rope.WinchResponsiveness = Config.WinchResponsiveness
		entry.Rope.WinchTarget = Config.WinchTargetLength

		if isControlled then
			entry.Rope.WinchEnabled = signal
			setIndicatorPowered(entry.WinchComponentId, signal)
			if signal then
				enabledCount += 1
			end
		else
			entry.Rope.WinchEnabled = true
			setIndicatorPowered(entry.WinchComponentId, true)
			enabledCount += 1
		end
	end

	if enabledCount > 0 then
		log(
			string.format(
				"%d actuator(s) enabled (%d motors, %d winches)",
				enabledCount,
				#motorEntries,
				#winchEntries
			)
		)
	end

	return enabledCount
end

--[[
	TEST -> RESETTING
	CRITICAL: Actuators must be disabled FIRST, before anchoring or zeroing
	velocities, so powered constraints do not fight restoration.
	For Winches: restores original rope length to eliminate progressive shortening!
]]
function ActuatorService.DisableActuators(): number
	local count = 0
	for _, entry in actuators do
		if entry.Kind == "RotaryMotor" then
			if entry.Hinge.Parent ~= nil then
				entry.Hinge.ActuatorType = Enum.ActuatorType.None
				entry.Hinge.AngularVelocity = 0
				entry.Hinge.MotorMaxTorque = 0
			end
			setIndicatorPowered(entry.MotorComponentId, false)
		elseif entry.Kind == "RopeWinch" then
			if entry.Rope.Parent ~= nil then
				entry.Rope.WinchEnabled = false
				entry.Rope.Length = entry.InitialLength
				entry.Rope.WinchTarget = entry.InitialLength
			end
			setIndicatorPowered(entry.WinchComponentId, false)
		end
		count += 1
	end

	if count > 0 then
		log("actuators disabled and rope lengths restored")
	end

	return count
end

--[[
	Cleans all actuator state on experiment restart or level switch.
]]
function ActuatorService.Clear()
	for connectionId, entry in actuators do
		if entry.Kind == "RotaryMotor" then
			if entry.Hinge.Parent ~= nil then
				entry.Hinge.ActuatorType = Enum.ActuatorType.None
				entry.Hinge.AngularVelocity = 0
				entry.Hinge.MotorMaxTorque = 0
				entry.Hinge:SetAttribute(Config.AttributePowered, false)
			end
			setIndicatorPowered(entry.MotorComponentId, false)
		elseif entry.Kind == "RopeWinch" then
			if entry.Rope.Parent ~= nil then
				entry.Rope.WinchEnabled = false
				entry.Rope.Length = entry.InitialLength
				entry.Rope:SetAttribute(Config.AttributePowered, false)
			end
			setIndicatorPowered(entry.WinchComponentId, false)
		end
		actuators[connectionId] = nil
	end

	table.clear(actuators)
end

return table.freeze(ActuatorService)
