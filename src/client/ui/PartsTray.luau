--!strict

--[[
	PartsTray

	The top-left HUD panel showing:
		* Current Experiment number, name, and short objective
		* Sleek "☰ EXPERIMENTS" button to open the Experiment Board
		* Staged parts inventory on the rack

	Hidden during TEST mode so the world becomes primary.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ComponentDefinitions = require(Shared.construction.ComponentDefinitions)
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local player = Players.LocalPlayer

local PartsTray = {}

local ROW_HEIGHT = 26
local SWATCH = 18

export type PartsTrayHandle = {
	SetDefinition: (definition: ExperimentTypes.ExperimentDefinition) -> (),
	SetVisible: (visible: boolean) -> (),
	Destroy: () -> (),
}

--[[
	Free build is not a numbered experiment, so it does not get the
	"EXPERIMENT 000" line. The id check (not the Number field) is the
	authoritative "this is Open Workshop" test everywhere.
]]
local function titleFor(definition: ExperimentTypes.ExperimentDefinition): string
	if not ExperimentDefinitions.IsOpenWorkshopId(definition.Id) then
		return string.format("EXPERIMENT %03d: %s", definition.Number, definition.Name)
	end

	return definition.Name
end

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
	corner.CornerRadius = if componentType == "Wheel" then UDim.new(1, 0) else UDim.new(0, 4)
	corner.Parent = swatch

	return swatch
end

local function populateRows(container: Instance, definition: ExperimentTypes.ExperimentDefinition)
	for _, child in container:GetChildren() do
		if child:IsA("Frame") and string.find(child.Name, "^PartRow_") ~= nil then
			child:Destroy()
		end
	end

	for index, requirement in definition.Inventory do
		local row = Instance.new("Frame")
		row.Name = string.format("PartRow_%s", requirement.ComponentType)
		row.LayoutOrder = 10 + index
		row.Size = UDim2.fromOffset(0, ROW_HEIGHT)
		row.AutomaticSize = Enum.AutomaticSize.X
		row.BackgroundTransparency = 1
		row.Parent = container

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
		label.TextSize = 14
		label.TextColor3 = Color3.fromRGB(226, 230, 240)
		label.Text = string.format("%s ×%d", requirement.ComponentType:upper(), requirement.Count)
		label.Parent = row
	end
end

function PartsTray.Create(
	definition: ExperimentTypes.ExperimentDefinition,
	onOpenBoard: (() -> ())?,
	onClear: (() -> ())?
): PartsTrayHandle
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
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = panel

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = panel

	-- Top header: Experiment badge and selector button
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.LayoutOrder = 1
	header.AutomaticSize = Enum.AutomaticSize.XY
	header.BackgroundTransparency = 1
	header.Parent = panel

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Padding = UDim.new(0, 12)
	headerLayout.Parent = header

	local infoBox = Instance.new("Frame")
	infoBox.Name = "InfoBox"
	infoBox.LayoutOrder = 1
	infoBox.AutomaticSize = Enum.AutomaticSize.XY
	infoBox.BackgroundTransparency = 1
	infoBox.Parent = header

	local infoLayout = Instance.new("UIListLayout")
	infoLayout.FillDirection = Enum.FillDirection.Vertical
	infoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	infoLayout.Padding = UDim.new(0, 2)
	infoLayout.Parent = infoBox

	local expTitle = Instance.new("TextLabel")
	expTitle.Name = "ExpTitle"
	expTitle.LayoutOrder = 1
	expTitle.AutomaticSize = Enum.AutomaticSize.XY
	expTitle.BackgroundTransparency = 1
	expTitle.Font = Enum.Font.GothamBold
	expTitle.TextSize = 13
	expTitle.TextColor3 = Color3.fromRGB(255, 214, 92)
	expTitle.TextXAlignment = Enum.TextXAlignment.Left
	expTitle.Text = titleFor(definition)
	expTitle.Parent = infoBox

	local expObjective = Instance.new("TextLabel")
	expObjective.Name = "ExpObjective"
	expObjective.LayoutOrder = 2
	expObjective.AutomaticSize = Enum.AutomaticSize.XY
	expObjective.BackgroundTransparency = 1
	expObjective.Font = Enum.Font.GothamMedium
	expObjective.TextSize = 11
	expObjective.TextColor3 = Color3.fromRGB(180, 186, 200)
	expObjective.TextXAlignment = Enum.TextXAlignment.Left
	expObjective.Text = definition.Objective
	expObjective.Parent = infoBox

	if onOpenBoard ~= nil then
		local boardBtn = Instance.new("TextButton")
		boardBtn.Name = "BoardBtn"
		boardBtn.LayoutOrder = 2
		boardBtn.Size = UDim2.fromOffset(104, 26)
		boardBtn.BackgroundColor3 = Color3.fromRGB(48, 54, 68)
		boardBtn.BorderSizePixel = 0
		boardBtn.Font = Enum.Font.GothamBold
		boardBtn.TextSize = 11
		boardBtn.TextColor3 = Color3.fromRGB(240, 244, 255)
		boardBtn.Text = "☰ EXPERIMENTS"
		boardBtn.Parent = header

		local boardBtnCorner = Instance.new("UICorner")
		boardBtnCorner.CornerRadius = UDim.new(0, 6)
		boardBtnCorner.Parent = boardBtn

		boardBtn.Activated:Connect(function()
			onOpenBoard()
		end)
	end

	-- CLEAR WORKSHOP exists only in free build. It is the ordinary
	-- experiment-layer restart wearing a label a child can read, so the rack
	-- comes back clean without a second cleanup path.
	local clearButton: TextButton? = nil
	if onClear ~= nil then
		local button = Instance.new("TextButton")
		button.Name = "ClearBtn"
		button.LayoutOrder = 3
		button.Size = UDim2.fromOffset(122, 26)
		button.BackgroundColor3 = Color3.fromRGB(96, 58, 44)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextSize = 10
		button.TextColor3 = Color3.fromRGB(250, 236, 226)
		button.Text = "CLEAR WORKSHOP"
		button.Visible = ExperimentDefinitions.IsOpenWorkshopId(definition.Id)
		button.Parent = header

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 6)
		buttonCorner.Parent = button

		button.Activated:Connect(function()
			onClear()
		end)

		clearButton = button
	end

	-- Divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.LayoutOrder = 2
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.BackgroundColor3 = Color3.fromRGB(48, 52, 64)
	divider.BorderSizePixel = 0
	divider.Parent = panel

	-- "PARTS" subheader
	local partsHeader = Instance.new("TextLabel")
	partsHeader.Name = "PartsHeader"
	partsHeader.LayoutOrder = 3
	partsHeader.AutomaticSize = Enum.AutomaticSize.XY
	partsHeader.BackgroundTransparency = 1
	partsHeader.Font = Enum.Font.GothamBold
	partsHeader.TextSize = 11
	partsHeader.TextColor3 = Color3.fromRGB(150, 156, 170)
	partsHeader.Text = "PARTS"
	partsHeader.Parent = panel

	populateRows(panel, definition)

	return {
		SetDefinition = function(newDefinition: ExperimentTypes.ExperimentDefinition)
			expTitle.Text = titleFor(newDefinition)
			expObjective.Text = newDefinition.Objective
			populateRows(panel, newDefinition)

			if clearButton ~= nil then
				clearButton.Visible = ExperimentDefinitions.IsOpenWorkshopId(newDefinition.Id)
			end
		end,
		SetVisible = function(visible: boolean)
			gui.Enabled = visible
		end,
		Destroy = function()
			gui:Destroy()
		end,
	}
end

return table.freeze(PartsTray)
