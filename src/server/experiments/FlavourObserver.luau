--!strict

--[[
	FlavourObserver

	One shared implementation of the "funny toast, at most once per attempt"
	rule that every experiment module used to copy for itself.

	It decides nothing about challenge state: firing a flavour event only
	produces a toast (and a Studio log line). The observer is cleared on
	Load / StartAttempt / RestoreToBuild / Restart, exactly like the per
	module `fired` tables it replaces.

	Module state (current definition, report, attempt number) is passed in
	as getters rather than values, because each experiment keeps those in
	module locals that change over the session.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local FlavourObserver = {}

export type Options = {
	GetDefinition: () -> ExperimentTypes.ExperimentDefinition,
	GetReport: () -> ExperimentTypes.ExperimentReport?,
	GetAttempt: () -> number,
	Log: ((message: string) -> ())?,
}

export type FlavourObserver = {
	-- Fires the event once per attempt: resolves the flavour line and
	-- routes it to the experiment report. Returns true when this call
	-- was the one that fired it.
	Fire: (eventId: ExperimentTypes.FailureEventId) -> boolean,
	IsFired: (eventId: ExperimentTypes.FailureEventId) -> boolean,
	-- Forgets everything: called wherever the modules used to clear
	-- their `fired` table.
	Clear: () -> (),
}

function FlavourObserver.Create(options: Options): FlavourObserver
	local fired: { [ExperimentTypes.FailureEventId]: boolean } = {}
	local log = options.Log

	local function fire(eventId: ExperimentTypes.FailureEventId): boolean
		if fired[eventId] then
			return false
		end

		fired[eventId] = true

		local definition = options.GetDefinition()
		local message =
			ExperimentDefinitions.FailureMessage(definition, eventId, options.GetAttempt())
		local report = options.GetReport()

		if report ~= nil and message ~= "" then
			report.Toast(message)
		end

		if log ~= nil then
			log(string.format("Flavour event %s: %s", eventId, message))
		end

		return true
	end

	local function isFired(eventId: ExperimentTypes.FailureEventId): boolean
		return fired[eventId] == true
	end

	local function clear()
		table.clear(fired)
	end

	return {
		Fire = fire,
		IsFired = isFired,
		Clear = clear,
	}
end

return table.freeze(FlavourObserver)
