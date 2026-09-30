--!strict

--[[
	Bootstrap (client)

	Proves the client half of the development pipeline works, then hands control
	to the construction client modules:

		1. find the network surface the server published
		2. build the control panel
		3. start the build controller

	The client owns input, presentation and preview only. Everything it sends is
	a request, and every answer comes back through the replicated state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)
local ProjectInfo = require(Shared.ProjectInfo)

local BuildController = require(script.Parent.construction.BuildController)
local PrototypeControls = require(script.Parent.ui.PrototypeControls)

local Config = ConstructionConfig
local WAIT_TIMEOUT = 30

print(string.format("[%s] Client bootstrap %s", ProjectInfo.InternalName, ProjectInfo.Version))

local function waitForRemoteEvent(parent: Instance, name: string): RemoteEvent?
	local child = parent:WaitForChild(name, WAIT_TIMEOUT)
	if child ~= nil and child:IsA("RemoteEvent") then
		return child
	end

	warn(string.format("[WZ] Missing remote event %q", name))

	return nil
end

local remotesFolder = ReplicatedStorage:WaitForChild(Config.RemotesFolderName, WAIT_TIMEOUT)
if remotesFolder == nil then
	warn(
		string.format(
			"[WZ] No %s folder: the construction kernel has no server to talk to",
			Config.RemotesFolderName
		)
	)

	return
end

local requestSimulationAction = waitForRemoteEvent(remotesFolder, Config.RemoteSimulationAction)
local requestRotation = waitForRemoteEvent(remotesFolder, Config.RemoteRotation)
local requestDisconnect = waitForRemoteEvent(remotesFolder, Config.RemoteDisconnect)
local dragStateChanged = waitForRemoteEvent(remotesFolder, Config.RemoteDragState)
local stateValue = remotesFolder:WaitForChild(Config.StateValueName, WAIT_TIMEOUT)

if
	requestSimulationAction == nil
	or requestRotation == nil
	or requestDisconnect == nil
	or dragStateChanged == nil
then
	return
end

if stateValue == nil or not stateValue:IsA("StringValue") then
	warn(string.format("[WZ] Missing %s state value", Config.StateValueName))

	return
end

local remotes: ConstructionTypes.ConstructionRemotes = {
	RequestSimulationAction = requestSimulationAction,
	RequestRotation = requestRotation,
	RequestDisconnect = requestDisconnect,
	DragStateChanged = dragStateChanged,
	SimulationState = stateValue,
}

local controls = PrototypeControls.Create({
	OnAction = function(action: ConstructionTypes.SimulationAction)
		remotes.RequestSimulationAction:FireServer(action)
	end,
})

BuildController.Start(remotes, controls)
