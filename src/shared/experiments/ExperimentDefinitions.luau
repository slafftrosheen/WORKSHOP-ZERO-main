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

local orderedList: { ExperimentTypes.ExperimentDefinition } = {
	SAVE_THE_DUCK,
	UPHILL_DELIVERY,
	OVER_THE_WALL,
	WINDY_BUSINESS,
	LIFT_OFF,
}

local byId: { [string]: ExperimentTypes.ExperimentDefinition } = {
	[SAVE_THE_DUCK.Id] = SAVE_THE_DUCK,
	[UPHILL_DELIVERY.Id] = UPHILL_DELIVERY,
	[OVER_THE_WALL.Id] = OVER_THE_WALL,
	[WINDY_BUSINESS.Id] = WINDY_BUSINESS,
	[LIFT_OFF.Id] = LIFT_OFF,
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
