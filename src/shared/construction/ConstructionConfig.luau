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

	-- Feature flags ------------------------------------------------------------

	-- The WZ-001 engineering sandbox. Off by default now that Experiment 001
	-- is the real experience; flip it on for kernel development.
	EnablePrototypeWorkshop = false,

	-- Dev override: for Studio development only. When set to an experiment id
	-- (e.g. "uphill_delivery"), boots directly into that experiment.
	DevExperimentId = nil :: string?,

	-- Playtest diagnostics in Studio Output (attempt duration, duck height and
	-- speed, parts moved). Output only - nothing is written or uploaded.
	PlaytestDiagnostics = true,

	-- A component counts as "used" once it has moved this far from where it was
	-- staged, or once it is part of any connection. Deliberately coarse: a child
	-- can check it by looking at the rack.
	PartsUsedMovedDistance = 0.25,

	-- Collision groups --------------------------------------------------------

	-- Players must never solve or break an experiment by walking into it.
	-- Components collide with each other, the world and the payload, but not
	-- with the player.
	CollisionGroupPlayers = "Players",
	CollisionGroupComponents = "WorkshopComponents",
	CollisionGroupPayloads = "Payloads",
	CollisionGroupEnvironment = "Environment",
	CollisionGroupGoalTrigger = "GoalTrigger",

	-- Networking --------------------------------------------------------------

	RemotesFolderName = "WorkshopZeroRemotes",
	StateValueName = "SimulationState",
	RemoteSimulationAction = "RequestSimulationAction",
	RemoteRotation = "RequestRotation",
	RemoteDisconnect = "RequestDisconnect",
	RemoteDragState = "DragStateChanged",

	-- Experiment layer: the challenge lifecycle and its feedback.
	RemoteExperimentAction = "RequestExperimentAction",
	RemoteFailureToast = "FailureToast",
	ExperimentStateValueName = "ExperimentState",
	CurrentExperimentValueName = "CurrentExperimentId",
	AttemptValueName = "ExperimentAttempt",
	PartsUsedValueName = "ExperimentPartsUsed",
	UnlockedExperimentValueName = "UnlockedExperimentIndex",

	-- Attributes --------------------------------------------------------------

	AttributeComponent = "WZ_Component",
	AttributeComponentId = "WZ_ComponentId",
	AttributeComponentType = "WZ_ComponentType",
	AttributeConnector = "WZ_Connector",
	AttributeConnectorType = "WZ_ConnectorType",
	AttributeOccupied = "WZ_Occupied",

	-- Payload and level attributes. A payload is the thing an experiment asks
	-- the player to move; it is never a construction component.
	AttributePayload = "WZ_Payload",
	AttributePayloadType = "WZ_PayloadType",
	AttributeGoal = "WZ_Goal",
	AttributeGoalTrigger = "WZ_GoalTrigger",
	AttributeGenerated = "WZ_Generated",
	AttributeExperiment = "WZ_Experiment",
	AttributePowered = "WZ_Powered",

	-- Visible socket markers, so a child can see where things connect.
	-- Rigid is a flat plate, Axle is a round cap: shape, not colour alone.
	ShowConnectorMarkers = true,
	RigidMarkerSize = Vector3.new(1.4, 0.12, 1.4),
	AxleMarkerSize = Vector3.new(0.35, 1.5, 1.5),
	ConnectorMarkerName = "Socket",

	-- Component structure -----------------------------------------------------

	RootPartName = "Root",
	DragDetectorName = "WZDragDetector",
	ConnectionsFolderTag = "WZ_Connection",

	-- Motor / Actuator tunables -----------------------------------------------

	-- Starting target for toy electric motor physics.
	-- Wheel radius ~1.2 studs, 16 rad/s gives ~19 studs/s linear wheel speed.
	MotorAngularVelocity = 16,
	MotorMaxTorque = 12000,
	MotorAngularResponsiveness = 20,

	-- Fan / Behaviour tunables ------------------------------------------------

	FanMaxRange = 32,
	FanConeAngleDegrees = 45,
	FanBaseForce = 1200,
	FanThrustForce = 500,

	-- Snapping -----------------------------------------------------------------

	-- Distance between connector positions that still counts as "close enough".
	SnapDistance = 1.75,

	-- Half-angle tolerance. A connector counts as compatible when its outward
	-- axis is within this angle of the direction the snap would rotate it to.
	SnapAngleToleranceDegrees = 75,

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
