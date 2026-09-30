--!strict

--[[
	ProjectInfo

	The small, immutable set of facts about Workshop Zero that both the server
	and the client agree on.

	Keep this module boring. It is the first thing every future module reads,
	so if it ever needs to change, it should change in one obvious place.
]]

local ProjectInfo = {
	Name = "Workshop Zero",
	InternalName = "WorkshopZero",
	Version = "0.0.1-dev",
	Prototype = true,
}

table.freeze(ProjectInfo)

return ProjectInfo
