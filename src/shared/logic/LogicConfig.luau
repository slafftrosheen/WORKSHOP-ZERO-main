--!strict

--[[
	LogicConfig

	One place for every tunable number and name in the signal/logic layer.
	Shared by server and client: the client's wire preview uses the same
	distances as the server's wire validation, so the highlight never lies
	about what will happen.
]]

local Config = {

	-- Scene naming ------------------------------------------------------------

	-- Folder that holds all signal-port Attachments (for debugging).
	SignalPortsFolderName = "SignalPorts",
	-- Name used for the signal-port Attachment instances.
	SignalPortName = "SignalPort",

	-- Attributes on signal-port Attachments ------------------------------------

	AttributeSignalPort = "WZ_SignalPort",
	AttributeSignalDirection = "WZ_SignalDirection",
	AttributeSignalPortName = "WZ_SignalPortName",

	-- Visible socket markers, so a child can see where signal ports live.
	-- Distinct from mechanical socket markers (Socket) by shape and colour.
	ShowSignalMarkers = true,
	SignalMarkerName = "SignalSocket",
	SignalMarkerSize = Vector3.new(0.45, 0.15, 0.45),
	SignalSocketColor = Color3.fromRGB(40, 90, 200),

	-- Input and Output ports look different: a circle vs a hexagon.
	-- (Shape, not colour alone.)
	SignalMarkerInputShape = Enum.PartType.Block,
	SignalMarkerOutputShape = Enum.PartType.Cylinder,

	-- Wire visual config -------------------------------------------------------

	-- Maximum distance a wire can span, in studs.
	MaxSignalWireLength = 35,

	-- Beam tuning.
	WireColor = Color3.fromRGB(40, 200, 255),
	WireColorActive = Color3.fromRGB(80, 240, 255),
	WireColorInactive = Color3.fromRGB(25, 75, 140),
	WireThickness = 0.12,
	WireTransparency = 0.3,

	-- Emissive glow so wires read as "carrying energy".
	WireLightEmissive = 0.6,
	WireLightEmissiveActive = 0.9,
	WireLightEmissiveInactive = 0.15,
	WireLightColor = Color3.fromRGB(80, 220, 255),

	-- Logic tick config --------------------------------------------------------

	-- Central LogicService update loop.
	-- 15 Hz is well within the 10-20 Hz band the spec asks for.
	LogicTickRate = 15,

	-- When true, logs every signal change and gate evaluation.
	-- Dev override only; never enable in a player session.
	LogicTrace = false,

	-- Unconnected inputs default to false (never nil as an electrical state).
	SignalDefault = false,

	-- Component behaviour ------------------------------------------------------
	TimerDelay = 2.0,
	ProximitySensorRange = 12.0,

	-- Lifecycle ---------------------------------------------------------------

	-- A wire shorter than this is rejected even if both endpoints are valid.
	MinSignalWireLength = 0.5,
}

return table.freeze(Config)
