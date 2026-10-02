--!strict

--[[
	OpenSesameExperiment

	Experiment 008: Open Sesame.
	Objective: "Get the duck through the gate."

	Key game concepts:
		* Sensors: Proximity sensor detects duck or cart approaching.
		* Servos: Rotary servo moves to target angle (90 deg) instead of spinning continuously.
		* Feedback & Automation: Sensor triggers servo to swing gate open.
		* Open solution: Any machine that gets the duck into the goal button wins.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local FlavourObserver = require(script.Parent.FlavourObserver)
local OpenSesameLevel = require(script.Parent.OpenSesameLevel)

local Config = ConstructionConfig
local BUTTON_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local OpenSesameExperiment = {}

local definition: ExperimentTypes.ExperimentDefinition = ExperimentDefinitions.Get("open_sesame")
	or ExperimentDefinitions.GetDefault()

type HandlesWithPosts = ExperimentTypes.LevelHandles & {
	GatePostLeft: BasePart,
	GatePostRight: BasePart,
}

local handles: HandlesWithPosts? = nil
local report: ExperimentTypes.ExperimentReport? = nil
local capRestPosition: Vector3 = Vector3.zero
local capRestColor: Color3 = Color3.new()

local live = false
local succeeded = false
local currentAttempt = 1
local attemptStartTime = 0
local sampler: RBXScriptConnection? = nil
local goalConnection: RBXScriptConnection? = nil

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ 008] %s", message))
	end
end

local flavour = FlavourObserver.Create({
	GetDefinition = function()
		return definition
	end,
	GetReport = function()
		return report
	end,
	GetAttempt = function()
		return currentAttempt
	end,
	Log = log,
})
local notify = flavour.Fire

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

-- Goal Animation --------------------------------------------------------------

local function animateGoalButton(cap: BasePart)
	local downPosition = capRestPosition - Vector3.new(0, 0.25, 0)
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local tween = TweenService:Create(cap, tweenInfo, {
		Position = downPosition,
		Color = Color3.fromRGB(80, 240, 120),
	})
	tween:Play()

	local sound = Instance.new("Sound")
	sound.SoundId = BUTTON_SOUND
	sound.Volume = 0.5
	sound.Parent = cap
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function resetGoalButton(cap: BasePart)
	cap.Position = capRestPosition
	cap.Color = capRestColor
end

-- Attempt Monitoring ----------------------------------------------------------

local function stopMonitors()
	if sampler ~= nil then
		sampler:Disconnect()
		sampler = nil
	end
end

local function startMonitors()
	stopMonitors()

	local level = handles
	if level == nil then
		return
	end

	local duck = level.Duck
	local primary = duck.PrimaryPart
	if primary == nil then
		return
	end

	local thresholds = definition.Thresholds
	local timeStuckNearGate = 0
	attemptStartTime = os.clock()

	sampler = RunService.Heartbeat:Connect(function(dt: number)
		if not live or succeeded then
			return
		end

		local pos = primary.Position
		local vel = primary.AssemblyLinearVelocity
		local speed = vel.Magnitude
		local elapsed = os.clock() - attemptStartTime

		-- 1. Standard physics boundaries
		if pos.Y < thresholds.PitY then
			notify("DuckDown")
			return
		end

		local center = level.Center
		local dist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
		if dist > thresholds.AwayDistance then
			notify("DuckDeparture")
			return
		end

		if speed > thresholds.FastSpeed then
			notify("BallisticDuck")
		end

		if pos.Y > thresholds.HighY then
			notify("SpaceProgram")
		end

		-- 2. Gate stall detection (duck is in front of the gate Z between -12 and 0, stopped)
		if elapsed > 2.5 and pos.Z > -14 and pos.Z < 0 and math.abs(pos.X) < 7 then
			if speed < 0.5 then
				timeStuckNearGate += dt
				if timeStuckNearGate > 2.0 then
					notify("GateClosed")
				end
			else
				timeStuckNearGate = 0
			end
		end

		-- 3. Automation delay detection (duck waiting near start or moving slowly for > 6s)
		if elapsed > 6.0 and pos.Z < -5 and speed < 1.0 then
			notify("AutomationThinking")
		end
	end)
end

-- Callbacks ------------------------------------------------------------------

local function onGoalTouched(otherPart: BasePart)
	if not live or succeeded then
		return
	end

	local active = handles
	if active == nil then
		return
	end

	local duckModel = active.Duck
	local isDuckDescendant = otherPart:IsDescendantOf(duckModel)
	local isPayload = otherPart:GetAttribute(Config.AttributePayload) == true
		or duckModel:GetAttribute(Config.AttributePayload) == true

	if not (isDuckDescendant or isPayload) then
		return
	end

	succeeded = true
	log(string.format("Goal activated on attempt %d", currentAttempt))

	animateGoalButton(active.GoalCap)

	if report ~= nil then
		report.Success()
	end
end

-- Lifecycle -------------------------------------------------------------------

function OpenSesameExperiment.Load(
	reportCallback: ExperimentTypes.ExperimentReport
): ExperimentTypes.LoadedExperiment?
	local currentDef = ExperimentDefinitions.Get("open_sesame") or definition
	definition = currentDef
	report = reportCallback

	local built = OpenSesameLevel.Build(definition)
	handles = built.Handles

	local duck = built.Handles.Duck
	if duck.PrimaryPart ~= nil then
		duck.PrimaryPart.Anchored = true
	end

	goalConnection = built.Handles.GoalTrigger.Touched:Connect(onGoalTouched)

	capRestPosition = built.Handles.GoalCap.Position
	capRestColor = built.Handles.GoalCap.Color

	return {
		Definition = definition,
		Workshop = built.Workshop,
		Staged = built.Staged,
	}
end

function OpenSesameExperiment.StartAttempt(attemptNumber: number)
	currentAttempt = attemptNumber
	live = true
	succeeded = false
	flavour.Clear()

	setPayloadAnchored(false)
	startMonitors()
	log(string.format("Attempt %d started", currentAttempt))
end

function OpenSesameExperiment.ResetAttempt()
	live = false
	succeeded = false
	stopMonitors()

	local level = handles
	if level ~= nil then
		setPayloadAnchored(true)
		zeroPayloadVelocity()
		level.Duck:PivotTo(level.DuckSpawn)
		resetGoalButton(level.GoalCap)
	end

	log(string.format("Attempt %d reset", currentAttempt))
end

function OpenSesameExperiment.Unload()
	live = false
	succeeded = false
	stopMonitors()

	if goalConnection ~= nil then
		goalConnection:Disconnect()
		goalConnection = nil
	end

	handles = nil
	report = nil
	log("Unloaded")
end

function OpenSesameExperiment.GetHandles(): ExperimentTypes.LevelHandles?
	return handles
end

return table.freeze(OpenSesameExperiment)
