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

local registry: { [string]: ExperimentTypes.ExperimentModule } = {
	save_the_duck = SaveTheDuckExperiment,
}

local ExperimentRegistry = {}

function ExperimentRegistry.Get(id: string): ExperimentTypes.ExperimentModule?
	return registry[id]
end

return table.freeze(ExperimentRegistry)
