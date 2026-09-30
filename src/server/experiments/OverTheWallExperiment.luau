--!strict

--[[
	OverTheWallExperiment

	Experiment 003: Over the Wall.
	Launches or transports the duck over a 12-stud obstacle wall to hit the goal button.

	Lifecycle:
		Load(report)     -> builds level, attaches goal trigger, applies visuals
		StartAttempt(n)  -> unanchors payload, captures build state, starts monitors
		RestoreToBuild() -> restores duck to start pad, clears transient state
		Restart()        -> restores button and duck to original state
		Unload()         -> disconnects all listeners, stops samplers, cleans up
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ExperimentLevelUtil = require(script.Parent.ExperimentLevelUtil)
local OverTheWallLevel = require(script.Parent.OverTheWallLevel)

local Config = ConstructionConfig
local BUTTON_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local OverTheWallExperiment = {}

local definition: ExperimentTypes.ExperimentDefinition = ExperimentDefinitions.Get("over_the_wall")
	or ExperimentDefinitions.GetDefault()
local handles: ExperimentTypes.LevelHandles? = nil
local report: ExperimentTypes.ExperimentReport? = nil
local capRestPosition: Vector3 = Vector3.zero
local capRestColor: Color3 = Color3.new()

local live = false
local succeeded = false
local currentAttempt = 1
local sampler: RBXScriptConnection? = nil
local goalConnection: RBXScriptConnection? = nil
local wallConnection: RBXScriptConnection? = nil
local fired: { [ExperimentTypes.FailureEventId]: boolean } = {}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Exp 003] %s", message))
	end
end

local function fireToast(eventId: ExperimentTypes.FailureEventId)
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

local function stopMonitors()
	if sampler ~= nil then
		sampler:Disconnect()
		sampler = nil
	end
	if wallConnection ~= nil then
		wallConnection:Disconnect()
		wallConnection = nil
	end
end

local function startMonitors()
	stopMonitors()

	local active = handles
	if active == nil then
		return
	end

	local duckRoot = active.Duck.PrimaryPart
	if duckRoot == nil then
		return
	end

	-- Monitor duck collision with the wall obstacle
	local wallObstacle = active.Workshop:FindFirstChild("WallObstacle")
	if wallObstacle ~= nil and wallObstacle:IsA("BasePart") then
		wallConnection = wallObstacle.Touched:Connect(function(otherPart: BasePart)
			if not live or succeeded then
				return
			end
			if otherPart:IsDescendantOf(active.Duck) then
				fireToast("WallImpact")
			end
		end)
	end

	sampler = RunService.Heartbeat:Connect(function()
		if not live or duckRoot.Parent == nil then
			return
		end

		local pos = duckRoot.Position
		local vel = duckRoot.AssemblyLinearVelocity
		local speed = vel.Magnitude

		-- High vertical launch
		if pos.Y > 24 and not fired.VerticalProgress then
			if pos.Z < 0 then
				fireToast("VerticalProgress")
			end
		end

		-- Space program
		if (pos.Y > definition.Thresholds.HighY or speed > 60) and not fired.SpaceProgram then
			fireToast("SpaceProgram")
		end

		-- Ballistic duck
		if speed > definition.Thresholds.FastSpeed and not fired.BallisticDuck then
			fireToast("BallisticDuck")
		end

		-- Duck departure
		local offset = pos - active.Center
		local horizontalDist = Vector2.new(offset.X, offset.Z).Magnitude
		if horizontalDist > definition.Thresholds.AwayDistance and not fired.DuckDeparture then
			fireToast("DuckDeparture")
		end

		-- Duck down in pit
		if pos.Y < definition.Thresholds.PitY and not fired.DuckDown then
			fireToast("DuckDown")
			duckRoot.Anchored = true
		end
	end)
end

-- Success ---------------------------------------------------------------------

local function animateGoalButton(cap: BasePart)
	local target = capRestPosition - Vector3.new(0, 0.45, 0)
	cap.Position = target
	cap.Color = Color3.fromRGB(80, 220, 110)

	local sound = Instance.new("Sound")
	sound.SoundId = BUTTON_SOUND
	sound.Volume = 0.8
	sound.Parent = cap
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)

	task.delay(1.5, function()
		if cap.Parent ~= nil then
			cap.Position = capRestPosition
			cap.Color = capRestColor
		end
	end)
end

local function onGoalTouched(otherPart: BasePart)
	if not live or succeeded then
		return
	end

	local active = handles
	if active == nil then
		return
	end

	local duckModel = active.Duck
	if not otherPart:IsDescendantOf(duckModel) then
		return
	end

	local isPayload = otherPart:GetAttribute(Config.AttributePayload) == true
		or duckModel:GetAttribute(Config.AttributePayload) == true
	if not isPayload then
		return
	end

	succeeded = true
	log(string.format("Goal activated by %s on attempt %d", otherPart.Name, currentAttempt))

	animateGoalButton(active.GoalCap)

	if report ~= nil then
		report.Success()
	end
end

-- Lifecycle -------------------------------------------------------------------

function OverTheWallExperiment.Load(
	reportCallback: ExperimentTypes.ExperimentReport
): ExperimentTypes.LoadedExperiment?
	local currentDef = ExperimentDefinitions.Get("over_the_wall") or definition
	definition = currentDef
	report = reportCallback

	local built = OverTheWallLevel.Build(definition)
	handles = built.Handles

	local duck = built.Handles.Duck
	duck.PrimaryPart.Anchored = true

	goalConnection = built.Handles.GoalTrigger.Touched:Connect(onGoalTouched)
	capRestPosition = built.Handles.GoalCap.Position
	capRestColor = built.Handles.GoalCap.Color

	ExperimentLevelUtil.ApplyCustomVisual(
		built.Handles.Duck,
		built.Handles.Duck.PrimaryPart :: BasePart,
		"Payloads",
		"Duck"
	)
	ExperimentLevelUtil.ApplyCustomVisual(
		built.Handles.Goal,
		built.Handles.GoalCap,
		"Goals",
		"GoalButton"
	)

	return {
		Definition = definition,
		Workshop = built.Workshop,
		Staged = built.Staged,
	}
end

function OverTheWallExperiment.StartAttempt(attemptNumber: number)
	currentAttempt = attemptNumber
	live = true
	succeeded = false
	fired = {}

	local active = handles
	if active ~= nil and active.Duck.PrimaryPart ~= nil then
		active.Duck.PrimaryPart.Anchored = false
	end

	startMonitors()
	log(string.format("Attempt %d started", currentAttempt))
end

function OverTheWallExperiment.RestoreToBuild()
	live = false
	succeeded = false
	stopMonitors()

	local active = handles
	if active ~= nil and active.Duck.PrimaryPart ~= nil then
		local root = active.Duck.PrimaryPart
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		active.Duck:PivotTo(active.DuckSpawn)
		root.Anchored = true
	end

	fired = {}
	log("Restored to build")
end

function OverTheWallExperiment.Restart()
	live = false
	succeeded = false
	stopMonitors()

	local active = handles
	if active ~= nil then
		if active.Duck.PrimaryPart ~= nil then
			local root = active.Duck.PrimaryPart
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			active.Duck:PivotTo(active.DuckSpawn)
			root.Anchored = true
		end

		active.GoalCap.Position = capRestPosition
		active.GoalCap.Color = capRestColor
	end

	fired = {}
	log("Restarted")
end

function OverTheWallExperiment.Unload()
	live = false
	succeeded = false
	stopMonitors()

	if goalConnection ~= nil then
		goalConnection:Disconnect()
		goalConnection = nil
	end

	handles = nil
	report = nil
	fired = {}
	log("Unloaded")
end

return table.freeze(OverTheWallExperiment)
