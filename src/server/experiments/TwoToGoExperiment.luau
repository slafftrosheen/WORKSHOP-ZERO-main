--!strict

--[[
	TwoToGoExperiment

	Experiment 007: TWO TO GO.
	Objective: "Lift the duck to the platform."

	Key game concepts:
		* Pressure sensors detect load / contact.
		* AND gate requires all inputs to be true.
		* Winch actuates when enabled by control signal.
		* Open solution: Any machine that lifts the duck onto the platform wins.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local FlavourObserver = require(script.Parent.FlavourObserver)
local TwoToGoLevel = require(script.Parent.TwoToGoLevel)

local Config = ConstructionConfig
local BUTTON_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local TwoToGoExperiment = {}

local definition: ExperimentTypes.ExperimentDefinition = ExperimentDefinitions.Get("two_to_go")
	or ExperimentDefinitions.GetDefault()

type HandlesWithPads = ExperimentTypes.LevelHandles & {
	PadA: BasePart,
	PadB: BasePart,
}

local handles: HandlesWithPads? = nil
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
		print(string.format("[WZ 007] %s", message))
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
	sound.Volume = 0.6
	sound.Parent = cap
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function resetButtonVisual(cap: BasePart)
	cap.Position = capRestPosition
	cap.Color = capRestColor
end

-- Monitors -------------------------------------------------------------------

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
	local goalPos = definition.Geometry.ButtonPosition
	attemptStartTime = os.clock()

	local checkedPartial = false

	sampler = RunService.Heartbeat:Connect(function()
		if not live or succeeded then
			return
		end

		local pos = primary.Position
		local vel = primary.AssemblyLinearVelocity
		local speed = vel.Magnitude

		if pos.Y < thresholds.PitY then
			notify("DuckDown")
		end

		local distFromGoal = (pos - goalPos).Magnitude
		if distFromGoal > thresholds.AwayDistance then
			notify("DuckDeparture")
		end

		if speed > thresholds.FastSpeed then
			notify("BallisticDuck")
		end

		if pos.Y > thresholds.HighY then
			notify("SpaceProgram")
		end

		-- After 3 seconds, check if sensors in the workshop indicate partial condition
		if not checkedPartial and os.clock() - attemptStartTime > 3.0 then
			checkedPartial = true
			local activeCount = 0
			local workshop = level.Workshop
			for _, descendant in workshop:GetDescendants() do
				if descendant:IsA("Model") and descendant.Name == "PressureSensor" then
					local outPort = descendant:FindFirstChild("Out")
					if outPort ~= nil and outPort:GetAttribute("WZ_SignalValue") == true then
						activeCount += 1
					end
				end
			end
			if activeCount == 1 then
				notify("OneOutOfTwo")
			end
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

function TwoToGoExperiment.Load(
	reportCallback: ExperimentTypes.ExperimentReport
): ExperimentTypes.LoadedExperiment?
	local currentDef = ExperimentDefinitions.Get("two_to_go") or definition
	definition = currentDef
	report = reportCallback

	local built = TwoToGoLevel.Build(definition)
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

function TwoToGoExperiment.StartAttempt(attemptNumber: number)
	currentAttempt = attemptNumber
	live = true
	succeeded = false
	flavour.Clear()

	setPayloadAnchored(false)
	startMonitors()
	log(string.format("Attempt %d started", currentAttempt))
end

function TwoToGoExperiment.RestoreToBuild()
	live = false
	succeeded = false
	stopMonitors()

	local level = handles
	if level ~= nil then
		setPayloadAnchored(true)
		zeroPayloadVelocity()
		level.Duck:PivotTo(CFrame.new(definition.Geometry.DuckSpawn))
		resetButtonVisual(level.GoalCap)
	end

	log(string.format("Attempt %d restored to Build", currentAttempt))
end

function TwoToGoExperiment.Restart()
	currentAttempt = 0
	live = false
	succeeded = false
	flavour.Clear()
	stopMonitors()

	local level = handles
	if level ~= nil then
		setPayloadAnchored(true)
		zeroPayloadVelocity()
		level.Duck:PivotTo(CFrame.new(definition.Geometry.DuckSpawn))
		resetButtonVisual(level.GoalCap)
	end

	log("Experiment restarted")
end

function TwoToGoExperiment.Unload()
	stopMonitors()
	flavour.Clear()

	if goalConnection ~= nil then
		goalConnection:Disconnect()
		goalConnection = nil
	end

	handles = nil
	report = nil
	live = false
	succeeded = false
	log("Experiment unloaded")
end

return table.freeze(TwoToGoExperiment)
