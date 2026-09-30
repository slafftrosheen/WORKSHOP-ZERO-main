--!strict

--[[
	BehaviourService

	Manages active physical behaviours during TEST phase for specialized
	construction components (e.g. Fan directional airflow thrust and reaction force).

	Architecture:
		* Motor rotational motion stays in ActuatorService.
		* Physical environmental forces (airflow, thrust, non-contact fields) live here.
		* Pure constraint forces: uses Roblox VectorForce primitives (no manual CFraming).
		* Single shared Heartbeat loop during TEST: mobile-friendly and O(active_components).
		* Strict cleanup on RESET and experiment transitions: zero orphan instances.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionMath = require(Shared.construction.ConstructionMath)

local ComponentFactory = require(script.Parent.ComponentFactory)
local ActuatorService = require(script.Parent.ActuatorService)

local Config = ConstructionConfig

local BehaviourService = {}

type ActiveFan = {
	Model: Model,
	Root: BasePart,
	ReactionAttachment: Attachment,
	ReactionForce: VectorForce,
}

local activeFans: { [string]: ActiveFan } = {}
local targetForces: { [BasePart]: { Attachment: Attachment, VectorForce: VectorForce } } = {}
local heartbeatConnection: RBXScriptConnection? = nil

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Fan] %s", message))
	end
end

-- Helper to ensure a target BasePart has a VectorForce for receiving airflow forces.
local function getOrCreateTargetForce(part: BasePart): VectorForce
	local existing = targetForces[part]
	if existing ~= nil and existing.VectorForce.Parent == part then
		return existing.VectorForce
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "WZ_AirflowAttachment"
	attachment.Parent = part

	local vectorForce = Instance.new("VectorForce")
	vectorForce.Name = "WZ_AirflowForce"
	vectorForce.Attachment0 = attachment
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.ApplyAtCenterOfMass = true
	vectorForce.Force = Vector3.zero
	vectorForce.Parent = part

	targetForces[part] = {
		Attachment = attachment,
		VectorForce = vectorForce,
	}

	return vectorForce
end

local function cleanupTargetForces()
	for _, record in targetForces do
		if record.VectorForce.Parent ~= nil then
			record.VectorForce:Destroy()
		end
		if record.Attachment.Parent ~= nil then
			record.Attachment:Destroy()
		end
	end
	table.clear(targetForces)
end

-- Collects payload root parts from the workspace.
local function findPayloadRoots(): { BasePart }
	local roots: { BasePart } = {}
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("Model") and instance:GetAttribute(Config.AttributePayload) == true then
			local primary = instance.PrimaryPart
			if primary ~= nil and primary.Parent ~= nil and not primary.Anchored then
				table.insert(roots, primary)
			end
		end
	end
	return roots
end

-- Lifecycle -------------------------------------------------------------------

--[[
	Called by SimulationService when entering TEST mode.
	Discovers powered fans and starts the airflow simulation loop.
]]
function BehaviourService.Start()
	BehaviourService.Stop()

	local minDot = math.cos(math.rad(Config.FanConeAngleDegrees))

	-- Discover powered fans
	for _, model in ComponentFactory.GetComponents() do
		local compType = ComponentFactory.GetComponentType(model)
		if compType == "Fan" then
			local componentId = ComponentFactory.GetComponentId(model)
			if componentId ~= nil then
				local actuator = ActuatorService.GetActuatorForComponent(componentId)
				if actuator ~= nil then
					local root = ComponentFactory.GetRoot(model)
					if root ~= nil and root.Parent ~= nil then
						local reactionAtt = Instance.new("Attachment")
						reactionAtt.Name = "WZ_FanReactionAttachment"
						reactionAtt.Parent = root

						local reactionForce = Instance.new("VectorForce")
						reactionForce.Name = "WZ_FanReactionForce"
						reactionForce.Attachment0 = reactionAtt
						reactionForce.RelativeTo = Enum.ActuatorRelativeTo.World
						reactionForce.ApplyAtCenterOfMass = true
						reactionForce.Force = Vector3.zero
						reactionForce.Parent = root

						activeFans[componentId] = {
							Model = model,
							Root = root,
							ReactionAttachment = reactionAtt,
							ReactionForce = reactionForce,
						}
					end
				end
			end
		end
	end

	local fanCount = 0
	for _ in activeFans do
		fanCount += 1
	end

	if fanCount == 0 then
		return
	end

	log(string.format("%d active fan(s) engaged", fanCount))

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		-- Collect all candidate targets: Duck payloads + unanchored construction components
		local candidateParts: { BasePart } = findPayloadRoots()

		for _, compModel in ComponentFactory.GetComponents() do
			local compType = ComponentFactory.GetComponentType(compModel)
			if compType ~= "Fan" then
				local root = ComponentFactory.GetRoot(compModel)
				if root ~= nil and root.Parent ~= nil and not root.Anchored then
					table.insert(candidateParts, root)
				end
			end
		end

		-- Reset forces for all active targets this step
		local accumulatedForces: { [BasePart]: Vector3 } = {}
		for _, part in candidateParts do
			accumulatedForces[part] = Vector3.zero
		end

		-- Process each active fan
		for _, fan in activeFans do
			if fan.Root.Parent ~= nil then
				-- Fan blows forward along its local X axis (+RightVector in Roblox CFrame convention)
				local forward = fan.Root.CFrame.RightVector
				local fanPos = fan.Root.Position

				-- Reaction thrust on the fan assembly (propeller car propulsion)
				fan.ReactionForce.Force = -forward * Config.FanThrustForce

				-- Aerodynamic airflow cone in front of the fan
				for _, target in candidateParts do
					if target.Parent ~= nil and not target.Anchored and target ~= fan.Root then
						local toTarget = target.Position - fanPos
						local distance = toTarget.Magnitude

						if distance > 0.5 and distance <= Config.FanMaxRange then
							local dir = toTarget.Unit
							local dot = forward:Dot(dir)

							local forceMagnitude = ConstructionMath.ComputeFanForce(
								distance,
								Config.FanMaxRange,
								dot,
								minDot,
								Config.FanBaseForce
							)

							if forceMagnitude > 0 then
								local windForce = forward * forceMagnitude
								accumulatedForces[target] = (
									accumulatedForces[target] or Vector3.zero
								) + windForce
							end
						end
					end
				end
			end
		end

		-- Apply accumulated forces to target parts via VectorForce
		for part, totalForce in accumulatedForces do
			if totalForce.Magnitude > 0.01 then
				local vf = getOrCreateTargetForce(part)
				vf.Force = totalForce
			else
				local existing = targetForces[part]
				if existing ~= nil then
					existing.VectorForce.Force = Vector3.zero
				end
			end
		end
	end)
end

--[[
	Called by SimulationService when leaving TEST mode (RESETTING).
	Stops airflow and reaction forces cleanly.
]]
function BehaviourService.Stop()
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	for _, fan in activeFans do
		if fan.ReactionForce.Parent ~= nil then
			fan.ReactionForce:Destroy()
		end
		if fan.ReactionAttachment.Parent ~= nil then
			fan.ReactionAttachment:Destroy()
		end
	end
	table.clear(activeFans)

	cleanupTargetForces()
end

--[[
	Called on experiment reload, restart, or level switch.
]]
function BehaviourService.Clear()
	BehaviourService.Stop()
	log("Cleared all active behaviours")
end

return table.freeze(BehaviourService)
