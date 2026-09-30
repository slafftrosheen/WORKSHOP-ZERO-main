--!strict

--[[
	PrototypeControls

	A deliberately plain control panel: one big action button, one state line,
	one hint line, and - on a touch device - large buttons for what a keyboard
	would otherwise do.

	The panel decides nothing. It reports presses through OnAction / OnRotate /
	OnDisconnect and renders whatever state the callers hand it, so the server
	stays the only thing that knows whether the workshop is building or testing.

	Presentation follows the device: a child on a tablet never sees "press Q",
	because Q does not exist there.

	Built at runtime on purpose: this is a prototype, and a ScreenGui created by
	code cannot drift away from the code that fills it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local ConstructionTypes = require(Shared.construction.ConstructionTypes)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local player = Players.LocalPlayer

local PrototypeControls = {}

export type Config = {
	OnAction: (action: ConstructionTypes.SimulationAction) -> (),
	OnRotate: (operation: ConstructionTypes.RotationOperation) -> (),
	OnDisconnect: () -> (),
}

export type Handle = {
	SetState: (state: ConstructionTypes.SimulationState) -> (),
	SetSelection: (name: string?) -> (),
	SetExperimentState: (state: ExperimentTypes.ExperimentState) -> (),
	IsPointerOverPanel: (position: Vector3) -> boolean,
}

local BUILD_HINT = "Tap a part to grab it"
local DESKTOP_HINT = "Q / E   ROTATE\nR       FLIP\nX       DISCONNECT"
local TOUCH_HINT = "Use the buttons below"
local TESTING_HINT = "Physics is in charge."
local SUCCESS_HINT = "The duck made it."

local BUTTON_COLORS = {
	Test = Color3.fromRGB(52, 132, 84),
	Reset = Color3.fromRGB(154, 96, 44),
	Busy = Color3.fromRGB(78, 82, 92),
	Touch = Color3.fromRGB(58, 64, 78),
}

local STATE_COLORS = {
	Build = Color3.fromRGB(140, 220, 170),
	Testing = Color3.fromRGB(255, 196, 120),
	Resetting = Color3.fromRGB(180, 200, 230),
}

-- A keyboard is the better signal than "has a touchscreen": laptops with touch
-- screens exist, and those players still have Q on the keyboard.
local function hasKeyboard(): boolean
	return UserInputService.KeyboardEnabled
end

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

local function createTouchButton(
	name: string,
	text: string,
	order: number,
	size: UDim2,
	parent: Instance
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = order
	button.Size = size
	button.BackgroundColor3 = BUTTON_COLORS.Touch
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = Color3.fromRGB(240, 242, 248)
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	return button
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
	panel.Size = UDim2.fromOffset(248, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
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

	local hintLabel = createLabel("Hint", 3, 46, panel)
	hintLabel.TextSize = 12
	hintLabel.TextColor3 = Color3.fromRGB(170, 176, 190)
	hintLabel.TextWrapped = true
	hintLabel.TextYAlignment = Enum.TextYAlignment.Top

	-- Touch equivalents of Q / E / R / X, created only where they can be used.
	local isTouch = not hasKeyboard()
	local rotateRow: Frame? = nil
	local disconnectButton: TextButton? = nil

	if isTouch then
		local row = Instance.new("Frame")
		row.Name = "RotateRow"
		row.LayoutOrder = 4
		row.Size = UDim2.new(1, 0, 0, 52)
		row.BackgroundTransparency = 1
		row.Visible = false
		row.Parent = panel

		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Padding = UDim.new(0, 6)
		rowLayout.Parent = row

		local quarter = UDim2.new(0.25, -5, 1, 0)
		createTouchButton("RotateLeft", "↺", 1, quarter, row).Activated:Connect(function()
			config.OnRotate("YawLeft")
		end)
		createTouchButton("RotateRight", "↻", 2, quarter, row).Activated:Connect(function()
			config.OnRotate("YawRight")
		end)
		createTouchButton("Flip", "FLIP", 3, quarter, row).Activated:Connect(function()
			config.OnRotate("Flip")
		end)

		local blank = Instance.new("Frame")
		blank.Name = "Spacer"
		blank.LayoutOrder = 4
		blank.Size = quarter
		blank.BackgroundTransparency = 1
		blank.Parent = row

		rotateRow = row

		disconnectButton =
			createTouchButton("Disconnect", "DISCONNECT", 5, UDim2.new(1, 0, 0, 44), panel)
		disconnectButton.Visible = false
		disconnectButton.Activated:Connect(function()
			config.OnDisconnect()
		end)
	end

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.LayoutOrder = 6
	button.Size = UDim2.new(1, 0, 0, 44)
	button.BackgroundColor3 = BUTTON_COLORS.Test
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 17
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = "TEST MACHINE"
	button.Parent = panel

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = button

	local currentState: ConstructionTypes.SimulationState = "Build"
	local currentExperiment: ExperimentTypes.ExperimentState = "Loading"
	local currentAction: ConstructionTypes.SimulationAction = "Test"
	local currentSelection: string? = nil

	local function canBuild(): boolean
		return currentState == "Build" and currentExperiment ~= "Success"
	end

	-- The experiment can be in a phase of its own (Loading, Success) while the
	-- simulation is still where it was, so the label is derived from both.
	local function refreshStateLabel()
		if currentExperiment == "Success" then
			stateLabel.Text = "SUCCESS"
			stateLabel.TextColor3 = STATE_COLORS.Build
			return
		end

		if currentExperiment == "Loading" then
			stateLabel.Text = "LOADING"
			stateLabel.TextColor3 = STATE_COLORS.Resetting
			return
		end

		local color = STATE_COLORS[currentState]
		if color ~= nil then
			stateLabel.TextColor3 = color
		end

		if currentState == "Build" then
			stateLabel.Text = "BUILD MODE"
		elseif currentState == "Testing" then
			stateLabel.Text = "TESTING"
		else
			stateLabel.Text = "RESETTING"
		end
	end

	local function refreshHint()
		if currentExperiment == "Success" then
			hintLabel.Text = SUCCESS_HINT
			return
		end

		if currentState ~= "Build" then
			hintLabel.Text = TESTING_HINT
			return
		end

		if currentSelection ~= nil then
			hintLabel.Text = string.format(
				"%s selected\n%s",
				currentSelection,
				if isTouch then TOUCH_HINT else DESKTOP_HINT
			)
			return
		end

		hintLabel.Text = BUILD_HINT
	end

	local function refreshSelectionTools()
		local visible = isTouch and canBuild() and currentSelection ~= nil

		if rotateRow ~= nil then
			rotateRow.Visible = visible
		end

		if disconnectButton ~= nil then
			disconnectButton.Visible = visible
		end
	end

	local function setState(newState: ConstructionTypes.SimulationState)
		currentState = newState

		if newState == "Build" then
			currentAction = "Test"
			button.Text = "TEST MACHINE"
			button.BackgroundColor3 = BUTTON_COLORS.Test
			button.Active = true
		elseif newState == "Testing" then
			currentAction = "Reset"
			button.Text = "RESET"
			button.BackgroundColor3 = BUTTON_COLORS.Reset
			button.Active = true
		else
			button.Text = "RESETTING"
			button.BackgroundColor3 = BUTTON_COLORS.Busy
			button.Active = false
		end

		refreshStateLabel()
		refreshHint()
		refreshSelectionTools()
	end

	--[[
		The success freeze is an experiment state, not a physics one: the world is
		still "Testing" while the player watches their machine. The action button
		has nothing useful to offer there, so it steps aside for TRY AGAIN.
	]]
	local function setExperimentState(newState: ExperimentTypes.ExperimentState)
		currentExperiment = newState

		button.Visible = newState ~= "Success" and newState ~= "Loading"
		refreshStateLabel()
		refreshHint()
		refreshSelectionTools()
	end

	button.Activated:Connect(function()
		if currentState == "Resetting" or currentExperiment == "Success" then
			return
		end

		config.OnAction(currentAction)
	end)

	local handle: Handle = {
		SetState = setState,

		SetSelection = function(name: string?)
			currentSelection = name
			refreshHint()
			refreshSelectionTools()
		end,

		SetExperimentState = setExperimentState,

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
	refreshHint()

	return handle
end

return table.freeze(PrototypeControls)
