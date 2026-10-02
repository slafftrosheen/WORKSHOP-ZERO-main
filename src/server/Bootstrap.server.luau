--!strict

--[[
	Bootstrap (server)

	Wires the server in one readable place, in the order the world needs it:

		1. collision groups, before any part is created with one
		2. the network surface, handed to the services that own it
		3. request handlers, funneled through the experiment layer
		4. the world: Experiment 001, or the developer harness behind a flag

	No framework, no service locator, no event bus. The server owns every
	decision; clients request actions and read state.

	The construction kernel is unchanged by WZ-002: this file only decides which
	level the kernel is attached to and who is allowed to talk to it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)
local ProjectInfo = require(Shared.ProjectInfo)

local BuildService = require(script.Parent.construction.BuildService)
local SimulationService = require(script.Parent.construction.SimulationService)
local ActuatorService = require(script.Parent.construction.ActuatorService)
local CollisionGroups = require(script.Parent.CollisionGroups)
local ExperimentService = require(script.Parent.experiments.ExperimentService)
local PrototypeWorkshop = require(script.Parent.dev.PrototypeWorkshop)
local WorkshopPresentationService = require(script.Parent.world.WorkshopPresentationService)
local WiringService = require(script.Parent.logic.WiringService)
local LogicService = require(script.Parent.logic.LogicService)

local Config = ConstructionConfig

print(string.format("[%s] Server bootstrap %s", ProjectInfo.InternalName, ProjectInfo.Version))

-- 1. Collision groups ---------------------------------------------------------

-- Registered before the level is built: assigning a part to an unregistered
-- group is an error, and the level assigns groups as it creates parts.
CollisionGroups.Setup()
CollisionGroups.TrackPlayers()

-- 2. Network surface ----------------------------------------------------------

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("RemoteEvent") then
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent

	return remote
end

local function ensureStringValue(parent: Instance, name: string): StringValue
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("StringValue") then
		return existing
	end

	local value = Instance.new("StringValue")
	value.Name = name
	value.Parent = parent

	return value
end

local function ensureIntValue(parent: Instance, name: string): IntValue
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("IntValue") then
		return existing
	end

	local value = Instance.new("IntValue")
	value.Name = name
	value.Parent = parent

	return value
end

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = Config.RemotesFolderName
remotesFolder.Parent = ReplicatedStorage

--[[
	The network surface, kept deliberately small:

		RequestSimulationAction   client -> server   "Test" | "Reset"
		RequestRotation           client -> server   { ComponentId, Operation }
		RequestDisconnect         client -> server   { ComponentId }
		DragStateChanged          server -> client   componentId | nil
		SimulationState           replicated value   the physics phase

		RequestExperimentAction   client -> server   "Restart" | "Next" | "Select"
		FailureToast              server -> client   flavour line
		OpenExperimentBoard       server -> client   the physical panel asked for the board
		ExperimentState           replicated value   the challenge phase
		ExperimentAttempt         replicated value   attempts this session
		ExperimentPartsUsed       replicated value   parts used in the last test

	State is a value rather than an event so that a player who joins in the
	middle of a test immediately reads "Testing" instead of waiting for the
	next broadcast.
]]
local remotes: ExperimentTypes.ExperimentRemotes = {
	RequestSimulationAction = ensureRemoteEvent(remotesFolder, Config.RemoteSimulationAction),
	RequestRotation = ensureRemoteEvent(remotesFolder, Config.RemoteRotation),
	RequestDisconnect = ensureRemoteEvent(remotesFolder, Config.RemoteDisconnect),
	RequestReturnToRack = ensureRemoteEvent(remotesFolder, Config.RemoteReturnToRack),
	DragStateChanged = ensureRemoteEvent(remotesFolder, Config.RemoteDragState),
	SimulationState = ensureStringValue(remotesFolder, Config.StateValueName),

	RequestExperimentAction = ensureRemoteEvent(remotesFolder, Config.RemoteExperimentAction),
	FailureToast = ensureRemoteEvent(remotesFolder, Config.RemoteFailureToast),
	OpenExperimentBoard = ensureRemoteEvent(remotesFolder, Config.RemoteOpenExperimentBoard),
	ExperimentState = ensureStringValue(remotesFolder, Config.ExperimentStateValueName),
	CurrentExperimentId = ensureStringValue(remotesFolder, Config.CurrentExperimentValueName),
	ExperimentAttempt = ensureIntValue(remotesFolder, Config.AttemptValueName),
	ExperimentPartsUsed = ensureIntValue(remotesFolder, Config.PartsUsedValueName),
	UnlockedExperimentIndex = ensureIntValue(remotesFolder, Config.UnlockedExperimentValueName),
	RequestWireConnect = ensureRemoteEvent(remotesFolder, Config.RemoteWireConnect),
	RequestWireDisconnect = ensureRemoteEvent(remotesFolder, Config.RemoteWireDisconnect),
}

remotes.UnlockedExperimentIndex.Value = 1

SimulationService.SetRemotes(remotes)
BuildService.SetRemotes(remotes)
ExperimentService.SetRemotes(remotes)
WiringService.SetRemotes(remotes)

ActuatorService.SetControlProvider(function(componentId: string)
	return LogicService.GetActuatorControl(componentId)
end)
LogicService.SetActuatorSignalHandler(function(componentId: string, enabled: boolean)
	ActuatorService.SetActuatorSignal(componentId, enabled)
end)

-- 3. Requests -----------------------------------------------------------------

remotes.RequestSimulationAction.OnServerEvent:Connect(function(player: Player, payload: unknown)
	-- Funneled through the experiment layer, which knows that a finished
	-- experiment cannot be reset - only restarted.
	ExperimentService.HandleSimulationRequest(player, payload)
end)

remotes.RequestRotation.OnServerEvent:Connect(function(player: Player, payload: unknown)
	BuildService.RequestRotation(player, payload)
end)

remotes.RequestDisconnect.OnServerEvent:Connect(function(player: Player, payload: unknown)
	BuildService.RequestDisconnect(player, payload)
end)

remotes.RequestReturnToRack.OnServerEvent:Connect(function(player: Player, payload: unknown)
	BuildService.RequestReturnToRack(player, payload)
end)

remotes.RequestExperimentAction.OnServerEvent:Connect(function(player: Player, payload: unknown)
	ExperimentService.HandleExperimentRequest(player, payload)
end)

-- 4. The world -----------------------------------------------------------------

if Config.EnablePrototypeWorkshop then
	local runtime = PrototypeWorkshop.Setup()
	if runtime ~= nil then
		BuildService.AttachWorkshop(runtime)
	end
else
	-- The presentation layer hangs off the shell, and reads whatever state the
	-- server has already published, so it is built before the first experiment
	-- fills the bay.
	WorkshopPresentationService.Start(remotes)
	ExperimentService.Start()
end
