--!strict

--[[
	SimulationService

	The single authority for which phase the workshop is in:

		Build      components anchored, draggable, joints frozen
		Testing    components unanchored, physics owns the machine
		Resetting  components anchored again, transforms being restored

	Only this module changes the state. Clients read it from a replicated
	StringValue, so a late joiner always sees the truth instead of missing a
	broadcast.

	TEST is a snapshot, not a rebuild: the machine is never reconstructed on
	RESET, only returned to the exact transforms it had before physics started.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ConstructionTypes = require(Shared.construction.ConstructionTypes)

local ComponentFactory = require(script.Parent.ComponentFactory)
local ConnectorService = require(script.Parent.ConnectorService)

local SimulationService = {}

-- One observer slot, not an event bus. The experiment layer watches the
-- simulation; nothing else does.
type Observer = {
	OnStateChanged: (
		previous: ConstructionTypes.SimulationState,
		current: ConstructionTypes.SimulationState
	) -> (),
}

local state: ConstructionTypes.SimulationState = "Build"
local snapshot: { [string]: ConstructionTypes.ComponentSnapshot } = {}
local remotes: ConstructionTypes.ConstructionRemotes? = nil
local observer: Observer? = nil

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ] %s", message))
	end
end

local function publish()
	if remotes ~= nil then
		remotes.SimulationState.Value = state
	end
end

local function setState(newState: ConstructionTypes.SimulationState)
	local previous = state
	state = newState
	publish()
	log(string.format("State %s -> %s", previous, newState))

	if observer ~= nil then
		local notify = observer.OnStateChanged
		notify(previous, newState)
	end
end

local function zeroVelocities()
	for _, model in ComponentFactory.GetComponents() do
		local root = ComponentFactory.GetRoot(model)
		if root ~= nil then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

--[[
	Captures what RESET has to restore.

	Velocities are recorded for diagnostics only: RESET deliberately zeroes them
	instead of restoring them, so a repeatable TEST always starts from rest.
]]
local function captureSnapshot()
	snapshot = {}

	for _, model in ComponentFactory.GetComponents() do
		local componentId = ComponentFactory.GetComponentId(model)
		local root = ComponentFactory.GetRoot(model)
		if componentId ~= nil and root ~= nil then
			snapshot[componentId] = {
				ComponentId = componentId,
				Pivot = model:GetPivot(),
				LinearVelocity = root.AssemblyLinearVelocity,
				AngularVelocity = root.AssemblyAngularVelocity,
				Anchored = root.Anchored,
			}
		end
	end
end

local function restoreSnapshot()
	for componentId, entry in snapshot do
		local model = ComponentFactory.FindComponentById(componentId)
		if model ~= nil then
			model:PivotTo(entry.Pivot)
		end
	end
end

-- Public API -----------------------------------------------------------------

function SimulationService.GetState(): ConstructionTypes.SimulationState
	return state
end

function SimulationService.SetRemotes(remoteSet: ConstructionTypes.ConstructionRemotes)
	remotes = remoteSet
	publish()
end

--[[
	Registers the single observer of phase changes.

	The experiment layer uses this to react to TEST and RESET without owning any
	physics state of its own: SimulationState stays the only truth about what the
	workshop is doing.
]]
function SimulationService.SetObserver(value: Observer?)
	observer = value
end

function SimulationService.RequestAction(player: Player, payload: unknown): boolean
	local action = ConstructionTypes.ToSimulationAction(payload)
	if action == nil then
		return false
	end

	if action == "Test" then
		return SimulationService.StartTest(player)
	end

	return SimulationService.ResetToBuild(player)
end

--[[
	Build -> Testing.

	Everything is captured first, then components are unanchored and left alone:
	after this point Roblox physics owns the motion and nothing here manually
	integrates gravity or velocity.
]]
function SimulationService.StartTest(player: Player): boolean
	if state ~= "Build" then
		return false
	end

	captureSnapshot()
	setState("Testing")
	ComponentFactory.SetDraggingEnabled(false)
	ComponentFactory.SetComponentsAnchored(false)
	ComponentFactory.SetConnectorMarkersVisible(false)
	zeroVelocities() -- The joint count is printed on purpose: "no duplicate constraints" is an
	-- acceptance condition, and this is the cheapest way for a human to watch it.
	log(
		string.format(
			"%s started a test: %d component(s), %d joint(s)",
			player.Name,
			#ComponentFactory.GetComponents(),
			ConnectorService.GetCount()
		)
	)

	return true
end

--[[
	Testing -> Resetting -> Build.

	Anchor first so constraints cannot move anything while transforms are being
	restored, zero velocities on both sides of the restore so the machine starts
	the next build from rest, then hand interaction back to the player.

	Constraints are never recreated, so repeated TEST/RESET cannot accumulate
	joints.
]]
function SimulationService.ResetToBuild(player: Player): boolean
	if state ~= "Testing" then
		return false
	end

	setState("Resetting")
	ComponentFactory.SetComponentsAnchored(true)
	zeroVelocities()
	restoreSnapshot()

	-- Give the anchored parts one physics step to settle before leaving the
	-- resetting state, so nothing is still being corrected when Build resumes.
	RunService.Heartbeat:Wait()
	zeroVelocities()

	snapshot = {}
	ComponentFactory.SetDraggingEnabled(true)
	ComponentFactory.SetConnectorMarkersVisible(true)
	setState("Build")

	log(
		string.format(
			"%s reset the machine: %d joint(s) still intact",
			player.Name,
			ConnectorService.GetCount()
		)
	)

	return true
end

return table.freeze(SimulationService)
