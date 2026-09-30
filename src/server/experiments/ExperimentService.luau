--!strict

--[[
	ExperimentService

	Orchestrates one experiment around the construction kernel, without owning
	any physics state of its own:

		Loading   the level is being built, the player can do nothing
		Build     parts on the rack, machine being made
		Testing   SimulationService is running the machine
		Success   the duck finished the job; physics keeps running so the
		          player can watch what their machine actually did

	SimulationState (Build / Testing / Resetting) stays the only truth about
	physics. This service observes it instead of duplicating it:

		* an attempt starts when the simulation enters Testing
		* an attempt ends when the simulation returns to Build, or at success
		* the success freeze is an ExperimentState, never a SimulationState

	The experiment module reports events (Success, Toast) and never sets
	experiment state, so exactly one module decides what "the experiment
	succeeded" means and how many times it can happen.

	Requests from clients funnel through here so that a straggling reset cannot
	unfreeze a finished attempt:

		RequestSimulationAction  Test | Reset   -> SimulationService (or ignored)
		RequestExperimentAction  Restart        -> a full experiment restart
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)
local ConstructionMath = require(Shared.construction.ConstructionMath)

local BuildService = require(script.Parent.Parent.construction.BuildService)
local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local ConnectorService = require(script.Parent.Parent.construction.ConnectorService)
local ActuatorService = require(script.Parent.Parent.construction.ActuatorService)
local BehaviourService = require(script.Parent.Parent.construction.BehaviourService)
local SimulationService = require(script.Parent.Parent.construction.SimulationService)
local ExperimentRegistry = require(script.Parent.ExperimentRegistry)
local WorkshopService = require(script.Parent.Parent.world.WorkshopService)

local Config = ConstructionConfig

local ExperimentService = {}

-- Per-attempt measurements for the Studio playtest log. Deliberately a plain
-- record: it is printed and thrown away, never stored.
type Diagnostics = {
	StartedAt: number,
	MaxSpeed: number,
	MaxHeight: number,
}

local state: ExperimentTypes.ExperimentState = "Loading"
local remotes: ExperimentTypes.ExperimentRemotes? = nil
local definition: ExperimentTypes.ExperimentDefinition = ExperimentDefinitions.GetDefault()
local loaded: ExperimentTypes.LoadedExperiment? = nil
local experiment: ExperimentTypes.ExperimentModule? = nil
local attempt = 0
local partsUsed = 0
local unlockedIndex = 1
local diagnostics: Diagnostics? = nil
local sampler: RBXScriptConnection? = nil

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ] %s", message))
	end
end

local function publishState()
	if remotes ~= nil then
		remotes.ExperimentState.Value = state
		remotes.CurrentExperimentId.Value = definition.Id
	end
end

local function publishCounters()
	if remotes == nil then
		return
	end

	remotes.ExperimentAttempt.Value = attempt
	remotes.ExperimentPartsUsed.Value = partsUsed
end

local function setState(newState: ExperimentTypes.ExperimentState)
	if state == newState then
		return
	end

	local previous = state
	state = newState
	publishState()
	log(string.format("Experiment %s -> %s", previous, newState))
end

--[[
	How many components the player actually used.

	The rule is intentionally simple enough to explain to a child: a part counts
	once it has left its staging spot, or once it is joined to anything. No
	machine graph analysis, no scoring.
]]
local function countPartsUsed(): number
	local active = loaded
	if active == nil then
		return 0
	end

	local joined: { [string]: boolean } = {}
	for _, record in ConnectorService.GetAll() do
		joined[record.ComponentA] = true
		joined[record.ComponentB] = true
	end

	local count = 0
	for _, staged in active.Staged do
		local used = joined[staged.ComponentId] == true

		if not used and staged.Model.Parent ~= nil then
			local moved = staged.Model:GetPivot().Position - staged.SpawnPivot.Position
			used = moved.Magnitude > Config.PartsUsedMovedDistance
		end

		if used then
			count += 1
		end
	end

	return count
end

-- Playtest diagnostics -------------------------------------------------------

local function stopSampler()
	if sampler ~= nil then
		sampler:Disconnect()
		sampler = nil
	end
end

local function startSampler()
	stopSampler()

	-- LoadedExperiment has no Handles field.  Find the duck payload by scanning
	-- the workshop folder, the same way the client's debug overlay does.
	local active = loaded
	if active == nil then
		return
	end

	local duckRoot: BasePart? = nil
	for _, descendant in active.Workshop:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and descendant:GetAttribute(Config.AttributePayload) == true
		then
			duckRoot = descendant
			break
		end
	end

	if duckRoot == nil then
		log("startSampler: duck not found in Workshop - diagnostics unavailable")
		return
	end

	local root: BasePart = duckRoot

	diagnostics = {
		StartedAt = os.clock(),
		MaxSpeed = 0,
		MaxHeight = root.Position.Y,
	}

	sampler = RunService.Heartbeat:Connect(function()
		local record = diagnostics
		if record == nil or root.Parent == nil then
			return
		end

		local speed = root.AssemblyLinearVelocity.Magnitude
		if speed > record.MaxSpeed then
			record.MaxSpeed = speed
		end

		local height = root.Position.Y
		if height > record.MaxHeight then
			record.MaxHeight = height
		end
	end)
end

--[[
	Prints one attempt to Studio Output. This is how a human watches their
	children solve the challenge: no remote analytics, no file writing, and
	never anything a player can see.
]]
local function printAttempt(result: string)
	local record = diagnostics
	diagnostics = nil
	stopSampler()

	if record == nil or not Config.PlaytestDiagnostics or not RunService:IsStudio() then
		return
	end

	local duration = os.clock() - record.StartedAt
	local durationLabel = if result == "Success" then "Duration" else "Duration before Reset"

	print(
		string.format(
			"[WZ] Attempt %d\n    %s: %.1fs\n    Connections: %d\n    Parts moved: %d\n    Duck max speed: %.1f\n    Duck max height: %.1f\n    Result: %s",
			attempt,
			durationLabel,
			duration,
			ConnectorService.GetCount(),
			partsUsed,
			record.MaxSpeed,
			record.MaxHeight,
			result
		)
	)
end

-- Attempt lifecycle ----------------------------------------------------------

local function onTestStarted()
	if state ~= "Build" then
		-- A test can only start from Build, and the simulation agrees, so this
		-- only happens if the two ever drift apart.
		warn(string.format("[WZ] Ignoring a test while the experiment is %s", state))
		return
	end

	attempt += 1
	partsUsed = countPartsUsed()
	publishCounters()
	startSampler()
	setState("Testing")

	if experiment ~= nil then
		experiment.StartAttempt(attempt)
	end

	log(string.format("Attempt %d started: %d part(s) used", attempt, partsUsed))
end

--[[
	Testing -> Build through the kernel's own reset.

	The machine stays exactly as the player built it: nothing here returns a
	part to the rack, because "change one thing and test again" is the whole
	point of the game.
]]
local function onTestFinished()
	printAttempt("Reset")
	setState("Build")

	if experiment ~= nil then
		experiment.RestoreToBuild()
	end
end

-- Success ---------------------------------------------------------------------

--[[
	Called by the experiment when the duck activates the goal.

	Guarded twice on purpose: the experiment already refuses to report the same
	attempt twice, and this refuses to mark success from anywhere but Testing.
	SimulationState stays "Testing" so physics keeps running and the player can
	watch what their machine did.
]]
function ExperimentService.MarkSuccess()
	if state ~= "Testing" then
		return false
	end

	printAttempt("Success")
	unlockedIndex = math.max(unlockedIndex, definition.Number + 1)
	if remotes ~= nil then
		remotes.UnlockedExperimentIndex.Value = unlockedIndex
	end
	setState("Success")
	log(string.format("The duck reached the goal after %d attempt(s)", attempt))

	return true
end

function ExperimentService.BroadcastToast(message: string)
	if remotes ~= nil and message ~= "" then
		remotes.FailureToast:FireAllClients(message)
	end
end

-- Requests ---------------------------------------------------------------------

--[[
	Operation funnel for the simulation remote.

	RESET means "stop physics and put my machine back the way I built it", so it
	is ignored while the experiment is frozen in Success: the only way out of a
	finished experiment is a restart.
]]
function ExperimentService.HandleSimulationRequest(player: Player, payload: unknown): boolean
	local action = ConstructionTypes.ToSimulationAction(payload)
	if action == "Reset" and state == "Success" then
		log(string.format("%s tried to reset a finished experiment", player.Name))
		return false
	end

	return SimulationService.RequestAction(player, payload)
end

--[[
	The full restart behind TRY AGAIN.

	This is not RESET: every joint is removed, every part goes back to its
	staging spot, the payload and the goal button are put back, and the attempt
	counter returns to zero.
]]
function ExperimentService.RestartExperiment(player: Player): boolean
	if state ~= "Build" and state ~= "Success" then
		return false
	end

	local active = loaded
	local experimentModule = experiment
	if active == nil or experimentModule == nil then
		return false
	end

	setState("Loading")
	printAttempt("Restart")

	-- Success keeps Roblox physics running, so the simulation has to be handed
	-- back to Build before the machine can be dismantled.
	if SimulationService.GetState() == "Testing" then
		SimulationService.ResetToBuild(player)
	end

	ConnectorService.DisconnectAll()
	ActuatorService.Clear()
	BehaviourService.Clear()

	for _, staged in active.Staged do
		if staged.Model.Parent ~= nil then
			staged.Model:PivotTo(staged.SpawnPivot)
		end
	end

	experimentModule.Restart()

	attempt = 0
	partsUsed = 0
	publishCounters()

	-- The parts are somewhere new now; without this the build service would
	-- still remember the pre-restart transforms as "last valid".
	BuildService.ResetPlacementMemory()
	setState("Build")

	log(string.format("%s restarted the experiment", player.Name))

	return true
end

function ExperimentService.SelectExperiment(player: Player, targetId: string): boolean
	local targetDef = ExperimentDefinitions.Get(targetId)
	if targetDef == nil then
		warn(string.format("[WZ] Experiment '%s' does not exist", targetId))
		return false
	end

	if not ConstructionMath.IsExperimentUnlocked(targetDef.Number, unlockedIndex) then
		warn(
			string.format(
				"[WZ] Player %s requested locked experiment '%s' (#%d, max unlocked #%d)",
				player.Name,
				targetId,
				targetDef.Number,
				unlockedIndex
			)
		)
		return false
	end

	if state ~= "Build" and state ~= "Success" then
		warn(string.format("[WZ] Cannot switch experiment while in %s state", state))
		return false
	end

	return ExperimentService.LoadExperiment(targetId, player)
end

function ExperimentService.HandleExperimentRequest(player: Player, payload: unknown): boolean
	local req = ExperimentTypes.ToExperimentActionRequest(payload)
	if req == nil then
		return false
	end

	if req.Action == "Restart" then
		return ExperimentService.RestartExperiment(player)
	elseif req.Action == "Next" then
		return ExperimentService.NextExperiment(player)
	elseif req.Action == "Select" and req.ExperimentId ~= nil then
		return ExperimentService.SelectExperiment(player, req.ExperimentId)
	end

	return false
end

-- Loading ----------------------------------------------------------------------

function ExperimentService.SetRemotes(remoteSet: ExperimentTypes.ExperimentRemotes)
	remotes = remoteSet
	remotes.UnlockedExperimentIndex.Value = unlockedIndex
	publishState()
	publishCounters()
end

function ExperimentService.GetState(): ExperimentTypes.ExperimentState
	return state
end

--[[
	Transitions between experiments or loads an initial experiment by ID.
	Handles clean teardown of previous workshop, connectors, and actuators.
]]
function ExperimentService.LoadExperiment(targetId: string, player: Player?): boolean
	local targetModule = ExperimentRegistry.Get(targetId)
	if targetModule == nil then
		warn(string.format("[WZ] Experiment '%s' not found in registry", targetId))
		return false
	end

	setState("Loading")
	printAttempt("Unload")

	if SimulationService.GetState() == "Testing" then
		SimulationService.ResetToBuild(player)
	end

	stopSampler()
	ConnectorService.DisconnectAll()
	ActuatorService.Clear()
	BehaviourService.Clear()
	ComponentFactory.Clear()

	if experiment ~= nil then
		experiment.Unload()
		experiment = nil
	end

	WorkshopService.ClearExperimentBay()
	loaded = nil

	BuildService.ResetPlacementMemory()

	local report: ExperimentTypes.ExperimentReport = {
		Success = function()
			ExperimentService.MarkSuccess()
		end,
		Toast = function(message: string)
			ExperimentService.BroadcastToast(message)
		end,
	}

	local built = targetModule.Load(report)
	if built == nil then
		warn(string.format("[WZ] The experiment '%s' did not load; workshop is empty", targetId))
		return false
	end

	loaded = built
	experiment = targetModule
	definition = built.Definition

	BuildService.AttachWorkshop(built.Workshop)

	attempt = 0
	partsUsed = 0
	publishCounters()
	setState("Build")

	log(string.format("%s is ready (%s)", definition.Name, definition.Objective))
	return true
end

--[[
	Advances the session to the next experiment in sequence, if available.
]]
function ExperimentService.NextExperiment(player: Player): boolean
	local nextDef = ExperimentDefinitions.GetNext(definition.Id)
	if nextDef == nil then
		log(string.format("No next experiment after %s", definition.Id))
		return false
	end

	log(string.format("%s advancing to next experiment: %s", player.Name, nextDef.Id))
	return ExperimentService.LoadExperiment(nextDef.Id, player)
end

--[[
	Builds the level, wires the experiment, and starts observing the simulation.

	Called once, by the server bootstrap. The construction kernel is already
	wired at this point; this only adds the challenge on top of it.
]]
function ExperimentService.Start()
	SimulationService.SetObserver({
		OnStateChanged = function(previous, current)
			if previous == "Build" and current == "Testing" then
				onTestStarted()
			elseif previous == "Testing" and current == "Build" then
				onTestFinished()
			end
		end,
	})

	WorkshopService.GetOrCreateWorkshop()
	local defaultDef = ExperimentDefinitions.GetDefault()
	local success = ExperimentService.LoadExperiment(defaultDef.Id)
	if not success then
		warn(string.format("[WZ] Failed to load default experiment '%s'", defaultDef.Id))
	end
end

return table.freeze(ExperimentService)
