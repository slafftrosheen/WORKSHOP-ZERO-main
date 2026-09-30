--!strict

--[[
	ComponentDefinitions

	The prototype catalogue. Every component is plain Roblox geometry for now:
	the point of WZ-001 is the construction kernel, not the art.

	Connector conventions (this is the part future batches must not break):

		* A connector attachment's local X axis points OUT of the component.
		* Its Y axis is the component's own "up" at that connector.
		* Connectors sit where the mating part's origin must end up, which for
		  axle sockets means half a wheel thickness outside the surface.

	So a Rigid connector on the +X end of a plank is a plain CFrame offset, the
	-X end is the same offset yawed 180 degrees, and everything else follows the
	same idea. When two connectors meet, the kernel rotates the moving one to
	face the other, so the axes above decide the final orientation.
]]

local ConstructionTypes = require(script.Parent.ConstructionTypes)

local RIGID: ConstructionTypes.ConnectorType = "Rigid"
local AXLE: ConstructionTypes.ConnectorType = "Axle"

local HALF_TURN = math.pi
local QUARTER_TURN = math.rad(90)
local MINUS_QUARTER_TURN = math.rad(-90)

-- Custom physical properties, tuned for "feels like a toy workshop".
local PLANK_DENSITY = 0.5
local BLOCK_DENSITY = 0.8
local WHEEL_DENSITY = 1.2

local definitions: { [string]: ConstructionTypes.ComponentDefinition } = {
	Plank = {
		Type = "Plank",
		DisplayName = "Plank",
		Shape = Enum.PartType.Block,
		Size = Vector3.new(8, 0.6, 2),
		Color = Color3.fromRGB(166, 126, 88),
		Material = Enum.Material.Wood,
		Density = PLANK_DENSITY,
		Friction = 0.6,
		Elasticity = 0.1,
		Spawnable = true,
		Connectors = {
			-- Both ends are rigid, so planks can be extended into longer beams.
			{ Name = "Rigid_A", Type = RIGID, Offset = CFrame.new(4, 0, 0) },
			{
				Name = "Rigid_B",
				Type = RIGID,
				Offset = CFrame.new(-4, 0, 0) * CFrame.Angles(0, HALF_TURN, 0),
			},
			-- Axle sockets on the sides, where a wheel's centre belongs.
			{
				Name = "Axle_L",
				Type = AXLE,
				Offset = CFrame.new(0, 0, -1.2) * CFrame.Angles(0, QUARTER_TURN, 0),
			},
			{
				Name = "Axle_R",
				Type = AXLE,
				Offset = CFrame.new(0, 0, 1.2) * CFrame.Angles(0, MINUS_QUARTER_TURN, 0),
			},
		},
	},

	Block = {
		Type = "Block",
		DisplayName = "Block",
		Shape = Enum.PartType.Block,
		Size = Vector3.new(2, 2, 2),
		Color = Color3.fromRGB(132, 138, 152),
		Material = Enum.Material.SmoothPlastic,
		Density = BLOCK_DENSITY,
		Friction = 0.5,
		Elasticity = 0.1,
		Spawnable = true,
		Connectors = {
			-- Rigid on the X and Y faces: the structural directions.
			{ Name = "Rigid_A", Type = RIGID, Offset = CFrame.new(1, 0, 0) },
			{
				Name = "Rigid_B",
				Type = RIGID,
				Offset = CFrame.new(-1, 0, 0) * CFrame.Angles(0, HALF_TURN, 0),
			},
			{
				Name = "Rigid_Top",
				Type = RIGID,
				Offset = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, QUARTER_TURN),
			},
			{
				Name = "Rigid_Bottom",
				Type = RIGID,
				Offset = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, MINUS_QUARTER_TURN),
			},
			-- Axle sockets on the Z faces: the chassis directions for wheels.
			{
				Name = "Axle_L",
				Type = AXLE,
				Offset = CFrame.new(0, 0, -1.2) * CFrame.Angles(0, QUARTER_TURN, 0),
			},
			{
				Name = "Axle_R",
				Type = AXLE,
				Offset = CFrame.new(0, 0, 1.2) * CFrame.Angles(0, MINUS_QUARTER_TURN, 0),
			},
		},
	},

	Wheel = {
		Type = "Wheel",
		DisplayName = "Wheel",
		-- A Roblox Cylinder spins around its X axis, which is exactly the axle.
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2.4, 2.4),
		Color = Color3.fromRGB(48, 48, 54),
		Material = Enum.Material.Rubber,
		Density = WHEEL_DENSITY,
		Friction = 0.9,
		Elasticity = 0.05,
		Spawnable = true,
		Connectors = {
			-- One connector, in the middle: the wheel hangs off this point.
			{ Name = "Axle_A", Type = AXLE, Offset = CFrame.new() },
		},
	},

	-- Placeholders. They exist so the catalogue type is honest about the plan,
	-- and are refused by ComponentFactory until they actually do something.
	Spring = {
		Type = "Spring",
		DisplayName = "Spring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 0.8, 0.8),
		Color = Color3.fromRGB(210, 176, 70),
		Material = Enum.Material.Metal,
		Density = 0.4,
		Friction = 0.4,
		Elasticity = 0.4,
		Spawnable = false,
		Connectors = {
			{ Name = "Rigid_A", Type = RIGID, Offset = CFrame.new(1, 0, 0) },
			{
				Name = "Rigid_B",
				Type = RIGID,
				Offset = CFrame.new(-1, 0, 0) * CFrame.Angles(0, HALF_TURN, 0),
			},
		},
	},

	Motor = {
		Type = "Motor",
		DisplayName = "Motor",
		Shape = Enum.PartType.Block,
		Size = Vector3.new(1.5, 1.5, 1.5),
		Color = Color3.fromRGB(196, 88, 66),
		Material = Enum.Material.Metal,
		Density = 1,
		Friction = 0.5,
		Elasticity = 0.1,
		Spawnable = false,
		Connectors = {
			{ Name = "Rigid_A", Type = RIGID, Offset = CFrame.new(0.75, 0, 0) },
			{
				Name = "Axle_A",
				Type = AXLE,
				Offset = CFrame.new(0, 0, -0.75) * CFrame.Angles(0, QUARTER_TURN, 0),
			},
		},
	},
}

local ComponentDefinitions = {}

function ComponentDefinitions.Get(componentType: string): ConstructionTypes.ComponentDefinition?
	return definitions[componentType]
end

-- Freeze the catalogue so no module can quietly re-balance a component at runtime.
for _, definition in definitions do
	for _, connector in definition.Connectors do
		table.freeze(connector)
	end

	table.freeze(definition.Connectors)
	table.freeze(definition)
end

table.freeze(definitions)

return table.freeze(ComponentDefinitions)
