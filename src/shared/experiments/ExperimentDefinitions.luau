--!strict

--[[
	ExperimentDefinitions

	Data for the experiments, plus the copy the player actually reads.

	Everything tunable about Save the Duck lives here: the parts on the rack,
	the level numbers, the "that was funny" thresholds and the failure flavour
	text. Server and client read the same file, so what the server announces is
	what the client prints.

	Geometry reasoning for the first playable:

		* the gap is a 14-stud trench cut into the workshop floor
		* two planks end to end are 16 studs, so a bridge reaches with a stud of
		  overlap at each end - a child can succeed on the first idea
		* plank + block + plank is 18 studs, so longer machines are possible too
		* the two pads are the same height, so bridges, carts, ramps, towers and
		  accidental catapults are all viable
		* the trench is only four studs deep: the player jumps out, the duck does
		  not

	Nothing here encodes a solution. If parts cannot plausibly solve it, the
	gap shrinks - that is the only dial that needs touching.
]]

local RunService = game:GetService("RunService")

local ConstructionConfig = require(script.Parent.Parent.construction.ConstructionConfig)
local ExperimentTypes = require(script.Parent.ExperimentTypes)

local ExperimentDefinitions = {}

local SAVE_THE_DUCK: ExperimentTypes.ExperimentDefinition = {
	Id = "save_the_duck",
	Number = 1,
	Name = "SAVE THE DUCK",
	Objective = "Get the duck to the button.",

	-- Copy shown to the player. Short, playful, never instructional.
	IntroTitle = "EXPERIMENT 001",
	IntroButton = "START BUILDING",
	SuccessTitle = "SUCCESS!",
	SuccessLine = "THE DUCK MADE IT.",
	RestartButton = "TRY AGAIN",

	DiscoveryTitle = "STRUCTURE",
	DiscoveryBody = "Longer beams bend the problem around you.",

	-- What is available on the rack. Nothing else exists in the world.
	Inventory = {
		{ ComponentType = "Plank", Count = 2 },
		{ ComponentType = "Block", Count = 2 },
		{ ComponentType = "Wheel", Count = 4 },
	},

	Payload = {
		Type = "Duck",
		BodySize = Vector3.new(2.4, 1.8, 3),
		Density = 0.35,
		Friction = 0.6,
		Elasticity = 0.05,
	},

	Geometry = {
		-- The safety net. Failed machines land here instead of vanishing.
		FloorSize = Vector3.new(120, 2, 120),
		FloorCenter = Vector3.new(0, -1, 0),

		-- Ground level, so the player walks everywhere and can never be
		-- stranded on a platform.
		PitFloorTopY = -4,

		StartPadSize = Vector3.new(24, 0.6, 16),
		StartPadCenter = Vector3.new(0, 0.3, -16),

		GoalPadSize = Vector3.new(20, 0.6, 16),
		GoalPadCenter = Vector3.new(0, 0.3, 14),

		DuckSpawn = Vector3.new(0, 1.5, -12),
		ButtonPosition = Vector3.new(0, 0.6, 14),

		BackWallSize = Vector3.new(120, 30, 2),
		BackWallCenter = Vector3.new(0, 15, -42),

		-- Beside the start pad, on the workshop floor.
		PlayerSpawn = Vector3.new(-14, 0.5, -16),

		BuildBoundsSize = Vector3.new(64, 30, 64),
		BuildBoundsCenter = Vector3.new(0, 8, 0),

		StagingRows = { -21, -18.5, -16 },
		StagingSpacing = 1,
	},

	Thresholds = {
		-- The duck sits at y = 0.9 on the floor and y = -3.1 in the trench.
		PitY = 0,
		AwayDistance = 70,
		FastSpeed = 45,
		HighY = 32,
		CleanupY = -40,
		StructuralPartCount = 3,
		StructuralTiltDegrees = 60,
	},

	-- Short. Laugh at the machine, never at the child.
	FailureMessages = {
		DuckDown = {
			"DUCK DOWN.",
			"WELL... THAT WASN'T THE BRIDGE.",
		},
		DuckDeparture = {
			"UNSCHEDULED DUCK DEPARTURE.",
		},
		BallisticDuck = {
			"BALLISTIC DUCK.",
		},
		SpaceProgram = {
			"SPACE PROGRAM STARTED.",
		},
		StructuralOptimism = {
			"STRUCTURAL OPTIMISM DETECTED.",
			"CONFIDENCE: HIGH\nSTRUCTURAL INTEGRITY: LESS HIGH.",
		},
	},
}

local UPHILL_DELIVERY: ExperimentTypes.ExperimentDefinition = {
	Id = "uphill_delivery",
	Number = 2,
	Name = "UPHILL DELIVERY",
	Objective = "Get the duck to the button.",

	IntroTitle = "EXPERIMENT 002",
	IntroButton = "START BUILDING",
	SuccessTitle = "SUCCESS!",
	SuccessLine = "THE DUCK MADE IT.",
	RestartButton = "TRY AGAIN",

	DiscoveryTitle = "POWER",
	DiscoveryBody = "Rotation becomes movement when wheels can push against the ground.",

	Inventory = {
		{ ComponentType = "Plank", Count = 3 },
		{ ComponentType = "Block", Count = 3 },
		{ ComponentType = "Wheel", Count = 6 },
		{ ComponentType = "Motor", Count = 2 },
	},

	Payload = {
		Type = "Duck",
		BodySize = Vector3.new(2.4, 1.8, 3),
		Density = 0.35,
		Friction = 0.6,
		Elasticity = 0.05,
	},

	Geometry = {
		FloorSize = Vector3.new(120, 2, 120),
		FloorCenter = Vector3.new(0, -1, 0),
		PitFloorTopY = -4,

		StartPadSize = Vector3.new(24, 0.6, 18),
		StartPadCenter = Vector3.new(0, 0.3, -18),

		GoalPadSize = Vector3.new(22, 0.6, 16),
		GoalPadCenter = Vector3.new(0, 10.3, 22),

		DuckSpawn = Vector3.new(0, 1.5, -14),
		ButtonPosition = Vector3.new(0, 10.6, 22),

		BackWallSize = Vector3.new(120, 30, 2),
		BackWallCenter = Vector3.new(0, 15, -42),

		PlayerSpawn = Vector3.new(-15, 0.5, -18),

		BuildBoundsSize = Vector3.new(64, 34, 72),
		BuildBoundsCenter = Vector3.new(0, 12, 2),

		StagingRows = { -24, -21.5, -19, -16.5 },
		StagingSpacing = 1,
	},

	Thresholds = {
		PitY = 0,
		AwayDistance = 75,
		FastSpeed = 45,
		HighY = 38,
		CleanupY = -40,
		StructuralPartCount = 3,
		StructuralTiltDegrees = 65,
	},

	FailureMessages = {
		LowTravel = {
			"LOTS OF NOISE.\nNOT MUCH TRAVEL.",
		},
		BackwardMovement = {
			"TECHNICALLY, THAT IS MOVEMENT.",
		},
		Rollback = {
			"GRAVITY HAS FILED AN OBJECTION.",
		},
		VehicleFlip = {
			"WHEELS UP.\nNOT IDEAL.",
		},
		HighRpm = {
			"RPM: QUESTIONABLE.",
		},
		DuckDown = {
			"DUCK DOWN.",
		},
		DuckDeparture = {
			"UNSCHEDULED DUCK DEPARTURE.",
		},
		BallisticDuck = {
			"BALLISTIC DUCK.",
		},
		SpaceProgram = {
			"SPACE PROGRAM STARTED.",
		},
		StructuralOptimism = {
			"STRUCTURAL OPTIMISM DETECTED.",
		},
	},
}

ExperimentDefinitions.SaveTheDuck = SAVE_THE_DUCK
ExperimentDefinitions.UphillDelivery = UPHILL_DELIVERY

local OVER_THE_WALL: ExperimentTypes.ExperimentDefinition = {
	Id = "over_the_wall",
	Number = 3,
	Name = "OVER THE WALL",
	Objective = "Get the duck over the wall.",

	IntroTitle = "EXPERIMENT 003",
	IntroButton = "START BUILDING",
	SuccessTitle = "SUCCESS!",
	SuccessLine = "THE DUCK MADE IT OVER.",
	RestartButton = "TRY AGAIN",

	DiscoveryTitle = "STORED ENERGY",
	DiscoveryBody = "A compressed spring can release its energy very quickly.",

	Inventory = {
		{ ComponentType = "Plank", Count = 3 },
		{ ComponentType = "Block", Count = 4 },
		{ ComponentType = "Wheel", Count = 4 },
		{ ComponentType = "Motor", Count = 1 },
		{ ComponentType = "Spring", Count = 2 },
	},

	Payload = {
		Type = "Duck",
		BodySize = Vector3.new(2.4, 1.8, 3),
		Density = 0.35,
		Friction = 0.6,
		Elasticity = 0.05,
	},

	Geometry = {
		FloorSize = Vector3.new(120, 2, 120),
		FloorCenter = Vector3.new(0, -1, 0),
		PitFloorTopY = -4,

		StartPadSize = Vector3.new(24, 0.6, 18),
		StartPadCenter = Vector3.new(0, 0.3, -18),

		GoalPadSize = Vector3.new(22, 0.6, 18),
		GoalPadCenter = Vector3.new(0, 0.3, 18),

		DuckSpawn = Vector3.new(0, 1.5, -14),
		ButtonPosition = Vector3.new(0, 0.6, 18),

		BackWallSize = Vector3.new(120, 30, 2),
		BackWallCenter = Vector3.new(0, 15, -42),

		PlayerSpawn = Vector3.new(-15, 0.5, -18),

		BuildBoundsSize = Vector3.new(64, 34, 72),
		BuildBoundsCenter = Vector3.new(0, 12, 0),

		StagingRows = { -24, -21.5, -19, -16.5, -14 },
		StagingSpacing = 1,
	},

	Thresholds = {
		PitY = 0,
		AwayDistance = 75,
		FastSpeed = 45,
		HighY = 40,
		CleanupY = -40,
		StructuralPartCount = 3,
		StructuralTiltDegrees = 65,
	},

	FailureMessages = {
		WallImpact = {
			"WALL: 1\nMACHINE: 0",
			"THE WALL WAS UNIMPRESSED.",
		},
		VerticalProgress = {
			"VERTICAL PROGRESS DETECTED.",
			"SPRING LOADED.\nPLAN QUESTIONABLE.",
		},
		SpaceProgram = {
			"ALMOST A SPACE PROGRAM.",
			"SPACE PROGRAM STARTED.",
		},
		DuckTrajectory = {
			"DUCK TRAJECTORY: CREATIVE.",
		},
		DuckDown = {
			"DUCK DOWN.",
		},
		DuckDeparture = {
			"UNSCHEDULED DUCK DEPARTURE.",
		},
		BallisticDuck = {
			"BALLISTIC DUCK.",
		},
		StructuralOptimism = {
			"STRUCTURAL OPTIMISM DETECTED.",
		},
	},
}

ExperimentDefinitions.OverTheWall = OVER_THE_WALL

local WINDY_BUSINESS: ExperimentTypes.ExperimentDefinition = {
	Id = "windy_business",
	Number = 4,
	Name = "WINDY BUSINESS",
	Objective = "Move the duck without touching it.",

	IntroTitle = "EXPERIMENT 004",
	IntroButton = "START BUILDING",
	SuccessTitle = "SUCCESS!",
	SuccessLine = "MOVED BY AIR ALONE.",
	RestartButton = "TRY AGAIN",

	DiscoveryTitle = "FORCE",
	DiscoveryBody = "You can move something without touching it directly.",

	Inventory = {
		{ ComponentType = "Block", Count = 4 },
		{ ComponentType = "Plank", Count = 2 },
		{ ComponentType = "Motor", Count = 2 },
		{ ComponentType = "Fan", Count = 2 },
		{ ComponentType = "Wheel", Count = 2 },
	},

	Payload = {
		Type = "Duck",
		BodySize = Vector3.new(2.4, 1.8, 3),
		Density = 0.35,
		Friction = 0.05,
		Elasticity = 0.05,
	},

	Geometry = {
		FloorSize = Vector3.new(120, 2, 120),
		FloorCenter = Vector3.new(0, -1, 0),
		PitFloorTopY = -4,

		StartPadSize = Vector3.new(20, 0.6, 24),
		StartPadCenter = Vector3.new(-14, 0.3, -12),

		GoalPadSize = Vector3.new(18, 0.6, 14),
		GoalPadCenter = Vector3.new(0, 0.3, 16),

		DuckSpawn = Vector3.new(0, 1.5, -14),
		ButtonPosition = Vector3.new(0, 0.6, 16),

		BackWallSize = Vector3.new(120, 30, 2),
		BackWallCenter = Vector3.new(0, 15, -42),

		PlayerSpawn = Vector3.new(-18, 0.5, -12),

		BuildBoundsSize = Vector3.new(64, 34, 72),
		BuildBoundsCenter = Vector3.new(0, 12, 0),

		StagingRows = { -22, -19.5, -17, -14.5, -12 },
		StagingSpacing = 1,
	},

	Thresholds = {
		PitY = 0,
		AwayDistance = 75,
		FastSpeed = 45,
		HighY = 40,
		CleanupY = -40,
		StructuralPartCount = 3,
		StructuralTiltDegrees = 65,
	},

	FailureMessages = {
		NonTouchViolation = {
			"THAT COUNTS AS TOUCHING.",
			"HANDS OFF THE DUCK!",
		},
		DuckDown = {
			"DUCK DOWN.",
		},
		DuckDeparture = {
			"UNSCHEDULED DUCK DEPARTURE.",
		},
		BallisticDuck = {
			"BALLISTIC DUCK.",
		},
		SpaceProgram = {
			"SPACE PROGRAM STARTED.",
		},
		StructuralOptimism = {
			"STRUCTURAL OPTIMISM DETECTED.",
		},
	},
}

ExperimentDefinitions.WindyBusiness = WINDY_BUSINESS

local LIFT_OFF: ExperimentTypes.ExperimentDefinition = {
	Id = "lift_off",
	Number = 5,
	Name = "LIFT OFF",
	Objective = "Get the duck onto the high platform.",

	IntroTitle = "EXPERIMENT 005",
	IntroButton = "START BUILDING",
	SuccessTitle = "SUCCESS!",
	SuccessLine = "THE DUCK MADE IT.",
	RestartButton = "TRY AGAIN",

	DiscoveryTitle = "TENSION",
	DiscoveryBody = "A rope can pull a load, but it cannot push one.",

	Inventory = {
		{ ComponentType = "Plank", Count = 3 },
		{ ComponentType = "Block", Count = 4 },
		{ ComponentType = "Wheel", Count = 2 },
		{ ComponentType = "Hook", Count = 3 },
		{ ComponentType = "Winch", Count = 2 },
		{ ComponentType = "Motor", Count = 1 },
	},

	Payload = {
		Type = "Duck",
		BodySize = Vector3.new(2.4, 1.8, 3),
		Density = 0.35,
		Friction = 0.6,
		Elasticity = 0.05,
	},

	Geometry = {
		FloorSize = Vector3.new(120, 2, 120),
		FloorCenter = Vector3.new(0, -1, 0),
		PitFloorTopY = -4,

		StartPadSize = Vector3.new(22, 0.6, 18),
		StartPadCenter = Vector3.new(0, 0.3, -16),

		GoalPadSize = Vector3.new(18, 0.8, 16),
		GoalPadCenter = Vector3.new(0, 14.4, 14),

		DuckSpawn = Vector3.new(0, 1.5, -12),
		ButtonPosition = Vector3.new(0, 14.8, 14),

		BackWallSize = Vector3.new(120, 36, 2),
		BackWallCenter = Vector3.new(0, 18, -42),

		PlayerSpawn = Vector3.new(-16, 0.5, -16),

		BuildBoundsSize = Vector3.new(64, 40, 72),
		BuildBoundsCenter = Vector3.new(0, 16, 0),

		StagingRows = { -22, -19.5, -17, -14.5, -12 },
		StagingSpacing = 1,
	},

	Thresholds = {
		PitY = 0,
		AwayDistance = 75,
		FastSpeed = 45,
		HighY = 48,
		CleanupY = -40,
		StructuralPartCount = 3,
		StructuralTiltDegrees = 65,
	},

	FailureMessages = {
		DuckDown = {
			"DUCK DOWN.",
			"ROPE HAS OPINIONS.",
			"GRAVITY REMAINS EMPLOYED.",
		},
		DuckDeparture = {
			"LOAD TEST: INTERESTING.",
			"DUCK ELEVATOR: TEMPORARILY OUT OF SERVICE.",
		},
		BallisticDuck = {
			"THAT IS TECHNICALLY A CRANE.",
			"BALLISTIC DUCK.",
		},
		SpaceProgram = {
			"SPACE PROGRAM STARTED.",
		},
		StructuralOptimism = {
			"STRUCTURAL OPTIMISM DETECTED.",
		},
	},
}

ExperimentDefinitions.LiftOff = LIFT_OFF

local DONT_HIT_THE_WALL: ExperimentTypes.ExperimentDefinition = {
	Id = "dont_hit_the_wall",
	Number = 6,
	Name = "DON'T HIT THE WALL",
	Objective = "Get the duck into the target. Stop before the wall.",

	IntroTitle = "EXPERIMENT 006",
	IntroButton = "START BUILDING",
	SuccessTitle = "SUCCESS!",
	SuccessLine = "STOPPED IN TIME.",
	RestartButton = "TRY AGAIN",

	DiscoveryTitle = "FEEDBACK",
	DiscoveryBody = "A sensor can change what a machine does while it is running.",

	Inventory = {
		{ ComponentType = "Plank", Count = 2 },
		{ ComponentType = "Block", Count = 3 },
		{ ComponentType = "Wheel", Count = 4 },
		{ ComponentType = "Motor", Count = 2 },
		{ ComponentType = "ProximitySensor", Count = 2 },
		{ ComponentType = "NOT", Count = 2 },
		{ ComponentType = "SignalLamp", Count = 1 },
		{ ComponentType = "Switch", Count = 1 },
	},

	Payload = {
		Type = "Duck",
		BodySize = Vector3.new(2.4, 1.8, 3),
		Density = 0.35,
		Friction = 0.6,
		Elasticity = 0.05,
	},

	Geometry = {
		FloorSize = Vector3.new(120, 2, 120),
		FloorCenter = Vector3.new(0, -1, 0),
		PitFloorTopY = -4,

		StartPadSize = Vector3.new(24, 0.6, 18),
		StartPadCenter = Vector3.new(0, 0.3, -22),

		GoalPadSize = Vector3.new(22, 0.6, 14),
		GoalPadCenter = Vector3.new(0, 0.3, 10),

		DuckSpawn = Vector3.new(0, 1.5, -20),
		ButtonPosition = Vector3.new(0, 0.6, 10),

		BackWallSize = Vector3.new(120, 30, 2),
		BackWallCenter = Vector3.new(0, 15, -42),

		PlayerSpawn = Vector3.new(-15, 0.5, -22),

		BuildBoundsSize = Vector3.new(64, 34, 72),
		BuildBoundsCenter = Vector3.new(0, 12, 0),

		StagingRows = { -28, -25.5, -23, -20.5, -18, -15.5, -13, -10.5 },
		StagingSpacing = 1,
	},

	Thresholds = {
		PitY = 0,
		AwayDistance = 75,
		FastSpeed = 45,
		HighY = 40,
		CleanupY = -40,
		StructuralPartCount = 3,
		StructuralTiltDegrees = 65,
	},

	FailureMessages = {
		WallImpact = {
			"BRAKES: OPTIONAL, APPARENTLY.",
			"WALL DETECTED.\nSLIGHTLY LATE.",
		},
		DuckDown = {
			"DUCK DOWN.",
		},
		DuckDeparture = {
			"UNSCHEDULED DUCK DEPARTURE.",
		},
		BallisticDuck = {
			"BALLISTIC DUCK.",
		},
		SpaceProgram = {
			"SPACE PROGRAM STARTED.",
		},
		StructuralOptimism = {
			"STRUCTURAL OPTIMISM DETECTED.",
		},
	},
}

ExperimentDefinitions.DontHitTheWall = DONT_HIT_THE_WALL

local TWO_TO_GO: ExperimentTypes.ExperimentDefinition = {
	Id = "two_to_go",
	Number = 7,
	Name = "TWO TO GO",
	Objective = "Lift the duck to the platform.",

	IntroTitle = "EXPERIMENT 007",
	IntroButton = "START BUILDING",
	SuccessTitle = "SUCCESS!",
	SuccessLine = "THE DUCK REACHED THE TOP.",
	RestartButton = "TRY AGAIN",

	DiscoveryTitle = "AND",
	DiscoveryBody = "An AND signal turns on only when all of its inputs are on.",

	Inventory = {
		{ ComponentType = "Block", Count = 6 },
		{ ComponentType = "Plank", Count = 3 },
		{ ComponentType = "Hook", Count = 2 },
		{ ComponentType = "Winch", Count = 1 },
		{ ComponentType = "PressureSensor", Count = 2 },
		{ ComponentType = "AND", Count = 2 },
		{ ComponentType = "SignalLamp", Count = 2 },
		{ ComponentType = "Switch", Count = 2 },
	},

	Payload = {
		Type = "Duck",
		BodySize = Vector3.new(2.4, 1.8, 3),
		Density = 0.35,
		Friction = 0.6,
		Elasticity = 0.05,
	},

	Geometry = {
		FloorSize = Vector3.new(120, 2, 120),
		FloorCenter = Vector3.new(0, -1, 0),
		PitFloorTopY = -4,

		StartPadSize = Vector3.new(32, 0.6, 22),
		StartPadCenter = Vector3.new(0, 0.3, -14),

		GoalPadSize = Vector3.new(18, 0.8, 16),
		GoalPadCenter = Vector3.new(0, 14.4, 14),

		DuckSpawn = Vector3.new(0, 1.5, -8),
		ButtonPosition = Vector3.new(0, 14.8, 14),

		BackWallSize = Vector3.new(120, 36, 2),
		BackWallCenter = Vector3.new(0, 18, -42),

		PlayerSpawn = Vector3.new(-16, 0.5, -16),

		BuildBoundsSize = Vector3.new(64, 40, 72),
		BuildBoundsCenter = Vector3.new(0, 16, 0),

		StagingRows = { -22, -19.5, -17, -14.5, -12, -9.5, -7, -4.5 },
		StagingSpacing = 1,
	},

	Thresholds = {
		PitY = 0,
		AwayDistance = 75,
		FastSpeed = 45,
		HighY = 48,
		CleanupY = -40,
		StructuralPartCount = 3,
		StructuralTiltDegrees = 65,
	},

	FailureMessages = {
		OneOutOfTwo = {
			"ONE OUT OF TWO.",
			"HALF THE PLAN IS WORKING.",
			"LOGIC: ALMOST.",
			"THE WINCH HAS CONDITIONS.",
		},
		DuckDown = {
			"DUCK DOWN.",
			"ROPE HAS OPINIONS.",
			"GRAVITY REMAINS EMPLOYED.",
		},
		DuckDeparture = {
			"LOAD TEST: INTERESTING.",
			"DUCK ELEVATOR: TEMPORARILY OUT OF SERVICE.",
		},
		BallisticDuck = {
			"THAT IS TECHNICALLY A CRANE.",
			"BALLISTIC DUCK.",
		},
		SpaceProgram = {
			"SPACE PROGRAM STARTED.",
		},
		StructuralOptimism = {
			"STRUCTURAL OPTIMISM DETECTED.",
		},
	},
}

ExperimentDefinitions.TwoToGo = TWO_TO_GO

local OPEN_SESAME: ExperimentTypes.ExperimentDefinition = {
	Id = "open_sesame",
	Number = 8,
	Name = "OPEN SESAME",
	Objective = "Get the duck through the gate.",

	IntroTitle = "EXPERIMENT 008",
	IntroButton = "START BUILDING",
	SuccessTitle = "SUCCESS!",
	SuccessLine = "THE GATE IS OPEN.",
	RestartButton = "TRY AGAIN",

	DiscoveryTitle = "POSITION",
	DiscoveryBody = "A servo moves to a target angle instead of spinning continuously.",

	Inventory = {
		{ ComponentType = "Plank", Count = 3 },
		{ ComponentType = "Block", Count = 4 },
		{ ComponentType = "Wheel", Count = 4 },
		{ ComponentType = "Motor", Count = 2 },
		{ ComponentType = "Servo", Count = 2 },
		{ ComponentType = "ProximitySensor", Count = 2 },
		{ ComponentType = "Switch", Count = 1 },
		{ ComponentType = "SignalLamp", Count = 1 },
		{ ComponentType = "NOT", Count = 1 },
	},

	Payload = {
		Type = "Duck",
		BodySize = Vector3.new(2.4, 1.8, 3),
		Density = 0.35,
		Friction = 0.6,
		Elasticity = 0.05,
	},

	Geometry = {
		FloorSize = Vector3.new(120, 2, 120),
		FloorCenter = Vector3.new(0, -1, 0),
		PitFloorTopY = -4,

		StartPadSize = Vector3.new(24, 0.6, 16),
		StartPadCenter = Vector3.new(0, 0.3, -20),

		GoalPadSize = Vector3.new(20, 0.6, 16),
		GoalPadCenter = Vector3.new(0, 0.3, 16),

		DuckSpawn = Vector3.new(0, 1.5, -20),
		ButtonPosition = Vector3.new(0, 0.6, 16),

		BackWallSize = Vector3.new(120, 30, 2),
		BackWallCenter = Vector3.new(0, 15, -42),

		PlayerSpawn = Vector3.new(-14, 0.5, -20),

		BuildBoundsSize = Vector3.new(64, 30, 72),
		BuildBoundsCenter = Vector3.new(0, 8, 0),

		StagingRows = { -28, -25.5, -23, -20.5, -18, -15.5, -13, -10.5, -8 },
		StagingSpacing = 1,
	},

	Thresholds = {
		PitY = 0,
		AwayDistance = 75,
		FastSpeed = 45,
		HighY = 32,
		CleanupY = -40,
		StructuralPartCount = 3,
		StructuralTiltDegrees = 60,
	},

	FailureMessages = {
		GateClosed = {
			"GATE: STILL VERY CLOSED.",
			"ACCESS DENIED.\nBY PHYSICS.",
		},
		AutomationThinking = {
			"AUTOMATION IS THINKING.",
			"DOOR OPENING:\nEVENTUALLY.",
		},
		DuckDown = {
			"DUCK DOWN.",
			"GRAVITY REMAINS EMPLOYED.",
		},
		DuckDeparture = {
			"UNSCHEDULED DUCK DEPARTURE.",
		},
		BallisticDuck = {
			"BALLISTIC DUCK.",
		},
		SpaceProgram = {
			"SPACE PROGRAM STARTED.",
		},
		StructuralOptimism = {
			"STRUCTURAL OPTIMISM DETECTED.",
		},
	},
}

ExperimentDefinitions.OpenSesame = OPEN_SESAME

local MAKE_ROOM: ExperimentTypes.ExperimentDefinition = {
	Id = "make_room",
	Number = 9,
	Name = "MAKE ROOM",
	Objective = "Get the duck past the obstacle.",

	IntroTitle = "EXPERIMENT 009",
	IntroButton = "START BUILDING",
	SuccessTitle = "SUCCESS!",
	SuccessLine = "THE WAY IS CLEAR.",
	RestartButton = "TRY AGAIN",

	DiscoveryTitle = "LINEAR MOTION",
	DiscoveryBody = "A piston turns control into straight-line movement.",

	Inventory = {
		{ ComponentType = "Plank", Count = 2 },
		{ ComponentType = "Block", Count = 4 },
		{ ComponentType = "Wheel", Count = 4 },
		{ ComponentType = "Motor", Count = 1 },
		{ ComponentType = "Piston", Count = 2 },
		{ ComponentType = "ProximitySensor", Count = 1 },
		{ ComponentType = "PressureSensor", Count = 2 },
		{ ComponentType = "Switch", Count = 2 },
		{ ComponentType = "Timer", Count = 1 },
		{ ComponentType = "SignalLamp", Count = 1 },
	},

	Payload = {
		Type = "Duck",
		BodySize = Vector3.new(2.4, 1.8, 3),
		Density = 0.35,
		Friction = 0.6,
		Elasticity = 0.05,
	},

	Geometry = {
		FloorSize = Vector3.new(120, 2, 120),
		FloorCenter = Vector3.new(0, -1, 0),
		PitFloorTopY = -4,

		StartPadSize = Vector3.new(24, 0.6, 16),
		StartPadCenter = Vector3.new(0, 0.3, -20),

		GoalPadSize = Vector3.new(20, 0.6, 16),
		GoalPadCenter = Vector3.new(0, 0.3, 16),

		DuckSpawn = Vector3.new(0, 1.5, -20),
		ButtonPosition = Vector3.new(0, 0.6, 16),

		BackWallSize = Vector3.new(120, 30, 2),
		BackWallCenter = Vector3.new(0, 15, -42),

		PlayerSpawn = Vector3.new(-14, 0.5, -20),

		BuildBoundsSize = Vector3.new(64, 30, 72),
		BuildBoundsCenter = Vector3.new(0, 8, 0),

		StagingRows = { -28, -25.5, -23, -20.5, -18, -15.5, -13, -10.5, -8, -5.5 },
		StagingSpacing = 1,
	},

	Thresholds = {
		PitY = 0,
		AwayDistance = 75,
		FastSpeed = 45,
		HighY = 32,
		CleanupY = -40,
		StructuralPartCount = 3,
		StructuralTiltDegrees = 60,
	},

	FailureMessages = {
		ObstacleUnmoved = {
			"OBSTACLE REMAINS OBSTACLY.",
			"THE BOX HAS DECLINED TO MOVE.",
		},
		BoxDeclined = {
			"THE BOX HAS DECLINED TO MOVE.",
			"OBSTACLE REMAINS OBSTACLY.",
		},
		PushHarder = {
			"PUSH HARDER.\nOR SMARTER.",
			"STRAIGHT-LINE PROGRESS.",
		},
		StraightLineProgress = {
			"STRAIGHT-LINE PROGRESS.",
			"PUSH HARDER.\nOR SMARTER.",
		},
		DuckDown = {
			"DUCK DOWN.",
			"GRAVITY REMAINS EMPLOYED.",
		},
		DuckDeparture = {
			"UNSCHEDULED DUCK DEPARTURE.",
		},
		BallisticDuck = {
			"BALLISTIC DUCK.",
		},
		SpaceProgram = {
			"SPACE PROGRAM STARTED.",
		},
		StructuralOptimism = {
			"STRUCTURAL OPTIMISM DETECTED.",
		},
	},
}

ExperimentDefinitions.MakeRoom = MAKE_ROOM

--[[
	Open Workshop: free build. It is deliberately NOT one of the numbered
	experiments:

		* Number is 0, so GetOrdered / GetNext and the "EXPERIMENT 00N" copy
		  never see it, and it cannot advance or renumber the session
		* it is still a normal entry in the catalogue, so server and client
		  resolve it by id exactly like every other definition
		* it has no goal button, so there is no success path: it can never
		  unlock anything or finish

	Everything else - the physics kernel, TEST, RESET, the failure flavour -
	is the ordinary one. Open Workshop reuses the same physics kernel as
	experiments; it is not a separate sandbox engine.
]]
local OPEN_WORKSHOP: ExperimentTypes.ExperimentDefinition = {
	Id = "open_workshop",
	Number = 0,
	Name = "OPEN WORKSHOP",
	Objective = "Build anything.",

	IntroTitle = "FREE BUILD",
	IntroButton = "START BUILDING",
	SuccessTitle = "SUCCESS!",
	SuccessLine = "THE DUCK MADE IT.",
	RestartButton = "CLEAR WORKSHOP",

	DiscoveryTitle = "NO RULES",
	DiscoveryBody = "Nothing here can win or lose. It just runs.",

	-- Every component type, mechanical and automation.
	Inventory = {
		{ ComponentType = "Plank", Count = 4 },
		{ ComponentType = "Block", Count = 4 },
		{ ComponentType = "Wheel", Count = 6 },
		{ ComponentType = "Motor", Count = 3 },
		{ ComponentType = "Spring", Count = 3 },
		{ ComponentType = "Fan", Count = 3 },
		{ ComponentType = "Hook", Count = 3 },
		{ ComponentType = "Winch", Count = 2 },
		{ ComponentType = "Switch", Count = 4 },
		{ ComponentType = "PressureSensor", Count = 4 },
		{ ComponentType = "ProximitySensor", Count = 4 },
		{ ComponentType = "Timer", Count = 4 },
		{ ComponentType = "AND", Count = 4 },
		{ ComponentType = "OR", Count = 4 },
		{ ComponentType = "NOT", Count = 4 },
		{ ComponentType = "SignalLamp", Count = 6 },
	},

	Payload = {
		Type = "Duck",
		BodySize = Vector3.new(2.4, 1.8, 3),
		Density = 0.35,
		Friction = 0.6,
		Elasticity = 0.05,
	},

	Geometry = {
		-- A flat floor. No trench, no gap, nothing to fall into: the point of
		-- free build is that the ground behaves the same everywhere.
		FloorSize = Vector3.new(120, 2, 120),
		FloorCenter = Vector3.new(0, -1, 0),
		PitFloorTopY = -4,

		-- Wide wooden build pad accommodating mechanical and automation rows.
		StartPadSize = Vector3.new(56, 0.6, 52),
		StartPadCenter = Vector3.new(0, 0.3, -6),

		GoalPadSize = Vector3.new(18, 0.6, 16),
		GoalPadCenter = Vector3.new(0, 0.3, 14),

		DuckSpawn = Vector3.new(0, 1.5, -29),
		ButtonPosition = Vector3.new(0, 0.6, 14),

		BackWallSize = Vector3.new(120, 30, 2),
		BackWallCenter = Vector3.new(0, 15, -42),

		PlayerSpawn = Vector3.new(-14, 0.5, -20),

		BuildBoundsSize = Vector3.new(64, 34, 64),
		BuildBoundsCenter = Vector3.new(0, 10, -4),

		-- One row per component type, back of the pad first.
		StagingRows = { -28, -25, -22, -19, -16, -13, -10, -7, -4, -1, 2, 5, 8, 11, 14, 17 },
		StagingSpacing = 1,
	},

	Thresholds = {
		-- No pit, so anything this low fell off the world entirely.
		PitY = -10,
		AwayDistance = 70,
		FastSpeed = 45,
		HighY = 32,
		CleanupY = -40,
		StructuralPartCount = 3,
		StructuralTiltDegrees = 60,
	},

	FailureMessages = {
		DuckDown = {
			"DUCK DOWN.",
			"GRAVITY REMAINS EMPLOYED.",
		},
		DuckDeparture = {
			"UNSCHEDULED DUCK DEPARTURE.",
		},
		BallisticDuck = {
			"BALLISTIC DUCK.",
		},
		SpaceProgram = {
			"SPACE PROGRAM STARTED.",
		},
		StructuralOptimism = {
			"STRUCTURAL OPTIMISM DETECTED.",
			"CONFIDENCE: HIGH\nSTRUCTURAL INTEGRITY: LESS HIGH.",
		},
	},
}

ExperimentDefinitions.OpenWorkshop = OPEN_WORKSHOP

local orderedList: { ExperimentTypes.ExperimentDefinition } = {
	SAVE_THE_DUCK,
	UPHILL_DELIVERY,
	OVER_THE_WALL,
	WINDY_BUSINESS,
	LIFT_OFF,
	DONT_HIT_THE_WALL,
	TWO_TO_GO,
	OPEN_SESAME,
	MAKE_ROOM,
}

local byId: { [string]: ExperimentTypes.ExperimentDefinition } = {
	[SAVE_THE_DUCK.Id] = SAVE_THE_DUCK,
	[UPHILL_DELIVERY.Id] = UPHILL_DELIVERY,
	[OVER_THE_WALL.Id] = OVER_THE_WALL,
	[WINDY_BUSINESS.Id] = WINDY_BUSINESS,
	[LIFT_OFF.Id] = LIFT_OFF,
	[DONT_HIT_THE_WALL.Id] = DONT_HIT_THE_WALL,
	[TWO_TO_GO.Id] = TWO_TO_GO,
	[OPEN_SESAME.Id] = OPEN_SESAME,
	[MAKE_ROOM.Id] = MAKE_ROOM,
	-- In the catalogue so both sides can resolve the id, but never in
	-- orderedList, so it stays outside the numbered sequence.
	[OPEN_WORKSHOP.Id] = OPEN_WORKSHOP,
}

function ExperimentDefinitions.Get(id: string): ExperimentTypes.ExperimentDefinition?
	return byId[id]
end

function ExperimentDefinitions.GetFirst(): ExperimentTypes.ExperimentDefinition
	return orderedList[1]
end

function ExperimentDefinitions.GetNext(id: string): ExperimentTypes.ExperimentDefinition?
	for index, def in orderedList do
		if def.Id == id then
			return orderedList[index + 1]
		end
	end

	return nil
end

function ExperimentDefinitions.GetOrdered(): { ExperimentTypes.ExperimentDefinition }
	return orderedList
end

function ExperimentDefinitions.GetOpenWorkshop(): ExperimentTypes.ExperimentDefinition
	return OPEN_WORKSHOP
end

function ExperimentDefinitions.IsOpenWorkshopId(id: string?): boolean
	return id ~= nil and id == OPEN_WORKSHOP.Id
end

--[[
	Open Workshop unlocks after Experiment 005 is finished (unlockedIndex >= 6).
	Completing Experiment 005 unlocks both Open Workshop and Experiment 006.
]]
function ExperimentDefinitions.IsOpenWorkshopUnlocked(unlockedIndex: number): boolean
	return unlockedIndex >= 6
end

--[[
	The first experiment that puts a component on the rack.

	Derived from the inventories rather than a hand-written table, so a new
	experiment that introduces a part moves the component wall by itself.
	Nil means no experiment stages it (nothing today).
]]
function ExperimentDefinitions.GetComponentIntroducedAt(componentType: string): number?
	local found: number? = nil

	for _, def in orderedList do
		for _, requirement in def.Inventory do
			if requirement.ComponentType == componentType then
				if found == nil or def.Number < found then
					found = def.Number
				end
			end
		end
	end

	return found
end

-- The experiment this build loads by default.
-- In Studio, DevExperimentId can override this to jump directly to a level.
function ExperimentDefinitions.GetDefault(): ExperimentTypes.ExperimentDefinition
	if RunService:IsStudio() and ConstructionConfig.DevExperimentId ~= nil then
		local override = byId[ConstructionConfig.DevExperimentId]
		if override ~= nil then
			return override
		end
	end

	return ExperimentDefinitions.GetFirst()
end

-- Deterministic flavour rotation: a child sees variety, a playtest sees the
-- same message for the same attempt number.
function ExperimentDefinitions.FailureMessage(
	definition: ExperimentTypes.ExperimentDefinition,
	eventId: ExperimentTypes.FailureEventId,
	attempt: number
): string
	local messages = definition.FailureMessages[eventId]
	if messages == nil or #messages == 0 then
		return ""
	end

	local index = ((attempt - 1) % #messages) + 1
	if index < 1 then
		index = 1
	end

	return messages[index]
end

for _, def in byId do
	table.freeze(def)
end

table.freeze(byId)
table.freeze(orderedList)

return table.freeze(ExperimentDefinitions)
