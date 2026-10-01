--!strict

--[[
	ExperimentTypes

	The vocabulary of the experiment layer.

	An *experiment* is a challenge: a goal, a set of parts, and a payload.
	A *simulation phase* (Build / Testing / Resetting) is how the workshop
	behaves while the player works on it. They are different things on purpose:

		SimulationState  physics truth, owned by SimulationService (WZ-001)
		ExperimentState  challenge lifecycle, owned by ExperimentService

	Only one service changes each of them, and the experiment layer never
	simulates physics itself. It observes the simulation and reacts.
]]

local ConstructionTypes = require(script.Parent.Parent.construction.ConstructionTypes)

export type ExperimentState = "Loading" | "Build" | "Testing" | "Success"

export type ExperimentAction = "Restart" | "Next" | "Select"

export type ExperimentActionRequest = {
	Action: ExperimentAction,
	ExperimentId: string?,
}

export type PartRequirement = {
	ComponentType: ConstructionTypes.ComponentType,
	Count: number,
}

-- The thing the player has to move. The duck is a payload, never a
-- construction component: it cannot be dragged, rotated or disconnected.
export type PayloadSpec = {
	Type: string,
	BodySize: Vector3,
	Density: number,
	Friction: number,
	Elasticity: number,
}

export type FailureEventId =
	"DuckDown"
	| "DuckDeparture"
	| "BallisticDuck"
	| "SpaceProgram"
	| "StructuralOptimism"
	| "LowTravel"
	| "BackwardMovement"
	| "Rollback"
	| "VehicleFlip"
	| "HighRpm"
	| "WallImpact"
	| "DuckTrajectory"
	| "VerticalProgress"
	| "NonTouchViolation"

export type FailureThresholds = {
	-- Below this height the duck is in the pit.
	PitY: number,
	-- Horizontal distance from the experiment centre that counts as "gone".
	AwayDistance: number,
	-- Speed in studs per second that counts as ballistic.
	FastSpeed: number,
	-- Height above the level that counts as leaving the atmosphere.
	HighY: number,
	-- Below this the duck is frozen so physics cannot run away forever.
	CleanupY: number,
	-- How many parts must tip over, and by how many degrees, to call a
	-- structure toppled. Joints never break in this kernel, so "fell apart"
	-- can only honestly mean "the machine went over".
	StructuralPartCount: number,
	StructuralTiltDegrees: number,
}

export type LevelGeometry = {
	FloorSize: Vector3,
	FloorCenter: Vector3,
	-- The trench between the two pads is cut down to this height.
	PitFloorTopY: number,
	StartPadSize: Vector3,
	StartPadCenter: Vector3,
	GoalPadSize: Vector3,
	GoalPadCenter: Vector3,
	DuckSpawn: Vector3,
	ButtonPosition: Vector3,
	BackWallSize: Vector3,
	BackWallCenter: Vector3,
	PlayerSpawn: Vector3,
	BuildBoundsSize: Vector3,
	BuildBoundsCenter: Vector3,
	-- Staging rows, back of the start pad first.
	StagingRows: { number },
	StagingSpacing: number,
}

export type ExperimentDefinition = {
	Id: string,
	Number: number,
	Name: string,
	Objective: string,
	IntroTitle: string,
	IntroButton: string,
	SuccessTitle: string,
	SuccessLine: string,
	RestartButton: string,
	Inventory: { PartRequirement },
	Payload: PayloadSpec,
	Geometry: LevelGeometry,
	Thresholds: FailureThresholds,
	FailureMessages: { [FailureEventId]: { string } },
}

-- One staged part in the world, remembered so a full restart can put it back.
export type StagedComponent = {
	Model: Model,
	ComponentId: string,
	SpawnPivot: CFrame,
}

-- One test attempt, for the Studio playtest diagnostics.
export type AttemptRecord = {
	Attempt: number,
	Duration: number,
	Connections: number,
	PartsMoved: number,
	DuckMaxSpeed: number,
	DuckMaxHeight: number,
	Result: string,
}

-- What an experiment module gives back once its level exists.
export type LoadedExperiment = {
	Definition: ExperimentDefinition,
	Workshop: Instance,
	Staged: { StagedComponent },
}

-- How an experiment talks back to ExperimentService: it never sets experiment
-- state itself, it reports that something happened.
export type ExperimentReport = {
	Success: () -> (),
	Toast: (message: string) -> (),
}

-- The shape ExperimentService drives. One experiment exists today; a second
-- one only needs to satisfy this and be registered by id.
export type ExperimentModule = {
	Load: (report: ExperimentReport) -> LoadedExperiment?,
	StartAttempt: (attempt: number) -> (),
	RestoreToBuild: () -> (),
	Restart: () -> (),
	Unload: () -> (),
}

-- What the level builder hands back to the experiment.
export type LevelHandles = {
	Workshop: Instance,
	Duck: Model,
	DuckSpawn: CFrame,
	Goal: Model,
	GoalTrigger: BasePart,
	GoalCap: BasePart,
	-- Middle of the playfield, used to decide when the duck has left it.
	Center: Vector3,
}

-- The client-facing surface for the experiment layer. Superset of the
-- construction remotes, built once by the server in Bootstrap.
export type ExperimentRemotes = {
	RequestSimulationAction: RemoteEvent,
	RequestRotation: RemoteEvent,
	RequestDisconnect: RemoteEvent,
	RequestReturnToRack: RemoteEvent,
	DragStateChanged: RemoteEvent,
	SimulationState: StringValue,
	RequestExperimentAction: RemoteEvent,
	FailureToast: RemoteEvent,
	OpenExperimentBoard: RemoteEvent,
	ExperimentState: StringValue,
	CurrentExperimentId: StringValue,
	ExperimentAttempt: IntValue,
	ExperimentPartsUsed: IntValue,
	UnlockedExperimentIndex: IntValue,
}

local ExperimentTypes = {}

function ExperimentTypes.ToExperimentState(value: unknown): ExperimentState?
	if type(value) ~= "string" then
		return nil
	end

	if value == "Loading" or value == "Build" or value == "Testing" or value == "Success" then
		return value
	end

	return nil
end

function ExperimentTypes.ToExperimentActionRequest(value: unknown): ExperimentActionRequest?
	if type(value) == "string" then
		if value == "Restart" or value == "Next" then
			return { Action = value }
		end
		return nil
	end

	if type(value) == "table" then
		local tbl = value :: { [string]: unknown }
		local action = tbl.Action
		if action == "Restart" or action == "Next" then
			return { Action = action }
		elseif action == "Select" and type(tbl.ExperimentId) == "string" then
			return { Action = "Select", ExperimentId = tbl.ExperimentId }
		end
	end

	return nil
end

function ExperimentTypes.ToExperimentAction(value: unknown): ExperimentAction?
	local req = ExperimentTypes.ToExperimentActionRequest(value)
	if req ~= nil then
		return req.Action
	end

	return nil
end

return table.freeze(ExperimentTypes)
