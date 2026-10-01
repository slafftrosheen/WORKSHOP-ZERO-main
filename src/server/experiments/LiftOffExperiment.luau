--!strict

--[[
	LiftOffExperiment

	Experiment 005: Lift Off.
	Objective: "Get the duck onto the high platform."

	Key game concepts:
		* Tension: a rope pulls a load, but cannot push one.
		* Winch mechanics: winches pull rope inward during TEST.
		* Lifting / Crane / Hoist / Elevator: player can construct cranes,
		  counterweights, elevator carriages, or slung platforms.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local AssetProvider = require(script.Parent.Parent.assets.AssetProvider)
local LiftOffLevel = require(script.Parent.LiftOffLevel)

local Config = ConstructionConfig
local BUTTON_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local LiftOffExperiment = {}

local definition: ExperimentTypes.ExperimentDefinition = ExperimentDefinitions.Get("lift_off")
	or ExperimentDefinitions.GetDefault()
local handles: ExperimentTypes.LevelHandles? = nil
local report: ExperimentTypes.ExperimentReport? = nil
local capRestPosition: Vector3 = Vector3.zero
local capRestColor: Color3 = Color3.new()

local live = false
local succeeded = false
local currentAttempt = 1
local attemptStartTime = 0
local sampler: RBXScriptConnection? = nil
local goalConnection: RBXScriptConnection? = nil
local fired: { [ExperimentTypes.FailureEventId]: boolean } = {}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ 005] %s", message))
	end
end

-- Payload helpers -------------------------------------------------------------

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

-- Goal button -----------------------------------------------------------------

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
		if handles == level and level.GoalCap.Parent ~= nil then
			level.GoalCap.Position = capRestPosition
			level.GoalCap.Color = capRestColor
		end
	end)
end

local function notify(eventId: ExperimentTypes.FailureEventId)
	if fired[eventId] then
		return
	end

	fired[eventId] = true

	if report ~= nil then
		local text = ExperimentDefinitions.FailureMessage(definition, eventId, currentAttempt)
		if text ~= "" then
			report.Toast(text)
		end
	end
end

local function onGoalTouched(other: BasePart)
	local level = handles
	if level == nil or not live or succeeded then
		return
	end

	local payload = findPayload(other)
	if payload == level.Duck then
		succeeded = true
		live = false
		pressButton()

		log(string.format("Goal reached on attempt %d!", currentAttempt))

		if report ~= nil then
			local elapsed = os.clock() - attemptStartTime
			report.Success({
				Attempts = currentAttempt,
				PartsUsed = #ComponentFactory.GetComponents(),
				ElapsedSeconds = math.round(elapsed * 10) / 10,
			})
		end
	end
end

-- Monitors -------------------------------------------------------------------

local function stopSampler()
	if sampler ~= nil then
		sampler:Disconnect()
		sampler = nil
	end
end

local function startSampler()
	stopSampler()

	local active = handles
	if active == nil then
		return
	end

	local duckRoot = active.Duck.PrimaryPart
	if duckRoot == nil then
		return
	end

	sampler = RunService.Heartbeat:Connect(function()
		if not live or duckRoot.Parent == nil then
			return
		end

		local pos = duckRoot.Position
		local vel = duckRoot.AssemblyLinearVelocity
		local speed = vel.Magnitude

		-- Space program
		if (pos.Y > definition.Thresholds.HighY or speed > 60) and not fired.SpaceProgram then
			notify("SpaceProgram")
		end

		-- Ballistic duck
		if speed > definition.Thresholds.FastSpeed and not fired.BallisticDuck then
			notify("BallisticDuck")
		end

		-- Duck departure (fell far away horizontally)
		local offset = pos - active.Center
		local horizontalDist = Vector2.new(offset.X, offset.Z).Magnitude
		if horizontalDist > definition.Thresholds.AwayDistance and not fired.DuckDeparture then
			notify("DuckDeparture")
		end

		-- Duck down in pit (below ground)
		if pos.Y < definition.Thresholds.PitY and not fired.DuckDown then
			notify("DuckDown")
		end
	end)
end

-- ExperimentModule implementation --------------------------------------------

function LiftOffExperiment.Load(
	experimentReport: ExperimentTypes.ExperimentReport
): ExperimentTypes.LoadedExperiment?
	local targetDef = ExperimentDefinitions.Get("lift_off")
	if targetDef ~= nil then
		definition = targetDef
	end

	local built = LiftOffLevel.Build(definition)
	if built == nil then
		return nil
	end

	handles = built.Handles
	report = experimentReport

	capRestPosition = built.Handles.GoalCap.Position
	capRestColor = built.Handles.GoalCap.Color

	-- Custom duck and goal art is applied by the shared level builders.

	pcall(function()
		local sound = Instance.new("Sound")
		sound.Name = "WZ_GoalSound"
		sound.SoundId = BUTTON_SOUND
		sound.Volume = 0.45
		sound.Parent = built.Handles.GoalCap
	end)

	if goalConnection ~= nil then
		goalConnection:Disconnect()
		goalConnection = nil
	end
	goalConnection = built.Handles.GoalTrigger.Touched:Connect(onGoalTouched)

	AssetProvider.PrintDiagnostics()

	return {
		Definition = definition,
		Workshop = built.Workshop,
		Staged = built.Staged,
	}
end

function LiftOffExperiment.StartAttempt(attempt: number)
	if handles == nil then
		return
	end

	currentAttempt = attempt
	live = true
	succeeded = false
	attemptStartTime = os.clock()
	table.clear(fired)

	setPayloadAnchored(false)
	zeroPayloadVelocity()
	startSampler()
end

function LiftOffExperiment.RestoreToBuild()
	live = false
	stopSampler()
	restoreDuck()
end

function LiftOffExperiment.Restart()
	live = false
	succeeded = false
	stopSampler()
	table.clear(fired)

	local level = handles
	if level ~= nil then
		level.GoalCap.Position = capRestPosition
		level.GoalCap.Color = capRestColor
	end

	restoreDuck()
	AssetProvider.ResetDiagnostics()
end

function LiftOffExperiment.Unload()
	live = false
	succeeded = false
	stopSampler()

	if goalConnection ~= nil then
		goalConnection:Disconnect()
		goalConnection = nil
	end

	table.clear(fired)
	handles = nil
	report = nil
	AssetProvider.ResetDiagnostics()
end

return table.freeze(LiftOffExperiment)
