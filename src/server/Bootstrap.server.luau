--!strict

--[[
	Bootstrap (server)

	Proves the server half of the development pipeline works:
	Rojo sync -> Roblox Studio -> server scripts run.

	It intentionally does nothing else. No framework, no game architecture,
	no networking layer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectInfo = require(ReplicatedStorage.Shared.ProjectInfo)

print(string.format("[%s] Server bootstrap %s", ProjectInfo.InternalName, ProjectInfo.Version))
