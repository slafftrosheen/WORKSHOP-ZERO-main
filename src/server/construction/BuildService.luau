--!strict

--[[
	BuildService

	Everything that happens to a component while the machine is being built:
	dragging, rotation, disconnecting, and the build-area rules that keep the
	workshop meaningful.

	Server authority:

		* DragDetectors run on the server (RunLocally = false), so the server
		  performs the drag and receives DragStart / DragContinue / DragEnd.
		* Rotation and disconnect requests carry a ComponentId and a semantic
		  operation. The server resolves the component itself and never accepts
		  a CFrame, an instance or a constraint from a client.

	Whole-assembly manipulation: a component that is already connected belongs
	to an assembly, and moving one member moves the whole assembly with it. That
	keeps every joint's internal transform untouched during BUILD, so physics
	never has to correct a bent weld the moment TEST starts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)

local ComponentFactory = require(script.Parent.ComponentFactory)
local ConnectorService = require(script.Parent.ConnectorService)
local SimulationService = require(script.Parent.SimulationService)

local Config = ConstructionConfig

local BuildService = {}

type DragSession = {
	Model: Model,
	AnchorPivot: CFrame,
	Followers: { [Model]: CFrame },
}

local remotes: ConstructionTypes.ConstructionRemotes? = nil
local sessions: { [Model]: DragSession } = {}
local tracked: { [Model]: boolean } = {}
local lastValidPivots: { [Model]: CFrame } = {}
local boundsCenter = Vector3.zero
local boundsSize = Config.BuildBoundsSize

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ] %s", message))
	end
end

-- Setup ----------------------------------------------------------------------

function BuildService.SetRemotes(remoteSet: ConstructionTypes.ConstructionRemotes)
	remotes = remoteSet
end

function BuildService.SetBounds(center: Vector3, size: Vector3)
	boundsCenter = center
	boundsSize = size
end

--[[
	Binds the service to a runtime workshop: remembers the build area and starts
	watching every component inside it.
]]
function BuildService.AttachWorkshop(runtime: Instance)
	ComponentFactory.SetRuntime(runtime)

	local bounds = runtime:FindFirstChild(Config.BuildBoundsName)
	if bounds ~= nil and bounds:IsA("BasePart") then
		BuildService.SetBounds(bounds.Position, bounds.Size)
	end

	for _, model in ComponentFactory.GetComponents() do
		BuildService.Track(model)
	end
end

function BuildService.Track(model: Model)
	if tracked[model] then
		return
	end

	if not ComponentFactory.IsComponent(model) then
		return
	end

	local dragDetector = ComponentFactory.GetDragDetector(model)
	if dragDetector == nil then
		return
	end

	tracked[model] = true
	lastValidPivots[model] = model:GetPivot()

	dragDetector.DragStart:Connect(function(player: Player)
		BuildService.OnDragStart(model, player)
	end)

	dragDetector.DragContinue:Connect(function()
		BuildService.OnDragContinue(model)
	end)

	dragDetector.DragEnd:Connect(function(player: Player)
		BuildService.OnDragEnd(model, player)
	end)

	model.Destroying:Connect(function()
		tracked[model] = nil
		sessions[model] = nil
		lastValidPivots[model] = nil
	end)
end

-- Build area -----------------------------------------------------------------

local function isInsideBuildArea(position: Vector3): boolean
	local padding =
		Vector3.new(Config.BuildBoundsPadding, Config.BuildBoundsPadding, Config.BuildBoundsPadding)
	local half = boundsSize * 0.5 + padding
	local offset = position - boundsCenter

	return math.abs(offset.X) <= half.X
		and math.abs(offset.Y) <= half.Y
		and math.abs(offset.Z) <= half.Z
end

local function isWithinSafetyRadius(position: Vector3): boolean
	return (position - boundsCenter).Magnitude <= Config.MaxComponentDistance
end

local function isPlacementValid(models: { Model }): boolean
	for _, model in models do
		local position = model:GetPivot().Position
		if not isInsideBuildArea(position) or not isWithinSafetyRadius(position) then
			return false
		end
	end

	return true
end

local function pivotSnapshot(models: { Model }): { [Model]: CFrame }
	local result: { [Model]: CFrame } = {}
	for _, model in models do
		result[model] = model:GetPivot()
	end

	return result
end

local function restorePivots(pivots: { [Model]: CFrame })
	for model, pivot in pivots do
		if model.Parent ~= nil then
			model:PivotTo(pivot)
		end
	end
end

local function rememberValidPivots(models: { Model })
	for _, model in models do
		if model.Parent ~= nil then
			lastValidPivots[model] = model:GetPivot()
		end
	end
end

-- Assemblies -----------------------------------------------------------------

--[[
	Walks the connection registry from one component to everything mechanically
	joined to it. Axles count: a wheel held by a hinge still travels with the
	chassis it hangs from.
]]
function BuildService.GetAssembly(model: Model): { Model }
	local componentId = ComponentFactory.GetComponentId(model)
	if componentId == nil then
		return { model }
	end

	local visited: { [string]: boolean } = { [componentId] = true }
	local queue: { string } = { componentId }
	local result: { Model } = { model }

	while #queue > 0 do
		local currentId = table.remove(queue, 1) :: string

		for _, record in ConnectorService.GetFor(currentId) do
			local neighbourId = record.ComponentA
			if neighbourId == currentId then
				neighbourId = record.ComponentB
			end

			if neighbourId ~= currentId and not visited[neighbourId] then
				visited[neighbourId] = true

				local neighbour = ComponentFactory.FindComponentById(neighbourId)
				if neighbour ~= nil then
					table.insert(result, neighbour)
					table.insert(queue, neighbourId)
				end
			end
		end
	end

	return result
end

local function applyDeltaToMembers(members: { Model }, reference: Model, delta: CFrame)
	for _, member in members do
		if member ~= reference and member.Parent ~= nil then
			member:PivotTo(delta * member:GetPivot())
		end
	end
end

-- Dragging -------------------------------------------------------------------

function BuildService.OnDragStart(model: Model, player: Player)
	-- Self-healing: a state change can end a drag without a matching DragEnd.
	sessions[model] = nil

	if SimulationService.GetState() ~= "Build" then
		return
	end

	local followers: { [Model]: CFrame } = {}
	for _, member in BuildService.GetAssembly(model) do
		if member ~= model then
			followers[member] = member:GetPivot()
		end
	end

	sessions[model] = {
		Model = model,
		AnchorPivot = model:GetPivot(),
		Followers = followers,
	}

	if remotes ~= nil then
		remotes.DragStateChanged:FireClient(player, ComponentFactory.GetComponentId(model))
	end

	log(string.format("%s picked up %s", player.Name, model.Name))
end

function BuildService.OnDragContinue(model: Model)
	local session = sessions[model]
	if session == nil then
		return
	end

	-- Move the rest of the assembly with the part the player is holding, so no
	-- joint is stretched while dragging.
	local delta = model:GetPivot() * session.AnchorPivot:Inverse()
	for follower, startPivot in session.Followers do
		if follower.Parent ~= nil then
			follower:PivotTo(delta * startPivot)
		end
	end
end

--[[
	DragEnd is where a placement becomes real:

		1. reject a placement outside the build area and put it back
		2. look for a compatible free connector pair and snap to it
		3. carry the rest of the assembly through the snap correction
		4. remember the resulting transforms as the new "last valid" state
]]
function BuildService.OnDragEnd(model: Model, player: Player)
	local session = sessions[model]
	sessions[model] = nil

	if remotes ~= nil then
		remotes.DragStateChanged:FireClient(player, nil)
	end

	if session == nil or SimulationService.GetState() ~= "Build" then
		return
	end

	local members: { Model } = { model }
	for follower in session.Followers do
		table.insert(members, follower)
	end

	if not isPlacementValid(members) then
		for _, member in members do
			local valid = lastValidPivots[member]
			if valid ~= nil then
				member:PivotTo(valid)
			end
		end

		log(
			string.format(
				"%s tried to drop %s outside the build area - returned to its last valid spot",
				player.Name,
				model.Name
			)
		)
		return
	end

	local candidate = ConnectorService.FindCandidate(model)
	if candidate ~= nil then
		local anchorBefore = model:GetPivot()
		local record = ConnectorService.Snap(model, candidate)

		if record ~= nil then
			-- Carry the rest of the assembly through the snap correction too, so
			-- the joints that already existed keep their exact transforms.
			local snapDelta = model:GetPivot() * anchorBefore:Inverse()
			applyDeltaToMembers(members, model, snapDelta)
		end
	end

	rememberValidPivots(members)
end

-- Rotation -------------------------------------------------------------------

local function rotationFor(operation: ConstructionTypes.RotationOperation): CFrame
	if operation == "YawLeft" then
		return CFrame.Angles(0, math.rad(-Config.YawStepDegrees), 0)
	end

	if operation == "YawRight" then
		return CFrame.Angles(0, math.rad(Config.YawStepDegrees), 0)
	end

	return CFrame.Angles(math.rad(Config.FlipDegrees), 0, 0)
end

local function parseComponentRequest(payload: unknown): string?
	if type(payload) ~= "table" then
		return nil
	end

	local componentId = (payload :: { [string]: unknown }).ComponentId
	if type(componentId) ~= "string" then
		return nil
	end

	return componentId :: string
end

local function parseRotationRequest(
	payload: unknown
): (string?, ConstructionTypes.RotationOperation?)
	if type(payload) ~= "table" then
		return nil, nil
	end

	local request = payload :: { [string]: unknown }
	local componentId = request.ComponentId
	local operation = ConstructionTypes.ToRotationOperation(request.Operation)

	if type(componentId) ~= "string" or operation == nil then
		return nil, nil
	end

	return componentId :: string, operation
end

function BuildService.RequestRotation(player: Player, payload: unknown): boolean
	if SimulationService.GetState() ~= "Build" then
		return false
	end

	local componentId, operation = parseRotationRequest(payload)
	if componentId == nil or operation == nil then
		return false
	end

	local model = ComponentFactory.FindComponentById(componentId)
	if model == nil then
		return false
	end

	local members = BuildService.GetAssembly(model)
	local before = pivotSnapshot(members)
	local pivot = model:GetPivot()
	local step = rotationFor(operation)

	model:PivotTo(pivot * step)
	applyDeltaToMembers(members, model, model:GetPivot() * pivot:Inverse())

	if not isPlacementValid(members) then
		restorePivots(before)
		log(string.format("Rotating %s would leave the build area", model.Name))
		return false
	end

	rememberValidPivots(members)
	log(string.format("%s rotated %s (%s)", player.Name, model.Name, operation))

	return true
end

-- Disconnecting --------------------------------------------------------------

function BuildService.RequestDisconnect(player: Player, payload: unknown): boolean
	if SimulationService.GetState() ~= "Build" then
		return false
	end

	local componentId = parseComponentRequest(payload)
	if componentId == nil then
		return false
	end

	local model = ComponentFactory.FindComponentById(componentId)
	if model == nil then
		return false
	end

	local removed = ConnectorService.Disconnect(componentId)
	log(string.format("%s disconnected %s (%d joint(s))", player.Name, model.Name, removed))

	return true
end

return table.freeze(BuildService)
