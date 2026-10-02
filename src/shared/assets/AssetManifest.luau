--!strict

--[[
	AssetManifest

	Central catalog of known 3D visual assets across Workshop Zero.
	Defines category hierarchy, expected bounding dimensions, and aliases.

	Invariants:
		* Visual assets are replaceable skins over stable physics contracts.
		* Missing art must never make an experiment unplayable.
		* Does not encode gameplay physics (handled by ComponentDefinitions).
]]

export type AssetEntry = {
	Category: string,
	Name: string,
	Aliases: { string }?,
	ExpectedBounds: Vector3,
	Tolerance: number?, -- max allowable scale deviation ratio (default 2.5)
	Description: string?,
}

export type AssetManifestData = {
	Components: { [string]: AssetEntry },
	Payloads: { [string]: AssetEntry },
	Goals: { [string]: AssetEntry },
	Props: { [string]: AssetEntry },
}

local Manifest: AssetManifestData = {
	Components = {
		Plank = {
			Category = "Components",
			Name = "Plank",
			Aliases = { "plank_beam_01", "PlankBeam" },
			ExpectedBounds = Vector3.new(8.0, 0.6, 2.0),
			Description = "Primary structural wooden beam.",
		},
		Block = {
			Category = "Components",
			Name = "Block",
			Aliases = { "block_cube_01", "ConstructionBlock" },
			ExpectedBounds = Vector3.new(2.0, 2.0, 2.0),
			Description = "Modular structural anchor cube.",
		},
		Wheel = {
			Category = "Components",
			Name = "Wheel",
			Aliases = { "wheel_rubber_01", "RubberWheel" },
			ExpectedBounds = Vector3.new(0.4, 2.4, 2.4),
			Description = "Heavy rubber rolling wheel.",
		},
		Motor = {
			Category = "Components",
			Name = "Motor",
			Aliases = { "motor_electric_01", "ElectricMotor" },
			ExpectedBounds = Vector3.new(2.0, 2.0, 2.0),
			Description = "Powered rotary actuator drive.",
		},
		Spring = {
			Category = "Components",
			Name = "Spring",
			Aliases = { "spring_compression_01", "SpringLauncher" },
			ExpectedBounds = Vector3.new(3.0, 2.5, 3.0),
			Description = "Stored-energy compression launcher.",
		},
		Fan = {
			Category = "Components",
			Name = "Fan",
			Aliases = { "fan_propeller_01", "PropellerFan" },
			ExpectedBounds = Vector3.new(0.8, 3.2, 3.2),
			Description = "Aerodynamic thrust fan module.",
		},
		Hook = {
			Category = "Components",
			Name = "Hook",
			Aliases = { "hook_anchor_01", "RopeHook" },
			ExpectedBounds = Vector3.new(1.0, 1.5, 1.0),
			Description = "Structural rope anchor hook.",
		},
		Winch = {
			Category = "Components",
			Name = "Winch",
			Aliases = { "winch_powered_01", "PoweredWinch" },
			ExpectedBounds = Vector3.new(2.0, 2.0, 2.0),
			Description = "Motorized rope tension winch.",
		},
		Switch = {
			Category = "Components",
			Name = "Switch",
			Aliases = { "switch_toggle_01", "ToggleSwitch" },
			ExpectedBounds = Vector3.new(2.0, 1.6, 2.0),
			Description = "Manual on/off toggle switch module.",
		},
		PressureSensor = {
			Category = "Components",
			Name = "PressureSensor",
			Aliases = { "pressure_plate_01", "PressurePlate" },
			ExpectedBounds = Vector3.new(3.0, 0.8, 3.0),
			Description = "Floor pressure plate contact sensor.",
		},
		ProximitySensor = {
			Category = "Components",
			Name = "ProximitySensor",
			Aliases = { "proximity_sensor_01", "DistanceSensor" },
			ExpectedBounds = Vector3.new(2.0, 1.8, 2.0),
			Description = "Directional obstacle detection sensor.",
		},
		Timer = {
			Category = "Components",
			Name = "Timer",
			Aliases = { "timer_delay_01", "DelayTimer" },
			ExpectedBounds = Vector3.new(2.0, 2.0, 2.0),
			Description = "Fixed-delay signal pulse timer.",
		},
		AND = {
			Category = "Components",
			Name = "AND",
			Aliases = { "AndGate", "gate_and_01" },
			ExpectedBounds = Vector3.new(2.4, 2.0, 2.0),
			Description = "Two-input logical AND gate block.",
		},
		OR = {
			Category = "Components",
			Name = "OR",
			Aliases = { "OrGate", "gate_or_01" },
			ExpectedBounds = Vector3.new(2.4, 2.0, 2.0),
			Description = "Two-input logical OR gate block.",
		},
		NOT = {
			Category = "Components",
			Name = "NOT",
			Aliases = { "NotGate", "gate_not_01" },
			ExpectedBounds = Vector3.new(2.0, 2.0, 2.0),
			Description = "Single-input logical inverter block.",
		},
		SignalLamp = {
			Category = "Components",
			Name = "SignalLamp",
			Aliases = { "signal_lamp_01", "IndicatorLamp" },
			ExpectedBounds = Vector3.new(1.8, 1.8, 1.8),
			Description = "High-visibility green signal indicator lamp.",
		},
	},

	Payloads = {
		Duck = {
			Category = "Payloads",
			Name = "Duck",
			Aliases = { "duck_rubber_01", "RubberDuck" },
			ExpectedBounds = Vector3.new(2.5, 2.0, 3.0),
			Description = "The star rubber duck payload.",
		},
	},

	Goals = {
		GoalButton = {
			Category = "Goals",
			Name = "GoalButton",
			Aliases = { "button_goal_red_01", "BigRedButton" },
			ExpectedBounds = Vector3.new(4.0, 1.8, 4.0),
			Description = "Giant mechanical red push button.",
		},
	},

	Props = {
		MakerWorkbench = {
			Category = "Props",
			Name = "MakerWorkbench",
			Aliases = { "Workbench", "workbench_maker_01" },
			ExpectedBounds = Vector3.new(12.0, 3.5, 5.0),
			Description = "Large wooden workshop workbench with vise.",
		},
		ToolStorageRack = {
			Category = "Props",
			Name = "ToolStorageRack",
			Aliases = { "ToolRack", "rack_tool_01" },
			ExpectedBounds = Vector3.new(10.0, 4.0, 4.0),
			Description = "Industrial storage rack for staging parts.",
		},
		Crate = {
			Category = "Props",
			Name = "Crate",
			Aliases = { "StorageCrate", "crate_wood_01" },
			ExpectedBounds = Vector3.new(3.0, 3.0, 3.0),
			Description = "Wooden workshop storage crate.",
		},
		WorkshopWallPanel = {
			Category = "Props",
			Name = "WorkshopWallPanel",
			Aliases = { "WallPanel", "wall_panel_01" },
			ExpectedBounds = Vector3.new(8.0, 12.0, 1.0),
			Description = "Modular workshop background wall panel.",
		},
		ConnectorBoard = {
			Category = "Props",
			Name = "ConnectorBoard",
			Aliases = { "ToolBoard", "board_connectors_01" },
			ExpectedBounds = Vector3.new(8.0, 6.0, 0.5),
			Description = "Pegboard displaying maker tools and connectors.",
		},
	},
}

local AssetManifest = {}

function AssetManifest.GetCategory(category: string): { [string]: AssetEntry }?
	return (Manifest :: any)[category]
end

function AssetManifest.GetEntry(category: string, name: string): AssetEntry?
	local cat = AssetManifest.GetCategory(category)
	if cat == nil then
		return nil
	end

	-- Direct key match
	if cat[name] ~= nil then
		return cat[name]
	end

	-- Case-insensitive or alias search
	local lower = string.lower(name)
	for _, entry in cat do
		if string.lower(entry.Name) == lower then
			return entry
		end
		if entry.Aliases ~= nil then
			for _, alias in entry.Aliases do
				if string.lower(alias) == lower then
					return entry
				end
			end
		end
	end

	return nil
end

function AssetManifest.GetAllCategories(): { string }
	return { "Components", "Payloads", "Goals", "Props" }
end

return table.freeze(AssetManifest)
