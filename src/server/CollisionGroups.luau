--!strict

--[[
	CollisionGroups

	Five groups, no more. The point is that a player can never solve, break or
	accidentally trigger an experiment by walking into it, while the machine
	itself still collides with everything it should.

	Matrix (true = they collide):

	                              Player  Comp  Payload  Env   Trigger
	    Players                    yes    no     no      yes    no
	    WorkshopComponents          no    yes    yes     yes    yes
	    Payloads                    no    yes    yes     yes    yes
	    Environment                yes    yes    yes     yes    yes
	    GoalTrigger                 no    yes    yes     yes    no

	Notes:

		* Players pass through components and the payload, so nobody can kick a
		  machine apart or shove the duck by walking into it. Players are never
		  anchored.
		* The goal trigger is group-collidable with components and payloads so
		  Touched fires for both, and the handler decides which one counts. It
		  cannot collide physically because it has CanCollide = false.
		* The trigger does not collide with players at all: two barriers are
		  better than one.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConstructionConfig = require(ReplicatedStorage.Shared.construction.ConstructionConfig)

local Config = ConstructionConfig

local CollisionGroups = {}

type MatrixEntry = {
	GroupA: string,
	GroupB: string,
	Collidable: boolean,
}

local ALL_GROUPS: { string } = {
	Config.CollisionGroupPlayers,
	Config.CollisionGroupComponents,
	Config.CollisionGroupPayloads,
	Config.CollisionGroupEnvironment,
	Config.CollisionGroupGoalTrigger,
}

local MATRIX: { MatrixEntry } = {
	-- Players
	{
		GroupA = Config.CollisionGroupPlayers,
		GroupB = Config.CollisionGroupPlayers,
		Collidable = true,
	},
	{
		GroupA = Config.CollisionGroupPlayers,
		GroupB = Config.CollisionGroupComponents,
		Collidable = false,
	},
	{
		GroupA = Config.CollisionGroupPlayers,
		GroupB = Config.CollisionGroupPayloads,
		Collidable = false,
	},
	{
		GroupA = Config.CollisionGroupPlayers,
		GroupB = Config.CollisionGroupEnvironment,
		Collidable = true,
	},
	{
		GroupA = Config.CollisionGroupPlayers,
		GroupB = Config.CollisionGroupGoalTrigger,
		Collidable = false,
	},

	-- Components
	{
		GroupA = Config.CollisionGroupComponents,
		GroupB = Config.CollisionGroupComponents,
		Collidable = true,
	},
	{
		GroupA = Config.CollisionGroupComponents,
		GroupB = Config.CollisionGroupPayloads,
		Collidable = true,
	},
	{
		GroupA = Config.CollisionGroupComponents,
		GroupB = Config.CollisionGroupEnvironment,
		Collidable = true,
	},
	{
		GroupA = Config.CollisionGroupComponents,
		GroupB = Config.CollisionGroupGoalTrigger,
		Collidable = true,
	},

	-- Payloads
	{
		GroupA = Config.CollisionGroupPayloads,
		GroupB = Config.CollisionGroupPayloads,
		Collidable = true,
	},
	{
		GroupA = Config.CollisionGroupPayloads,
		GroupB = Config.CollisionGroupEnvironment,
		Collidable = true,
	},
	{
		GroupA = Config.CollisionGroupPayloads,
		GroupB = Config.CollisionGroupGoalTrigger,
		Collidable = true,
	},

	-- Environment and trigger
	{
		GroupA = Config.CollisionGroupEnvironment,
		GroupB = Config.CollisionGroupEnvironment,
		Collidable = true,
	},
	{
		GroupA = Config.CollisionGroupEnvironment,
		GroupB = Config.CollisionGroupGoalTrigger,
		Collidable = true,
	},
	{
		GroupA = Config.CollisionGroupGoalTrigger,
		GroupB = Config.CollisionGroupGoalTrigger,
		Collidable = false,
	},
}

function CollisionGroups.Setup()
	for _, groupName in ALL_GROUPS do
		if not PhysicsService:IsCollisionGroupRegistered(groupName) then
			PhysicsService:RegisterCollisionGroup(groupName)
		end
	end

	for _, entry in MATRIX do
		PhysicsService:CollisionGroupSetCollidable(entry.GroupA, entry.GroupB, entry.Collidable)
	end
end

function CollisionGroups.AssignCharacter(character: Model)
	local function assign(instance: Instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = Config.CollisionGroupPlayers
		end
	end

	for _, descendant in character:GetDescendants() do
		assign(descendant)
	end

	-- Accessories, tools and anything else attached later.
	character.DescendantAdded:Connect(assign)
end

function CollisionGroups.TrackPlayers()
	local function trackPlayer(player: Player)
		player.CharacterAdded:Connect(CollisionGroups.AssignCharacter)

		if player.Character ~= nil then
			CollisionGroups.AssignCharacter(player.Character)
		end
	end

	Players.PlayerAdded:Connect(trackPlayer)

	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
end

return table.freeze(CollisionGroups)
