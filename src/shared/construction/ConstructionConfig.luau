--!strict

--[[
	ConstructionConfig

	One place for every tunable number and name in the construction kernel.

	Values here are starting points, not laws. They are deliberately readable so
	that a human can nudge them after playing instead of digging through
	geometry code.

	Shared by server and client on purpose: the client's snap *preview* uses the
	same distances as the server's snap *decision*, so the highlight never lies
	about what will happen.
]]

local ConstructionConfig = {
	-- Scene naming ------------------------------------------------------------

	-- Runtime sandbox created by the Studio-only harness.
	RuntimeFolderName = "WorkshopZeroRuntime",
	ComponentsFolderName = "Components",
	ConnectionsFolderName = "Connections",
	FloorName = "Floor",
	BuildBoundsName = "BuildBounds",
	SpawnName = "WorkshopSpawn",

	-- The hand-authored workshop we must never touch, if it ever exists.
	AuthoredWorkshopName = "Workshop",

	-- Networking --------------------------------------------------------------

	RemotesFolderName = "WorkshopZeroRemotes",
	StateValueName = "SimulationState",
	RemoteSimulationAction = "RequestSimulationAction",
	RemoteRotation = "RequestRotation",
	RemoteDisconnect = "RequestDisconnect",
	RemoteDragState = "DragStateChanged",

	-- Attributes --------------------------------------------------------------

	AttributeComponent = "WZ_Component",
	AttributeComponentId = "WZ_ComponentId",
	AttributeComponentType = "WZ_ComponentType",
	AttributeConnector = "WZ_Connector",
	AttributeConnectorType = "WZ_ConnectorType",
	AttributeOccupied = "WZ_Occupied",

	-- Component structure -----------------------------------------------------

	RootPartName = "Root",
	DragDetectorName = "WZDragDetector",
	ConnectionsFolderTag = "WZ_Connection",

	-- Snapping -----------------------------------------------------------------

	-- Distance between connector positions that still counts as "close enough".
	SnapDistance = 1.25,

	-- Half-angle tolerance. A connector counts as compatible when its outward
	-- axis is within this angle of the direction the snap would rotate it to.
	SnapAngleToleranceDegrees = 60,

	-- Build area ---------------------------------------------------------------

	-- Legal build volume, centred on the BuildBounds part.
	BuildBoundsSize = Vector3.new(60, 30, 60),

	-- Slack allowed past the bounds before a placement is rejected.
	BuildBoundsPadding = 2,

	-- Coarse safety net: a component dragged further than this from the centre
	-- of the build area is always returned to its last valid transform.
	MaxComponentDistance = 80,

	-- Rotation -----------------------------------------------------------------

	YawStepDegrees = 15,
	FlipDegrees = 90,

	-- Client interaction -------------------------------------------------------

	SelectionRayLength = 500,
	PreviewSphereDiameter = 0.7,
}

return table.freeze(ConstructionConfig)
