--!strict

--[[
	ExperimentRegistry

	Minimal registry mapping experiment IDs to their server implementations.
	Responsibilities:
		* lookup experiment implementation by ID
		Nothing more.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local SaveTheDuckExperiment = require(script.Parent.SaveTheDuckExperiment)
local UphillDeliveryExperiment = require(script.Parent.UphillDeliveryExperiment)
local OverTheWallExperiment = require(script.Parent.OverTheWallExperiment)
local WindyBusinessExperiment = require(script.Parent.WindyBusinessExperiment)
local LiftOffExperiment = require(script.Parent.LiftOffExperiment)
local DontHitTheWallExperiment = require(script.Parent.DontHitTheWallExperiment)
local TwoToGoExperiment = require(script.Parent.TwoToGoExperiment)
local OpenSesameExperiment = require(script.Parent.OpenSesameExperiment)
local OpenWorkshopExperiment = require(script.Parent.OpenWorkshopExperiment)

local registry: { [string]: ExperimentTypes.ExperimentModule } = {
	save_the_duck = SaveTheDuckExperiment,
	uphill_delivery = UphillDeliveryExperiment,
	over_the_wall = OverTheWallExperiment,
	windy_business = WindyBusinessExperiment,
	lift_off = LiftOffExperiment,
	dont_hit_the_wall = DontHitTheWallExperiment,
	two_to_go = TwoToGoExperiment,
	open_sesame = OpenSesameExperiment,
	-- Free build. Registered here so it loads like any other mode, but never
	-- listed in ExperimentDefinitions.GetOrdered(), so it stays out of the
	-- numbered sequence.
	open_workshop = OpenWorkshopExperiment,
}

local ExperimentRegistry = {}

function ExperimentRegistry.Get(id: string): ExperimentTypes.ExperimentModule?
	return registry[id]
end

return table.freeze(ExperimentRegistry)
