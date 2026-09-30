--!strict

--[[
	Bootstrap (server)

	Proves the server half of the development pipeline works and wires up the
	construction kernel in one readable place:

		1. create the client-facing network surface
		2. hand it to the simulation and build services
		3. build the Studio-only prototype workshop
		4. attach the build service to that workshop

	No framework, no service locator, no event bus: four modules, wired once.
	The server owns every decision; clients request actions and read state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)
local ProjectInfo = require(Shared.ProjectInfo)

local BuildService = require(script.Parent.construction.BuildService)
local SimulationService = require(script.Parent.construction.SimulationService)
local PrototypeWorkshop = require(script.Parent.dev.PrototypeWorkshop)

local Config = ConstructionConfig

print(string.format("[%s] Server bootstrap %s", ProjectInfo.InternalName, ProjectInfo.Version))

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

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = Config.RemotesFolderName
remotesFolder.Parent = ReplicatedStorage

--[[
	The network surface, kept deliberately small:

		RequestSimulationAction   client -> server   "Test" | "Reset"
		RequestRotation           client -> server   { ComponentId, Operation }
		RequestDisconnect         client -> server   { ComponentId }
		DragStateChanged          server -> client   componentId | nil
		SimulationState           replicated value   the authoritative state

	Simulation state is a value rather than an event so a player who joins in
	the middle of a test immediately reads "Testing" instead of waiting for the
	next broadcast.
]]
local remotes: ConstructionTypes.ConstructionRemotes = {
	RequestSimulationAction = ensureRemoteEvent(remotesFolder, Config.RemoteSimulationAction),
	RequestRotation = ensureRemoteEvent(remotesFolder, Config.RemoteRotation),
	RequestDisconnect = ensureRemoteEvent(remotesFolder, Config.RemoteDisconnect),
	DragStateChanged = ensureRemoteEvent(remotesFolder, Config.RemoteDragState),
	SimulationState = ensureStringValue(remotesFolder, Config.StateValueName),
}

SimulationService.SetRemotes(remotes)
BuildService.SetRemotes(remotes)

remotes.RequestSimulationAction.OnServerEvent:Connect(function(player: Player, payload: unknown)
	SimulationService.RequestAction(player, payload)
end)

remotes.RequestRotation.OnServerEvent:Connect(function(player: Player, payload: unknown)
	BuildService.RequestRotation(player, payload)
end)

remotes.RequestDisconnect.OnServerEvent:Connect(function(player: Player, payload: unknown)
	BuildService.RequestDisconnect(player, payload)
end)

local runtime = PrototypeWorkshop.Setup()
if runtime ~= nil then
	BuildService.AttachWorkshop(runtime)
end
