--!strict

--[[
	PrototypeControls

	A deliberately plain control panel: one action button, one state line, one
	hint line. No framework, no animation, no art.

	The panel decides nothing. It reports a press through OnAction and renders
	whatever state the caller hands it, so the server stays the only thing that
	knows whether the workshop is building or testing.

	Built at runtime on purpose: this is a prototype, and a ScreenGui created by
	code cannot drift away from the code that fills it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ConstructionTypes = require(Shared.construction.ConstructionTypes)

local player = Players.LocalPlayer

local PrototypeControls = {}

export type Config = {
	OnAction: (action: ConstructionTypes.SimulationAction) -> (),
}

export type Handle = {
	SetState: (state: ConstructionTypes.SimulationState) -> (),
	SetSelection: (name: string?) -> (),
	IsPointerOverPanel: (position: Vector3) -> boolean,
}

local BUILD_HINT = "Tap a part to select it"
local SELECTED_HINT = "Q / E rotate     R flip     X disconnect"

local BUTTON_COLORS = {
	Test = Color3.fromRGB(52, 132, 84),
	Reset = Color3.fromRGB(154, 96, 44),
	Busy = Color3.fromRGB(78, 82, 92),
}

local STATE_COLORS = {
	Build = Color3.fromRGB(140, 220, 170),
	Testing = Color3.fromRGB(255, 196, 120),
	Resetting = Color3.fromRGB(180, 200, 230),
}

local function createLabel(name: string, order: number, height: number, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(225, 228, 235)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = ""
	label.Parent = parent

	return label
end

function PrototypeControls.Create(config: Config): Handle
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "WorkshopZeroControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -16, 1, -16)
	panel.Size = UDim2.fromOffset(248, 132)
	panel.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	local title = createLabel("Title", 1, 14, panel)
	title.Text = "WORKSHOP ZERO"
	title.TextSize = 12
	title.TextColor3 = Color3.fromRGB(150, 156, 170)

	local stateLabel = createLabel("State", 2, 18, panel)
	stateLabel.Font = Enum.Font.GothamBold
	stateLabel.TextSize = 16

	local hintLabel = createLabel("Hint", 3, 28, panel)
	hintLabel.TextSize = 12
	hintLabel.TextColor3 = Color3.fromRGB(170, 176, 190)
	hintLabel.TextWrapped = true
	hintLabel.TextYAlignment = Enum.TextYAlignment.Top

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.LayoutOrder = 4
	button.Size = UDim2.new(1, 0, 0, 42)
	button.BackgroundColor3 = BUTTON_COLORS.Test
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 17
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = "TEST"
	button.Parent = panel

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = button

	local currentState: ConstructionTypes.SimulationState = "Build"
	local currentAction: ConstructionTypes.SimulationAction = "Test"
	local currentSelection: string? = nil

	local function refreshHint()
		if currentState ~= "Build" then
			hintLabel.Text = "Physics is in charge."
			return
		end

		if currentSelection ~= nil then
			hintLabel.Text = string.format("%s selected\n%s", currentSelection, SELECTED_HINT)
			return
		end

		hintLabel.Text = BUILD_HINT
	end

	local function setState(newState: ConstructionTypes.SimulationState)
		currentState = newState

		if newState == "Build" then
			currentAction = "Test"
			button.Text = "TEST"
			button.BackgroundColor3 = BUTTON_COLORS.Test
			button.Active = true
			stateLabel.Text = "BUILD MODE"
		elseif newState == "Testing" then
			currentAction = "Reset"
			button.Text = "RESET"
			button.BackgroundColor3 = BUTTON_COLORS.Reset
			button.Active = true
			stateLabel.Text = "TESTING"
		else
			button.Text = "RESETTING"
			button.BackgroundColor3 = BUTTON_COLORS.Busy
			button.Active = false
			stateLabel.Text = "RESETTING"
		end

		local color = STATE_COLORS[newState]
		if color ~= nil then
			stateLabel.TextColor3 = color
		end

		refreshHint()
	end

	button.Activated:Connect(function()
		if currentState == "Resetting" then
			return
		end

		config.OnAction(currentAction)
	end)

	local handle: Handle = {
		SetState = setState,

		SetSelection = function(name: string?)
			currentSelection = name
			refreshHint()
		end,

		IsPointerOverPanel = function(position: Vector3): boolean
			local topLeft = panel.AbsolutePosition
			local size = panel.AbsoluteSize

			return position.X >= topLeft.X
				and position.X <= topLeft.X + size.X
				and position.Y >= topLeft.Y
				and position.Y <= topLeft.Y + size.Y
		end,
	}

	setState("Build")

	return handle
end

return table.freeze(PrototypeControls)
