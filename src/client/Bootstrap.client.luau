--!strict

--[[
	Bootstrap (client)

	Proves the client half of the development pipeline works:
	Rojo sync -> Roblox Studio -> local scripts run.

	It intentionally does nothing else.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectInfo = require(ReplicatedStorage.Shared.ProjectInfo)

print(string.format("[%s] Client bootstrap %s", ProjectInfo.InternalName, ProjectInfo.Version))
