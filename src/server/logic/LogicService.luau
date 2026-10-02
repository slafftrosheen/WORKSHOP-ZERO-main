--!strict

--[[
	LogicService

	The central runtime evaluation service for Workshop Zero's automation layer:
		* evaluates logic nodes (AND, OR, NOT, Timer)
		* samples sensors (Switch, PressureSensor, ProximitySensor)
		* updates actuator control state (Motor, Winch)
		* updates visual feedback (SignalLamp, indicators, wire beams)
		* lifecycle management (Test, Reset, Restart, Unload)

	Hard rules:
		* Single centralized update loop at LogicConfig.LogicTickRate (15 Hz) during TEST.
		* Inactive during BUILD and RESETTING.
		* Deterministic evaluation: reads previous output state, evaluates all nodes,
		  writes next output state, publishes changes. Multi-gate cycles cannot crash
		  or recurse.
		* Unconnected inputs default to false (LogicConfig.SignalDefault).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local LogicConfig = require(Shared.logic.LogicConfig)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local WiringService = require(script.Parent.WiringService)

local Config = ConstructionConfig

local LogicService = {}

type TimerState = {
	Elapsed: number,
	Out: boolean,
}

-- ComponentId -> PortName -> boolean
local currentOutputs: { [string]: { [string]: boolean } } = {}
local previousOutputs: { [string]: { [string]: boolean } } = {}
-- ComponentId -> TimerState
local timerStates: { [string]: TimerState } = {}

local isRunning = false
local accumulator = 0
local heartbeatConn: RBXScriptConnection? = nil

-- Injected callback to notify ActuatorService of signal changes without circular require
type ActuatorSignalHandler = (componentId: string, enabled: boolean) -> ()
local actuatorSignalHandler: ActuatorSignalHandler? = nil

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Logic] %s", message))
	end
end

-- Helper: read an input port for a component
local function readInput(componentId: string, inputPortName: string): boolean
	local wire = WiringService.GetIncomingWire(componentId, inputPortName)
	if wire == nil then
		return LogicConfig.SignalDefault
	end

	local sourceOutputs = previousOutputs[wire.OutputComponentId]
	if sourceOutputs ~= nil and sourceOutputs[wire.OutputPort] ~= nil then
		return sourceOutputs[wire.OutputPort]
	end

	return LogicConfig.SignalDefault
end

-- Helper: check if a part is a valid sensor trigger
local function isValidSensorTrigger(part: BasePart, sensorModel: Model): boolean
	if part:IsDescendantOf(sensorModel) then
		return false
	end

	-- Exclude player avatars
	local character = part.Parent
	if character ~= nil and Players:GetPlayerFromCharacter(character) ~= nil then
		return false
	end
	if part.Parent ~= nil and part.Parent.Parent ~= nil then
		if Players:GetPlayerFromCharacter(part.Parent.Parent) ~= nil then
			return false
		end
	end

	-- Ignore wire visuals and socket markers
	if part:GetAttribute("WZ_SignalSocketMarker") == true or part.Name == "WZ_SnapPreview" then
		return false
	end

	-- Valid: Payload (Duck)
	if part:GetAttribute(Config.AttributePayload) == true then
		return true
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if model ~= nil and model:GetAttribute(Config.AttributePayload) == true then
		return true
	end

	-- Valid: Construction components
	if part:GetAttribute(Config.AttributeComponent) == true then
		return true
	end
	if model ~= nil and model:GetAttribute(Config.AttributeComponent) == true then
		return true
	end

	return false
end

-- Sensor evaluations ---------------------------------------------------------

local function evaluateSwitch(model: Model, nextCompOutputs: { [string]: boolean })
	local state = model:GetAttribute("WZ_SwitchState") == true
	nextCompOutputs["Out"] = state

	-- Update indicator
	local indicator = model:FindFirstChild("WZ_SwitchIndicator", true)
	if indicator ~= nil and indicator:IsA("BasePart") then
		indicator.Material = if state then Enum.Material.Neon else Enum.Material.SmoothPlastic
		indicator.Color = if state then Color3.fromRGB(80, 240, 120) else Color3.fromRGB(50, 55, 65)
	end
end

local function evaluatePressureSensor(model: Model, nextCompOutputs: { [string]: boolean })
	local pad = model:FindFirstChild("Pad") or model.PrimaryPart
	if pad == nil or not pad:IsA("BasePart") then
		nextCompOutputs["Out"] = false
		return
	end

	local padCFrame = pad.CFrame
	local padSize = pad.Size
	local checkCFrame = padCFrame * CFrame.new(0, padSize.Y / 2 + 0.35, 0)
	local checkSize = Vector3.new(padSize.X * 0.9, 0.7, padSize.Z * 0.9)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { model }

	local partsInBox = Workspace:GetPartBoundsInBox(checkCFrame, checkSize, overlapParams)
	local triggered = false

	for _, part in partsInBox do
		if isValidSensorTrigger(part, model) then
			triggered = true
			break
		end
	end

	nextCompOutputs["Out"] = triggered

	-- Visual plate indicator
	local indicator = model:FindFirstChild("WZ_SensorIndicator", true)
	if indicator ~= nil and indicator:IsA("BasePart") then
		indicator.Material = if triggered then Enum.Material.Neon else Enum.Material.SmoothPlastic
		indicator.Color = if triggered
			then Color3.fromRGB(80, 240, 255)
			else Color3.fromRGB(40, 50, 70)
	end
end

local function evaluateProximitySensor(model: Model, nextCompOutputs: { [string]: boolean })
	local root = model.PrimaryPart
	if root == nil then
		nextCompOutputs["Out"] = false
		return
	end

	-- Forward vector: +X is the component's front pointing direction in WorkshopZero
	local forward = root.CFrame.RightVector
	local origin = root.Position + forward * (root.Size.X / 2 + 0.2)
	local range = LogicConfig.ProximitySensorRange

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { model }

	local result = Workspace:Blockcast(
		CFrame.new(origin, origin + forward),
		Vector3.new(1.4, 1.4, 0.2),
		forward * range,
		raycastParams
	)

	local detected = false
	if result ~= nil and result.Instance ~= nil then
		local hit = result.Instance
		-- Check that hit is not player avatar and is valid obstacle or payload or component
		local char = hit.Parent
		local isPlayer = char ~= nil and Players:GetPlayerFromCharacter(char) ~= nil
		if not isPlayer and hit.CanCollide then
			-- Environment obstacle, duck, or other component
			detected = true
		end
	end

	nextCompOutputs["Out"] = detected

	-- Visual lens indicator
	local lens = model:FindFirstChild("WZ_SensorLens", true)
	if lens ~= nil and lens:IsA("BasePart") then
		lens.Material = if detected then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lens.Color = if detected then Color3.fromRGB(80, 240, 255) else Color3.fromRGB(40, 60, 90)
	end
end

-- Gates and Timers -----------------------------------------------------------

local function evaluateAndGate(componentId: string, nextCompOutputs: { [string]: boolean })
	local inA = readInput(componentId, "A")
	local inB = readInput(componentId, "B")
	nextCompOutputs["Out"] = inA and inB
end

local function evaluateOrGate(componentId: string, nextCompOutputs: { [string]: boolean })
	local inA = readInput(componentId, "A")
	local inB = readInput(componentId, "B")
	nextCompOutputs["Out"] = inA or inB
end

local function evaluateNotGate(componentId: string, nextCompOutputs: { [string]: boolean })
	local inVal = readInput(componentId, "In")
	nextCompOutputs["Out"] = not inVal
end

local function evaluateTimer(
	componentId: string,
	dt: number,
	nextCompOutputs: { [string]: boolean }
)
	local inVal = readInput(componentId, "In")
	local state = timerStates[componentId]
	if state == nil then
		state = { Elapsed = 0, Out = false }
		timerStates[componentId] = state
	end

	if inVal then
		state.Elapsed += dt
		if state.Elapsed >= LogicConfig.TimerDelay then
			state.Out = true
		end
	else
		state.Elapsed = 0
		state.Out = false
	end

	nextCompOutputs["Out"] = state.Out
end

local function evaluateSignalLamp(model: Model, componentId: string)
	local inVal = readInput(componentId, "In")

	local bulb = model:FindFirstChild("WZ_LampBulb", true)
	if bulb ~= nil and bulb:IsA("BasePart") then
		bulb.Material = if inVal then Enum.Material.Neon else Enum.Material.SmoothPlastic
		bulb.Color = if inVal then Color3.fromRGB(60, 255, 120) else Color3.fromRGB(20, 50, 30)
	end
end

-- Central step function ------------------------------------------------------

local function stepLogic(dt: number)
	local nextOutputs: { [string]: { [string]: boolean } } = {}

	-- 1. Evaluate all components
	for _, model in ComponentFactory.GetComponents() do
		local componentId = ComponentFactory.GetComponentId(model)
		local componentType = ComponentFactory.GetComponentType(model)
		if componentId == nil or componentType == nil then
			continue
		end

		local compOutputs: { [string]: boolean } = {}
		nextOutputs[componentId] = compOutputs

		if componentType == "Switch" then
			evaluateSwitch(model, compOutputs)
		elseif componentType == "PressureSensor" then
			evaluatePressureSensor(model, compOutputs)
		elseif componentType == "ProximitySensor" then
			evaluateProximitySensor(model, compOutputs)
		elseif componentType == "AND" then
			evaluateAndGate(componentId, compOutputs)
		elseif componentType == "OR" then
			evaluateOrGate(componentId, compOutputs)
		elseif componentType == "NOT" then
			evaluateNotGate(componentId, compOutputs)
		elseif componentType == "Timer" then
			evaluateTimer(componentId, dt, compOutputs)
		elseif componentType == "SignalLamp" then
			evaluateSignalLamp(model, componentId)
		end
	end

	-- 2. Trace changes if LogicTrace is enabled
	if LogicConfig.LogicTrace then
		for compId, ports in nextOutputs do
			local prevPorts = previousOutputs[compId]
			for portName, newVal in ports do
				local oldVal = if prevPorts ~= nil then prevPorts[portName] else nil
				if oldVal ~= newVal then
					log(
						string.format(
							"%s.%s %s -> %s",
							string.sub(compId, 1, 6),
							portName,
							tostring(oldVal),
							tostring(newVal)
						)
					)
				end
			end
		end
	end

	-- 3. Commit state
	for compId, ports in nextOutputs do
		currentOutputs[compId] = ports
		if previousOutputs[compId] == nil then
			previousOutputs[compId] = {}
		end
		for portName, val in ports do
			previousOutputs[compId][portName] = val
		end
	end

	-- 4. Publish to controlled actuators (Motor, Winch)
	for _, model in ComponentFactory.GetComponents() do
		local componentId = ComponentFactory.GetComponentId(model)
		local componentType = ComponentFactory.GetComponentType(model)
		if componentId == nil or (componentType ~= "Motor" and componentType ~= "Winch") then
			continue
		end

		local wire = WiringService.GetIncomingWire(componentId, "Control")
		if wire ~= nil and actuatorSignalHandler ~= nil then
			local sourceOutputs = currentOutputs[wire.OutputComponentId]
			local signal = sourceOutputs ~= nil and sourceOutputs[wire.OutputPort] == true
			actuatorSignalHandler(componentId, signal)
		end
	end

	-- 5. Update wire visuals
	for _, wire in WiringService.GetAllWires() do
		local sourceOutputs = currentOutputs[wire.OutputComponentId]
		local active = sourceOutputs ~= nil and sourceOutputs[wire.OutputPort] == true
		WiringService.SetWireActive(wire.Id, active)
	end
end

-- Public API -----------------------------------------------------------------

function LogicService.SetActuatorSignalHandler(handler: ActuatorSignalHandler)
	actuatorSignalHandler = handler
end

function LogicService.IsActuatorControlled(componentId: string): boolean
	return WiringService.GetIncomingWire(componentId, "Control") ~= nil
end

function LogicService.GetActuatorControl(componentId: string): (boolean, boolean)
	local wire = WiringService.GetIncomingWire(componentId, "Control")
	if wire == nil then
		return false, false
	end

	local sourceOutputs = currentOutputs[wire.OutputComponentId]
	local signal = sourceOutputs ~= nil and sourceOutputs[wire.OutputPort] == true
	return true, signal
end

function LogicService.GetPortSignal(componentId: string, portName: string): boolean
	local ports = currentOutputs[componentId]
	if ports ~= nil and ports[portName] ~= nil then
		return ports[portName]
	end
	return LogicConfig.SignalDefault
end

-- Lifecycle ------------------------------------------------------------------

function LogicService.Start()
	if isRunning then
		return
	end

	isRunning = true
	accumulator = 0

	-- Populate initial previous outputs from static state
	for _, model in ComponentFactory.GetComponents() do
		local componentId = ComponentFactory.GetComponentId(model)
		local componentType = ComponentFactory.GetComponentType(model)
		if componentId == nil or componentType == nil then
			continue
		end

		if previousOutputs[componentId] == nil then
			previousOutputs[componentId] = {}
		end

		if componentType == "Switch" then
			local sw = model:GetAttribute("WZ_SwitchState") == true
			previousOutputs[componentId]["Out"] = sw
		end
	end

	-- Run one immediate step so actuators and gates reflect initial state at tick 0
	stepLogic(0)

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		if not isRunning then
			return
		end

		accumulator += dt
		local tickInterval = 1 / LogicConfig.LogicTickRate
		while accumulator >= tickInterval do
			accumulator -= tickInterval
			stepLogic(tickInterval)
		end
	end)

	log("LogicService started (15 Hz)")
end

function LogicService.Stop()
	if not isRunning then
		return
	end

	isRunning = false
	if heartbeatConn ~= nil then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end

	accumulator = 0
	log("LogicService stopped")
end

function LogicService.ResetRuntimeState()
	LogicService.Stop()

	-- Reset timer progress
	for compId in timerStates do
		timerStates[compId] = { Elapsed = 0, Out = false }
	end

	-- Reset all active output signals to false
	for _, ports in currentOutputs do
		for portName in ports do
			ports[portName] = false
		end
	end
	for _, ports in previousOutputs do
		for portName in ports do
			ports[portName] = false
		end
	end

	-- Reset wire beam visuals to inactive
	for _, wire in WiringService.GetAllWires() do
		WiringService.SetWireActive(wire.Id, false)
	end

	-- Reset visual indicators on components
	for _, model in ComponentFactory.GetComponents() do
		local componentType = ComponentFactory.GetComponentType(model)
		if componentType == "SignalLamp" then
			local bulb = model:FindFirstChild("WZ_LampBulb", true)
			if bulb ~= nil and bulb:IsA("BasePart") then
				bulb.Material = Enum.Material.SmoothPlastic
				bulb.Color = Color3.fromRGB(20, 50, 30)
			end
		elseif componentType == "PressureSensor" then
			local ind = model:FindFirstChild("WZ_SensorIndicator", true)
			if ind ~= nil and ind:IsA("BasePart") then
				ind.Material = Enum.Material.SmoothPlastic
				ind.Color = Color3.fromRGB(40, 50, 70)
			end
		elseif componentType == "ProximitySensor" then
			local lens = model:FindFirstChild("WZ_SensorLens", true)
			if lens ~= nil and lens:IsA("BasePart") then
				lens.Material = Enum.Material.SmoothPlastic
				lens.Color = Color3.fromRGB(40, 60, 90)
			end
		end
	end

	log("runtime logic states reset")
end

function LogicService.Clear()
	LogicService.Stop()

	table.clear(currentOutputs)
	table.clear(previousOutputs)
	table.clear(timerStates)

	log("all logic records cleared")
end

return table.freeze(LogicService)
