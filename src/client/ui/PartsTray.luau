--!strict

--[[
	PartsTray

	The parts list, and nothing more. Parts are real objects sitting on a rack in
	the world, so this panel is informational: it answers "what have I got?" at a
	glance without pretending to be an inventory the player drags from.

	It reads the same experiment definition the server used to build the rack,
	so the panel can never promise a part the level did not stage.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ComponentDefinitions = require(Shared.construction.ComponentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local player = Players.LocalPlayer

local PartsTray = {}

local ROW_HEIGHT = 26
local SWATCH = 18

local function createSwatch(parent: Instance, componentType: string, layoutOrder: number): Frame
	local definition = ComponentDefinitions.Get(componentType)
	local color = if definition ~= nil then definition.Color else Color3.fromRGB(150, 150, 150)

	local swatch = Instance.new("Frame")
	swatch.Name = componentType
	swatch.LayoutOrder = layoutOrder
	swatch.Size = UDim2.fromOffset(SWATCH, SWATCH)
	swatch.BackgroundColor3 = color
	swatch.BorderSizePixel = 0
	swatch.Parent = parent

	local corner = Instance.new("UICorner")
	-- A wheel reads as a wheel; everything else keeps a soft square corner.
	corner.CornerRadius = if componentType == "Wheel" then UDim.new(1, 0) else UDim.new(0, 4)
	corner.Parent = swatch

	return swatch
end

export type PartsTrayHandle = {
	SetDefinition: (definition: ExperimentTypes.ExperimentDefinition) -> (),
	Destroy: () -> (),
}

local function populateRows(panel: Frame, definition: ExperimentTypes.ExperimentDefinition)
	for _, child in panel:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, requirement in definition.Inventory do
		local row = Instance.new("Frame")
		row.Name = requirement.ComponentType
		row.LayoutOrder = index + 1
		row.Size = UDim2.fromOffset(0, ROW_HEIGHT)
		row.AutomaticSize = Enum.AutomaticSize.X
		row.BackgroundTransparency = 1
		row.Parent = panel

		local rowList = Instance.new("UIListLayout")
		rowList.FillDirection = Enum.FillDirection.Horizontal
		rowList.VerticalAlignment = Enum.VerticalAlignment.Center
		rowList.SortOrder = Enum.SortOrder.LayoutOrder
		rowList.Padding = UDim.new(0, 8)
		rowList.Parent = row

		createSwatch(row, requirement.ComponentType, 1)

		local label = Instance.new("TextLabel")
		label.Name = "Count"
		label.LayoutOrder = 2
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 15
		label.TextColor3 = Color3.fromRGB(226, 230, 240)
		label.Text = string.format("%s ×%d", requirement.ComponentType:upper(), requirement.Count)
		label.Parent = row
	end
end

function PartsTray.Create(definition: ExperimentTypes.ExperimentDefinition): PartsTrayHandle
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "WorkshopZeroParts"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Tray"
	panel.Position = UDim2.fromOffset(16, 16)
	panel.AutomaticSize = Enum.AutomaticSize.XY
	panel.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	panel.BackgroundTransparency = 0.18
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = panel

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.LayoutOrder = 1
	title.AutomaticSize = Enum.AutomaticSize.XY
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.TextColor3 = Color3.fromRGB(150, 156, 170)
	title.Text = "PARTS"
	title.Parent = panel

	populateRows(panel, definition)

	return {
		SetDefinition = function(newDefinition: ExperimentTypes.ExperimentDefinition)
			populateRows(panel, newDefinition)
		end,
		Destroy = function()
			gui:Destroy()
		end,
	}
end

return table.freeze(PartsTray)
