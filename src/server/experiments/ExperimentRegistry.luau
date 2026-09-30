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

local registry: { [string]: ExperimentTypes.ExperimentModule } = {
	save_the_duck = SaveTheDuckExperiment,
	uphill_delivery = UphillDeliveryExperiment,
	over_the_wall = OverTheWallExperiment,
	windy_business = WindyBusinessExperiment,
}

local ExperimentRegistry = {}

function ExperimentRegistry.Get(id: string): ExperimentTypes.ExperimentModule?
	return registry[id]
end

return table.freeze(ExperimentRegistry)
