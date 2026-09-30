--!strict

--[[
	Bootstrap (client)

	Finds the network surface the server published, builds the control panel, and
	then hands control to the two client modules:

		BuildController       selection, rotation and disconnect requests, snap
		                      preview and snap feedback
		ExperimentController  intro card, toasts, parts list, success panel

	The client owns input, presentation and preview only. Everything it sends is
	a request, and every answer comes back through a replicated value.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)
local ProjectInfo = require(Shared.ProjectInfo)

local BuildController = require(script.Parent.construction.BuildController)
local ExperimentController = require(script.Parent.experiments.ExperimentController)
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

local function waitForStringValue(parent: Instance, name: string): StringValue?
	local child = parent:WaitForChild(name, WAIT_TIMEOUT)
	if child ~= nil and child:IsA("StringValue") then
		return child
	end

	warn(string.format("[WZ] Missing %s state value", name))

	return nil
end

local function waitForIntValue(parent: Instance, name: string): IntValue?
	local child = parent:WaitForChild(name, WAIT_TIMEOUT)
	if child ~= nil and child:IsA("IntValue") then
		return child
	end

	warn(string.format("[WZ] Missing %s value", name))

	return nil
end

local remotesFolder = ReplicatedStorage:WaitForChild(Config.RemotesFolderName, WAIT_TIMEOUT)
if remotesFolder == nil then
	warn(
		string.format(
			"[WZ] No %s folder: the client has no server to talk to",
			Config.RemotesFolderName
		)
	)

	return
end

local requestSimulationAction = waitForRemoteEvent(remotesFolder, Config.RemoteSimulationAction)
local requestRotation = waitForRemoteEvent(remotesFolder, Config.RemoteRotation)
local requestDisconnect = waitForRemoteEvent(remotesFolder, Config.RemoteDisconnect)
local dragStateChanged = waitForRemoteEvent(remotesFolder, Config.RemoteDragState)
local requestExperimentAction = waitForRemoteEvent(remotesFolder, Config.RemoteExperimentAction)
local failureToast = waitForRemoteEvent(remotesFolder, Config.RemoteFailureToast)

local simulationState = waitForStringValue(remotesFolder, Config.StateValueName)
local experimentState = waitForStringValue(remotesFolder, Config.ExperimentStateValueName)
local currentExperimentId = waitForStringValue(remotesFolder, Config.CurrentExperimentValueName)
local attemptValue = waitForIntValue(remotesFolder, Config.AttemptValueName)
local partsUsedValue = waitForIntValue(remotesFolder, Config.PartsUsedValueName)

if
	requestSimulationAction == nil
	or requestRotation == nil
	or requestDisconnect == nil
	or dragStateChanged == nil
	or requestExperimentAction == nil
	or failureToast == nil
	or simulationState == nil
	or experimentState == nil
	or currentExperimentId == nil
	or attemptValue == nil
	or partsUsedValue == nil
then
	return
end

local remotes: ExperimentTypes.ExperimentRemotes = {
	RequestSimulationAction = requestSimulationAction,
	RequestRotation = requestRotation,
	RequestDisconnect = requestDisconnect,
	DragStateChanged = dragStateChanged,
	SimulationState = simulationState,

	RequestExperimentAction = requestExperimentAction,
	FailureToast = failureToast,
	ExperimentState = experimentState,
	CurrentExperimentId = currentExperimentId,
	ExperimentAttempt = attemptValue,
	ExperimentPartsUsed = partsUsedValue,
}

-- The panel asks the controller to act on the current selection; it never
-- touches a component itself.
local controls = PrototypeControls.Create({
	OnAction = function(action)
		remotes.RequestSimulationAction:FireServer(action)
	end,
	OnRotate = function(operation)
		BuildController.RequestRotation(operation)
	end,
	OnDisconnect = function()
		BuildController.RequestDisconnect()
	end,
})

BuildController.Start(remotes, controls)
ExperimentController.Start(remotes, controls)
