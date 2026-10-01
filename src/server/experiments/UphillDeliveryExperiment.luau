--!strict

--[[
	UphillDeliveryExperiment

	Experiment 002: Uphill Delivery.
	Moves the duck up an incline to the button at the top platform.

	Lifecycle:
		Load(report)     -> builds level, attaches goal trigger, applies visuals
		StartAttempt(n)  -> unanchors payload, captures build state, starts monitors
		RestoreToBuild() -> restores duck to start pad, clears transient state
		Restart()        -> restores button and duck to original state
		Unload()         -> disconnects all listeners, stops samplers, cleans up

	Failure flavours:
		* LowTravel: motor active but vehicle barely moved
		* BackwardMovement: machine drives backward down the hill
		* Rollback: machine climbed partially, then gravity took it back down
		* VehicleFlip: machine rolled over
		* HighRpm: wheels spinning at questionable speed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local ConnectorService = require(script.Parent.Parent.construction.ConnectorService)
local ActuatorService = require(script.Parent.Parent.construction.ActuatorService)
local AssetProvider = require(script.Parent.Parent.assets.AssetProvider)
local UphillDeliveryLevel = require(script.Parent.UphillDeliveryLevel)
local FlavourObserver = require(script.Parent.FlavourObserver)

local Config = ConstructionConfig
local BUTTON_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local UphillDeliveryExperiment = {}

local definition: ExperimentTypes.ExperimentDefinition = ExperimentDefinitions.Get(
	"uphill_delivery"
) or ExperimentDefinitions.GetDefault()
local handles: ExperimentTypes.LevelHandles? = nil
local report: ExperimentTypes.ExperimentReport? = nil
local capRestPosition: Vector3 = Vector3.zero
local capRestColor: Color3 = Color3.new()

local live = false
local succeeded = false
local currentAttempt = 1
local sampler: RBXScriptConnection? = nil
local goalConnection: RBXScriptConnection? = nil

-- Machine tracking for failure flavour detection
local attemptStartTime = 0
local initialMachinePositions: { [string]: Vector3 } = {}
local maxAttainedDuckY = 0
local builtUp: { [string]: Vector3 } = {}
local rigidParts: { [string]: boolean } = {}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ 002] %s", message))
	end
end

-- Shared once-per-attempt flavour plumbing; see FlavourObserver.
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
		if handles == level and level.GoalCap.Parent ~= nil then
			level.GoalCap.Position = capRestPosition
			level.GoalCap.Color = capRestColor
		end
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

	succeeded = true
	pressButton()

	if report ~= nil then
		report.Success()
	end
end

-- Failure flavour --------------------------------------------------------------

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
	local velocity = root.AssemblyLinearVelocity

	if position.Y < thresholds.CleanupY then
		setPayloadAnchored(true)
		zeroPayloadVelocity()
		live = false
		log("The duck left the workshop entirely and was frozen where it stopped")
		return
	end

	if velocity.Magnitude > thresholds.FastSpeed then
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

	-- Rollback detection: duck attained height on the ramp, then fell back down
	if position.Y > maxAttainedDuckY then
		maxAttainedDuckY = position.Y
	end

	if maxAttainedDuckY > 4.5 and position.Y < 2.0 and velocity.Z < -2 then
		notify("Rollback")
	end
end

local function checkMachine()
	local thresholds = definition.Thresholds
	local now = os.clock()
	local elapsed = now - attemptStartTime

	local components = ComponentFactory.GetComponents()
	local maxComponentSpeed = 0
	local maxTranslation = 0
	local backwardSpeed = 0
	local toppled = 0

	for _, model in components do
		local root = ComponentFactory.GetRoot(model)
		local compId = ComponentFactory.GetComponentId(model)
		if root ~= nil and compId ~= nil then
			local speed = root.AssemblyLinearVelocity.Magnitude
			if speed > maxComponentSpeed then
				maxComponentSpeed = speed
			end

			-- Check backward motion
			if root.AssemblyLinearVelocity.Z < backwardSpeed then
				backwardSpeed = root.AssemblyLinearVelocity.Z
			end

			-- Check wheel rotational speed for HighRpm
			local rotSpeed = root.AssemblyAngularVelocity.Magnitude
			if rotSpeed > 38 then
				notify("HighRpm")
			end

			-- Check travel distance from attempt start
			local startPos = initialMachinePositions[compId]
			if startPos ~= nil then
				local dist = (root.Position - startPos).Magnitude
				if dist > maxTranslation then
					maxTranslation = dist
				end
			end

			-- Check tilt for vehicle flip
			local up = builtUp[compId]
			if up ~= nil and rigidParts[compId] == true then
				local dot = math.clamp(root.CFrame.UpVector:Dot(up), -1, 1)
				local tilt = math.deg(math.acos(dot))
				if tilt > thresholds.StructuralTiltDegrees then
					toppled += 1
				end
			end
		end
	end

	-- Flip detection
	if toppled >= thresholds.StructuralPartCount then
		notify("VehicleFlip")
	end

	-- Backward movement: machine moving noticeably toward -Z
	if backwardSpeed < -6 and maxTranslation > 3 then
		notify("BackwardMovement")
	end

	-- Low travel: motors active for > 3.5s but machine moved less than 1.5 studs
	if ActuatorService.GetCount() > 0 and elapsed > 3.5 and maxTranslation < 1.5 then
		notify("LowTravel")
	end
end

local function stopSampler()
	if sampler ~= nil then
		sampler:Disconnect()
		sampler = nil
	end
end

local function startSampler()
	stopSampler()

	sampler = RunService.Heartbeat:Connect(function()
		if not live then
			return
		end

		checkDuck()
		checkMachine()
	end)
end

local function captureBuildState()
	table.clear(builtUp)
	table.clear(rigidParts)
	table.clear(initialMachinePositions)

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
			initialMachinePositions[componentId] = root.Position
		end
	end
end

-- ExperimentModule -------------------------------------------------------------

function UphillDeliveryExperiment.Load(
	experimentReport: ExperimentTypes.ExperimentReport
): ExperimentTypes.LoadedExperiment?
	local targetDef = ExperimentDefinitions.Get("uphill_delivery")
	if targetDef ~= nil then
		definition = targetDef
	end

	local built = UphillDeliveryLevel.Build(definition)
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

function UphillDeliveryExperiment.StartAttempt(attempt: number)
	if handles == nil then
		return
	end

	currentAttempt = attempt
	live = true
	succeeded = false
	attemptStartTime = os.clock()
	maxAttainedDuckY = 0
	flavour.Clear()

	captureBuildState()
	setPayloadAnchored(false)
	zeroPayloadVelocity()
	startSampler()
end

function UphillDeliveryExperiment.RestoreToBuild()
	live = false
	stopSampler()
	restoreDuck()
end

function UphillDeliveryExperiment.Restart()
	live = false
	succeeded = false
	stopSampler()
	flavour.Clear()
	table.clear(builtUp)
	table.clear(rigidParts)
	table.clear(initialMachinePositions)

	local level = handles
	if level ~= nil then
		level.GoalCap.Position = capRestPosition
		level.GoalCap.Color = capRestColor
	end

	restoreDuck()
	AssetProvider.ResetDiagnostics()
end

function UphillDeliveryExperiment.Unload()
	live = false
	succeeded = false
	stopSampler()

	if goalConnection ~= nil then
		goalConnection:Disconnect()
		goalConnection = nil
	end

	flavour.Clear()
	table.clear(builtUp)
	table.clear(rigidParts)
	table.clear(initialMachinePositions)

	handles = nil
	report = nil
	AssetProvider.ResetDiagnostics()
end

return table.freeze(UphillDeliveryExperiment)
