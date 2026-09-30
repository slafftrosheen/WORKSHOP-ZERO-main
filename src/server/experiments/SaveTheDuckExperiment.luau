--!strict

--[[
	SaveTheDuckExperiment

	Experiment 001, from the duck's point of view:

		* the duck is a physics payload, never a construction component
		* the goal is an invisible trigger over a comically large red button,
		  and only the duck can activate it
		* the FailureObserver watches for funny outcomes and reports flavour
		  text; it never decides that an attempt is over - the player does,
		  by pressing RESET

	Every decision that matters (is this success? how many attempts? what does
	the player see?) belongs to ExperimentService. This module only knows about
	the duck, the button and the silly things that happen between them.

	Detection rules worth remembering:

		* success is validated by payload identity - an ancestor model carrying
		  the payload attribute and being *this* duck - never by a name string,
		  so a plank dropped on the button cannot win
		* each failure flavour fires at most once per attempt
		* a duck that leaves the world entirely is anchored instead of deleted,
		  so the player can still inspect the disaster and then reset
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local ConnectorService = require(script.Parent.Parent.construction.ConnectorService)
local SaveTheDuckLevel = require(script.Parent.SaveTheDuckLevel)
local AssetProvider = require(script.Parent.Parent.assets.AssetProvider)

local Config = ConstructionConfig

local SaveTheDuckExperiment = {}

-- The sound a toy button would make. A Roblox built-in asset, no dependency on
-- an uploaded sound, and nothing in the experiment waits for it to load.
local BUTTON_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local definition: ExperimentTypes.ExperimentDefinition = ExperimentDefinitions.GetDefault()
local handles: ExperimentTypes.LevelHandles? = nil
local report: ExperimentTypes.ExperimentReport? = nil
local capRestPosition: Vector3 = Vector3.zero
local capRestColor: Color3 = Color3.new()

-- An attempt is "live" between TEST and RESET, which is exactly the window in
-- which the duck can do anything funny.
local live = false
local succeeded = false
local currentAttempt = 1
local sampler: RBXScriptConnection? = nil
local fired: { [ExperimentTypes.FailureEventId]: boolean } = {}

-- Captured at the start of an attempt: enough to tell "the machine went over"
-- from "a wheel is spinning freely on its axle".
local builtUp: { [string]: Vector3 } = {}
local rigidParts: { [string]: boolean } = {}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ] %s", message))
	end
end

-- Payload helpers ---------------------------------------------------------------

local function payloadParts(duck: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in duck:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function setPayloadAnchored(anchored: boolean)
	local level = handles
	if level == nil then
		return
	end

	for _, part in payloadParts(level.Duck) do
		part.Anchored = anchored
	end
end

local function zeroPayloadVelocity()
	local level = handles
	if level == nil then
		return
	end

	for _, part in payloadParts(level.Duck) do
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end
end

-- Returns the duck to its exact starting transform, at rest, anchored.
local function restoreDuck()
	local level = handles
	if level == nil then
		return
	end

	zeroPayloadVelocity()
	setPayloadAnchored(true)
	level.Duck:PivotTo(level.DuckSpawn)
	zeroPayloadVelocity()
end

--[[
	Walks up from whatever touched the goal looking for a payload.

	This is identity validation, not name validation: the attribute is set by
	the level builder on the payload itself, so a player, a plank or a wheel can
	never claim to be the duck.
]]
local function findPayload(instance: Instance?): Model?
	local current: Instance? = instance
	while current ~= nil do
		if current:IsA("Model") and current:GetAttribute(Config.AttributePayload) == true then
			return current
		end

		current = current.Parent
	end

	return nil
end

-- The button -------------------------------------------------------------------

local function pressButton()
	local level = handles
	if level == nil then
		return
	end

	level.GoalCap.Position = capRestPosition - Vector3.new(0, 0.4, 0)
	level.GoalCap.Color = capRestColor:Lerp(Color3.new(1, 1, 1), 0.35)

	local sound = level.GoalCap:FindFirstChildOfClass("Sound")
	if sound ~= nil then
		sound:Play()
	end

	task.delay(0.45, function()
		-- The level may already have been restarted; the cap is a fresh part in
		-- that case and this write is simply harmless.
		level.GoalCap.Position = capRestPosition
		level.GoalCap.Color = capRestColor
	end)
end

local function onGoalTouched(other: BasePart)
	local level = handles
	if level == nil or not live or succeeded then
		return
	end

	if findPayload(other) ~= level.Duck then
		return
	end

	-- One success per attempt, no matter how many times Roblox reports contact.
	succeeded = true
	pressButton()

	if report ~= nil then
		report.Success()
	end
end

-- Failure flavour --------------------------------------------------------------

local function notify(eventId: ExperimentTypes.FailureEventId)
	if fired[eventId] == true then
		return
	end

	fired[eventId] = true

	local message = ExperimentDefinitions.FailureMessage(definition, eventId, currentAttempt)
	if report ~= nil then
		report.Toast(message)
	end

	log(string.format("Flavour event %s: %s", eventId, message))
end

local function checkDuck()
	local level = handles
	if level == nil then
		return
	end

	local root = level.Duck.PrimaryPart
	if root == nil then
		return
	end

	local thresholds = definition.Thresholds
	local position = root.Position

	if position.Y < thresholds.CleanupY then
		-- Very deep, very boring: freeze it so physics cannot keep integrating a
		-- fallen object forever. This is still not a reset.
		setPayloadAnchored(true)
		zeroPayloadVelocity()
		live = false
		log("The duck left the workshop entirely and was frozen where it stopped")

		return
	end

	local speed = root.AssemblyLinearVelocity.Magnitude
	if speed > thresholds.FastSpeed then
		notify("BallisticDuck")
	end

	if position.Y > thresholds.HighY then
		notify("SpaceProgram")
	end

	local offset = Vector3.new(position.X - level.Center.X, 0, position.Z - level.Center.Z)
	if offset.Magnitude > thresholds.AwayDistance then
		notify("DuckDeparture")
	end

	if position.Y < thresholds.PitY then
		notify("DuckDown")
	end
end

--[[
	"Fell apart" can only honestly mean "the machine went over": joints in this
	kernel never break, so the honest signal is rotation.

	Only components held by at least one rigid joint are counted. A wheel on an
	axle spins freely by design, so counting wheels would call a cart rolling
	down a ramp a collapse.
]]
local function checkStructure()
	local thresholds = definition.Thresholds
	local toppled = 0

	for componentId, up in builtUp do
		if rigidParts[componentId] == true then
			local model = ComponentFactory.FindComponentById(componentId)
			local root = if model ~= nil then ComponentFactory.GetRoot(model) else nil

			if root ~= nil then
				local dot = math.clamp(root.CFrame.UpVector:Dot(up), -1, 1)
				local tilt = math.deg(math.acos(dot))

				if tilt > thresholds.StructuralTiltDegrees then
					toppled += 1
				end
			end
		end
	end

	if toppled >= thresholds.StructuralPartCount then
		notify("StructuralOptimism")
	end
end

local function stopSampler()
	if sampler ~= nil then
		sampler:Disconnect()
		sampler = nil
	end
end

--[[
	One sampler for the whole attempt: failure flavour and the safety freeze.
	Nothing here changes experiment state; a toast is the only side effect.
]]
local function startSampler()
	stopSampler()

	sampler = RunService.Heartbeat:Connect(function()
		if not live then
			return
		end

		checkDuck()
		checkStructure()
	end)
end

local function captureBuildState()
	table.clear(builtUp)
	table.clear(rigidParts)

	for _, record in ConnectorService.GetAll() do
		if record.Type == "Rigid" then
			rigidParts[record.ComponentA] = true
			rigidParts[record.ComponentB] = true
		end
	end

	for _, model in ComponentFactory.GetComponents() do
		local componentId = ComponentFactory.GetComponentId(model)
		local root = ComponentFactory.GetRoot(model)

		if componentId ~= nil and root ~= nil then
			builtUp[componentId] = root.CFrame.UpVector
		end
	end
end

-- ExperimentModule -------------------------------------------------------------

function SaveTheDuckExperiment.Load(
	experimentReport: ExperimentTypes.ExperimentReport
): ExperimentTypes.LoadedExperiment?
	local built = SaveTheDuckLevel.Build(definition)
	if built == nil then
		return nil
	end

	handles = built.Handles
	report = experimentReport

	capRestPosition = built.Handles.GoalCap.Position
	capRestColor = built.Handles.GoalCap.Color

	-- Optional: replace the duck appearance with a custom imported visual.
	-- The physics collider (Duck/Body) is untouched; only appearance changes.
	local duckVisual = AssetProvider.Get("Payloads", "Duck")
	if duckVisual ~= nil then
		duckVisual.Parent = built.Handles.Duck
		local root = built.Handles.Duck.PrimaryPart
		if root ~= nil then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "WZ_VisualWeld"
			weld.Part0 = root
			local vizRoot = duckVisual.PrimaryPart
			if vizRoot ~= nil then
				weld.Part1 = vizRoot
				weld.Parent = vizRoot
			end
		end
	end

	-- Optional: replace the goal button appearance with a custom imported visual.
	local goalVisual = AssetProvider.Get("Goals", "GoalButton")
	if goalVisual ~= nil then
		goalVisual.Parent = built.Handles.Goal
		local cap = built.Handles.GoalCap
		local vizRoot = goalVisual.PrimaryPart
		if vizRoot ~= nil then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "WZ_VisualWeld"
			weld.Part0 = cap
			weld.Part1 = vizRoot
			weld.Parent = vizRoot
		end
	end

	-- Attempt to play a button sound on success.  rbxasset:// sounds are not
	-- guaranteed to exist forever; wrap in pcall so a missing asset does not
	-- break the experiment.
	pcall(function()
		local sound = Instance.new("Sound")
		sound.Name = "WZ_GoalSound"
		sound.SoundId = BUTTON_SOUND
		sound.Volume = 0.45
		sound.Parent = built.Handles.GoalCap
	end)

	built.Handles.GoalTrigger.Touched:Connect(onGoalTouched)

	-- Print the asset resolution summary once, so whoever is running Studio
	-- can immediately see whether custom art is active or not.
	AssetProvider.PrintDiagnostics()

	return {
		Definition = definition,
		Workshop = built.Workshop,
		Staged = built.Staged,
	}
end

--[[
	TEST: the duck joins the physics simulation.

	Components are unanchored by SimulationService a moment later; the duck
	belongs to the experiment, so its anchors are this module's business.
]]
function SaveTheDuckExperiment.StartAttempt(attempt: number)
	if handles == nil then
		return
	end

	currentAttempt = attempt
	live = true
	succeeded = false
	table.clear(fired)

	captureBuildState()
	setPayloadAnchored(false)
	zeroPayloadVelocity()
	startSampler()
end

-- RESET: physics is over and the machine has been restored. The duck goes back
-- to its mark so the next attempt starts from the same place as the first.
function SaveTheDuckExperiment.RestoreToBuild()
	live = false
	stopSampler()
	restoreDuck()
end

-- TRY AGAIN: the machine is already gone at this point (ExperimentService
-- disconnects it and returns the parts to the rack). This restores everything
-- the experiment owns.
function SaveTheDuckExperiment.Restart()
	live = false
	succeeded = false
	stopSampler()
	table.clear(fired)
	table.clear(builtUp)
	table.clear(rigidParts)

	local level = handles
	if level ~= nil then
		level.GoalCap.Position = capRestPosition
		level.GoalCap.Color = capRestColor
	end

	restoreDuck()

	-- Reset diagnostics so the next load prints a fresh asset summary.
	AssetProvider.ResetDiagnostics()
end

return table.freeze(SaveTheDuckExperiment)
