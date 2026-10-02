--!strict

--[[
	LogicDefinitions

	A catalogue of signal-port behaviour for logic components and for the
	actuator control ports that motors and winches gain.

	Signal-port geometry lives in ComponentDefinitions (the mechanical
	definition). This module adds the logic-specific metadata that
	LogicService and WiringService need to interpret those ports:

		* which port name is the "active" output for sensors
		* what an unconnected input defaults to
		* how a logic gate evaluates

	Hard rule: Logic definitions must not encode the intended solution for any
	experiment. They describe what a gate IS, not how a puzzle is solved.
]]

local LogicTypes = require(script.LogicTypes)

local LogicDefinitions = {}

--[[
	A signal-port specification for a single component type.
]]
export type PortSpec = {
	Name: string,
	Direction: LogicTypes.SignalPortDirection,
}

export type LogicComponentSpec = {
	ComponentType: string,
	Ports: { PortSpec },
	-- Default signal value for unconnected inputs.
	DefaultInput: LogicTypes.SignalValue,
	-- Optional evaluation description for editor/debug tooling.
	Description: string?,
}

-- ---------------------------------------------------------------------------
-- Actuator control ports
-- ---------------------------------------------------------------------------
--
-- Motors and winches gain a Control input port. An unconnected actuator keeps
-- its legacy automatic TEST behaviour; a connected Control signal opts the
-- actuator into automated control.

local MOTOR_CONTROL_PORT: PortSpec = {
	Name = "Control",
	Direction = "Input",
}

local WINCH_CONTROL_PORT: PortSpec = {
	Name = "Control",
	Direction = "Input",
}

-- ---------------------------------------------------------------------------
-- Logic component port definitions
-- ---------------------------------------------------------------------------

--[[
	Switch: manual on/off toggle.
	Output feeds zero or more downstream inputs.
]]
local SWITCH: LogicComponentSpec = {
	ComponentType = "Switch",
	Ports = {
		{ Name = "Out", Direction = "Output" },
	},
	DefaultInput = false,
	Description = "Manual toggle. Output mirrors the switch position.",
}

--[[
	PressureSensor: active when a payload sits on it.
]]
local PRESSURE_SENSOR: LogicComponentSpec = {
	ComponentType = "PressureSensor",
	Ports = {
		{ Name = "Out", Direction = "Output" },
	},
	DefaultInput = false,
	Description = "Outputs true while weight is on the pad.",
}

--[[
	ProximitySensor: active when something is within range.
]]
local PROXIMITY_SENSOR: LogicComponentSpec = {
	ComponentType = "ProximitySensor",
	Ports = {
		{ Name = "Out", Direction = "Output" },
	},
	DefaultInput = false,
	Description = "Outputs true when an object is close enough.",
}

--[[
	Timer: delays a rising signal.
	Input A is the trigger; output follows after a delay.
	Resets (output falls) when input drops.
]]
local TIMER: LogicComponentSpec = {
	ComponentType = "Timer",
	Ports = {
		{ Name = "In", Direction = "Input" },
		{ Name = "Out", Direction = "Output" },
	},
	DefaultInput = false,
	Description = "Delays rising input; resets output when input drops.",
}

--[[
	AND: two inputs, true only when both are true.
]]
local AND: LogicComponentSpec = {
	ComponentType = "AND",
	Ports = {
		{ Name = "A", Direction = "Input" },
		{ Name = "B", Direction = "Input" },
		{ Name = "Out", Direction = "Output" },
	},
	DefaultInput = false,
	Description = "Output true only when both inputs are true.",
}

--[[
	OR: two inputs, true when either is true.
]]
local OR: LogicComponentSpec = {
	ComponentType = "OR",
	Ports = {
		{ Name = "A", Direction = "Input" },
		{ Name = "B", Direction = "Input" },
		{ Name = "Out", Direction = "Output" },
	},
	DefaultInput = false,
	Description = "Output true when either input is true.",
}

--[[
	NOT: single input, inverts it.
]]
local NOT: LogicComponentSpec = {
	ComponentType = "NOT",
	Ports = {
		{ Name = "In", Direction = "Input" },
		{ Name = "Out", Direction = "Output" },
	},
	DefaultInput = false,
	Description = "Output is the logical negation of the input.",
}

--[[
	SignalLamp: visual output. Lights up when powered.
]]
local SIGNAL_LAMP: LogicComponentSpec = {
	ComponentType = "SignalLamp",
	Ports = {
		{ Name = "In", Direction = "Input" },
	},
	DefaultInput = false,
	Description = "Lights up when its input is true.",
}

-- ---------------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------------

local catalogue: { [string]: LogicComponentSpec } = {
	["Motor"] = {
		ComponentType = "Motor",
		Ports = { MOTOR_CONTROL_PORT },
		DefaultInput = false,
		Description = "Motor with optional Control input. Unconnected = auto-run.",
	},
	["Winch"] = {
		ComponentType = "Winch",
		Ports = { WINCH_CONTROL_PORT },
		DefaultInput = false,
		Description = "Winch with optional Control input. Unconnected = auto-run.",
	},
	["Switch"] = SWITCH,
	["PressureSensor"] = PRESSURE_SENSOR,
	["ProximitySensor"] = PROXIMITY_SENSOR,
	["Timer"] = TIMER,
	["AND"] = AND,
	["OR"] = OR,
	["NOT"] = NOT,
	["SignalLamp"] = SIGNAL_LAMP,
}

function LogicDefinitions.Get(componentType: string): LogicComponentSpec?
	return catalogue[componentType]
end

-- Returns true if the given component type has signal ports defined.
function LogicDefinitions.HasPorts(componentType: string): boolean
	return catalogue[componentType] ~= nil
end

-- Returns the Control port name for an actuator, or nil if it is not an
-- actuator with a control port.
function LogicDefinitions.GetControlPort(componentType: string): string?
	if componentType == "Motor" or componentType == "Winch" then
		return "Control"
	end
	return nil
end

-- Returns the output port name for a sensor, or nil if the component type
-- is not a sensor with a single output.
function LogicDefinitions.GetSensorOutputPort(componentType: string): string?
	if componentType == "Switch" then
		return "Out"
	end
	if componentType == "PressureSensor" then
		return "Out"
	end
	if componentType == "ProximitySensor" then
		return "Out"
	end
	return nil
end

table.freeze(catalogue)
return table.freeze(LogicDefinitions)
