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

ExperimentDefinitions.SaveTheDuck = SAVE_THE_DUCK

local byId: { [string]: ExperimentTypes.ExperimentDefinition } = {
	[SAVE_THE_DUCK.Id] = SAVE_THE_DUCK,
}

function ExperimentDefinitions.Get(id: string): ExperimentTypes.ExperimentDefinition?
	return byId[id]
end

-- The experiment this build loads. One experiment exists; when a second one
-- arrives it gets added to byId and the bootstrap picks it explicitly.
function ExperimentDefinitions.GetDefault(): ExperimentTypes.ExperimentDefinition
	return SAVE_THE_DUCK
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

for _, definition in byId do
	table.freeze(definition)
end

table.freeze(byId)

return table.freeze(ExperimentDefinitions)
