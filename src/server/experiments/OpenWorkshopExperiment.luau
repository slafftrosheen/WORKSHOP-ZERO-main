--!strict

--[[
	OpenWorkshopExperiment

	Free build: every component on the rack, the same physics kernel, the same
	TEST and RESET, and the same duck to launch at things.

	What it does not have is a goal button. Nothing here can succeed, so
	report.Success is never called, no attempt can finish, and this mode can
	never unlock or renumber anything.

	The flavour observer is this module's own, exactly as every other
	experiment keeps its own: they all read the same thresholds out of
	ExperimentDefinitions and report through the same ExperimentReport, so
	"the machine went over" means the same thing everywhere.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ComponentFactory = require(script.Parent.Parent.construction.ComponentFactory)
local ConnectorService = require(script.Parent.Parent.construction.ConnectorService)
local OpenWorkshopLevel = require(script.Parent.OpenWorkshopLevel)
local FlavourObserver = require(script.Parent.FlavourObserver)

local OpenWorkshopExperiment = {}

local definition: ExperimentTypes.ExperimentDefinition = ExperimentDefinitions.GetOpenWorkshop()
local built: OpenWorkshopLevel.Built? = nil
local report: ExperimentTypes.ExperimentReport? = nil

-- An attempt is live between TEST and RESET, which is exactly the window in
-- which the duck can do anything funny.
local live = false
local currentAttempt = 1
local sampler: RBXScriptConnection? = nil

-- Captured at the start of an attempt: enough to tell "the machine went over"
-- from "a wheel is spinning freely on its axle".
local builtUp: { [string]: Vector3 } = {}
local rigidParts: { [string]: boolean } = {}

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ OpenWorkshop] %s", message))
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

-- Duck helpers ---------------------------------------------------------------

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
	local level = built
	if level == nil then
		return
	end

	for _, part in payloadParts(level.Duck) do
		part.Anchored = anchored
	end
end

local function zeroPayloadVelocity()
	local level = built
	if level == nil then
		return
	end

	for _, part in payloadParts(level.Duck) do
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end
end

local function restoreDuck()
	local level = built
	if level == nil then
		return
	end

	zeroPayloadVelocity()
	setPayloadAnchored(true)
	level.Duck:PivotTo(level.DuckSpawn)
	zeroPayloadVelocity()
end

-- Flavour -------------------------------------------------------------------

local function checkDuck()
	local level = built
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
		-- Off the edge of the world entirely. Freeze it where it stopped so
		-- physics cannot keep integrating a falling object forever. This is
		-- still not a reset.
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
	"Fell apart" can only honestly mean "the machine went over": joints in
	this kernel never break, so the honest signal is rotation. Wheels are
	excluded because a wheel on an axle is supposed to spin.
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

-- ExperimentModule -----------------------------------------------------------

function OpenWorkshopExperiment.Load(
	experimentReport: ExperimentTypes.ExperimentReport
): ExperimentTypes.LoadedExperiment?
	local level = OpenWorkshopLevel.Build(definition)
	if level == nil then
		return nil
	end

	built = level
	report = experimentReport

	return {
		Definition = definition,
		Workshop = level.Workshop,
		Staged = level.Staged,
	}
end

function OpenWorkshopExperiment.StartAttempt(attempt: number)
	if built == nil then
		return
	end

	currentAttempt = attempt
	live = true
	flavour.Clear()

	captureBuildState()
	setPayloadAnchored(false)
	zeroPayloadVelocity()
	startSampler()
end

function OpenWorkshopExperiment.RestoreToBuild()
	live = false
	stopSampler()
	restoreDuck()
end

function OpenWorkshopExperiment.Restart()
	live = false
	stopSampler()
	flavour.Clear()
	table.clear(builtUp)
	table.clear(rigidParts)
	restoreDuck()
end

function OpenWorkshopExperiment.Unload()
	live = false
	stopSampler()

	flavour.Clear()
	table.clear(builtUp)
	table.clear(rigidParts)

	built = nil
	report = nil
end

return table.freeze(OpenWorkshopExperiment)
