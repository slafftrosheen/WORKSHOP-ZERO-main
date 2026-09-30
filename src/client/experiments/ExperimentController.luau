--!strict

--[[
	ExperimentController

	Everything the player reads while an experiment is running: the intro card,
	the flavour toasts, the parts list, the success panel, and - in Studio only -
	a small F8 overlay for whoever is watching a playtest.

	It decides nothing. Experiment state arrives as a replicated value, toasts
	arrive as messages, and TRY AGAIN is a request that the server performs.

	The client never guesses whether the duck made it: the success panel is a
	rendering of a value the server already set.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local ExperimentToast = require(script.Parent.Parent.ui.ExperimentToast)
local PartsTray = require(script.Parent.Parent.ui.PartsTray)

local Config = ConstructionConfig
local player = Players.LocalPlayer

local ExperimentController = {}

-- Structural shape of the control panel. Declared here rather than imported so
-- client UI modules stay independent of each other.
export type ControlsHandle = {
	SetState: (state: ConstructionTypes.SimulationState) -> (),
	SetSelection: (name: string?) -> (),
	SetExperimentState: (state: ExperimentTypes.ExperimentState) -> (),
	IsPointerOverPanel: (position: Vector3) -> boolean,
}

local definition = ExperimentDefinitions.GetDefault()

-- Long enough to watch the duck hit the button before the panel covers the
-- machine, short enough that nobody thinks the game froze.
local SUCCESS_PAUSE = 1.1

local CARD_COLOR = Color3.fromRGB(26, 28, 34)
local TITLE_COLOR = Color3.fromRGB(255, 214, 92)
local TEXT_COLOR = Color3.fromRGB(232, 236, 244)

-- UI helpers -----------------------------------------------------------------

local function createScreenGui(name: string, displayOrder: number): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = displayOrder
	gui.Parent = playerGui

	return gui
end

local function createCard(parent: Instance): Frame
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(360, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = CARD_COLOR
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 22)
	padding.PaddingBottom = UDim.new(0, 22)
	padding.PaddingLeft = UDim.new(0, 24)
	padding.PaddingRight = UDim.new(0, 24)
	padding.Parent = card

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = card

	return card
end

local function createLine(
	parent: Instance,
	order: number,
	height: number,
	text: string,
	textSize: number,
	color: Color3,
	bold: boolean
): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextSize = textSize
	label.TextColor3 = color
	label.Text = text
	label.TextWrapped = true
	label.ZIndex = 3
	label.Parent = parent

	return label
end

local function createCardButton(
	parent: Instance,
	order: number,
	text: string,
	color: Color3
): TextButton
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 48)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.ZIndex = 3
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	return button
end

-- Panels ---------------------------------------------------------------------

type IntroHandle = {
	Show: () -> (),
	Hide: () -> (),
}

type SuccessHandle = {
	Show: (attempts: number, partsUsed: number) -> (),
	Hide: () -> (),
}

local function createIntro(): IntroHandle
	local gui = createScreenGui("WorkshopZeroIntro", 40)

	-- A full-screen button, so one tap anywhere dismisses the card: a child
	-- should never be stuck behind a panel looking for the close control.
	local dim = Instance.new("TextButton")
	dim.Name = "Dimmer"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.ZIndex = 1
	dim.Parent = gui

	local card = createCard(dim)
	createLine(card, 1, 16, definition.IntroTitle, 13, Color3.fromRGB(150, 156, 170), false)
	createLine(card, 2, 42, definition.Name, 30, TITLE_COLOR, true)
	createLine(card, 3, 24, definition.Objective, 17, TEXT_COLOR, false)
	createLine(card, 4, 8, "", 8, TEXT_COLOR, false)

	local startButton =
		createCardButton(card, 5, definition.IntroButton, Color3.fromRGB(52, 132, 84))

	local function hide()
		gui.Enabled = false
	end

	dim.Activated:Connect(hide)
	startButton.Activated:Connect(hide)

	return {
		Show = function()
			gui.Enabled = true
		end,
		Hide = hide,
	}
end

local function createSuccess(onRestart: () -> ()): SuccessHandle
	local gui = createScreenGui("WorkshopZeroSuccess", 40)
	gui.Enabled = false

	local dim = Instance.new("TextButton")
	dim.Name = "Dimmer"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	dim.BackgroundTransparency = 0.55
	dim.BorderSizePixel = 0
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.ZIndex = 1
	dim.Parent = gui

	local card = createCard(dim)
	createLine(card, 1, 44, definition.SuccessTitle, 32, TITLE_COLOR, true)
	createLine(card, 2, 26, definition.SuccessLine, 18, TEXT_COLOR, false)

	local attemptsLabel = createLine(card, 3, 22, "", 16, TEXT_COLOR, false)
	local partsLabel = createLine(card, 4, 22, "", 16, TEXT_COLOR, false)
	createLine(card, 5, 10, "", 10, TEXT_COLOR, false)

	local again = createCardButton(card, 6, definition.RestartButton, Color3.fromRGB(154, 96, 44))
	again.Activated:Connect(function()
		gui.Enabled = false
		onRestart()
	end)

	return {
		Show = function(attempts: number, partsUsed: number)
			attemptsLabel.Text = string.format("Attempts: %d", attempts)
			partsLabel.Text = string.format("Parts used: %d", partsUsed)
			gui.Enabled = true
		end,

		Hide = function()
			gui.Enabled = false
		end,
	}
end

-- Studio playtest overlay ------------------------------------------------------

local function findRuntimeFolder(): Instance?
	for _, name in { Config.AuthoredWorkshopName, Config.RuntimeFolderName } do
		local folder = Workspace:FindFirstChild(name)
		if folder ~= nil then
			return folder
		end
	end

	return nil
end

local function findDuck(): Model?
	local runtime = findRuntimeFolder()
	if runtime == nil then
		return nil
	end

	for _, descendant in runtime:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute(Config.AttributePayload) == true then
			return descendant
		end
	end

	return nil
end

local function countConnections(): number
	local runtime = findRuntimeFolder()
	if runtime == nil then
		return 0
	end

	local container = runtime:FindFirstChild(Config.ConnectionsFolderName)
	if container == nil then
		return 0
	end

	local count = 0
	for _, child in container:GetChildren() do
		if child:IsA("Constraint") then
			count += 1
		end
	end

	return count
end

--[[
	F8, Studio only: the numbers a person watching a playtest wants. This is not
	for players, so it is never created on a real client.
]]
local function startDebugOverlay(remotes: ExperimentTypes.ExperimentRemotes): ()
	local gui = createScreenGui("WorkshopZeroDebug", 5)
	gui.Enabled = false

	local label = Instance.new("TextLabel")
	label.Name = "Readout"
	label.Position = UDim2.fromOffset(16, 220)
	label.Size = UDim2.fromOffset(260, 150)
	label.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
	label.BackgroundTransparency = 0.3
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Code
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(200, 240, 210)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = ""
	label.Parent = gui

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or input.KeyCode ~= Enum.KeyCode.F8 then
			return
		end

		gui.Enabled = not gui.Enabled
	end)

	RunService.RenderStepped:Connect(function()
		if not gui.Enabled then
			return
		end

		local duck = findDuck()
		local speed = 0
		local height = 0
		local root = if duck ~= nil then duck.PrimaryPart else nil

		if root ~= nil then
			speed = root.AssemblyLinearVelocity.Magnitude
			height = root.Position.Y
		end

		label.Text = string.format(
			"EXPERIMENT (F8)\nExperimentState: %s\nSimulationState: %s\nAttempt: %d\nParts used: %d\nConnections: %d\nDuck speed: %.1f\nDuck height: %.1f",
			remotes.ExperimentState.Value,
			remotes.SimulationState.Value,
			remotes.ExperimentAttempt.Value,
			remotes.ExperimentPartsUsed.Value,
			countConnections(),
			speed,
			height
		)
	end)
end

-- Start ------------------------------------------------------------------------

function ExperimentController.Start(
	remotes: ExperimentTypes.ExperimentRemotes,
	controls: ControlsHandle
): ()
	if Config.EnablePrototypeWorkshop then
		-- The developer harness is running: there is no experiment to present.
		return
	end

	local toast = ExperimentToast.Create()
	local intro = createIntro()
	local success = createSuccess(function()
		remotes.RequestExperimentAction:FireServer("Restart")
	end)

	remotes.FailureToast.OnClientEvent:Connect(function(message: unknown)
		if type(message) == "string" then
			toast.Show(message)
		end
	end)

	local function applyExperimentState(value: string)
		local state = ExperimentTypes.ToExperimentState(value) or "Loading"
		controls.SetExperimentState(state)

		if state == "Success" then
			intro.Hide()

			task.delay(SUCCESS_PAUSE, function()
				if
					ExperimentTypes.ToExperimentState(remotes.ExperimentState.Value) == "Success"
				then
					success.Show(remotes.ExperimentAttempt.Value, remotes.ExperimentPartsUsed.Value)
				end
			end)

			return
		end

		success.Hide()

		if state == "Testing" then
			intro.Hide()
		end
	end

	local initial = ExperimentTypes.ToExperimentState(remotes.ExperimentState.Value) or "Loading"
	if initial == "Loading" or initial == "Build" then
		intro.Show()
	else
		intro.Hide()
	end

	controls.SetExperimentState(initial)
	success.Hide()

	remotes.ExperimentState:GetPropertyChangedSignal("Value"):Connect(function()
		applyExperimentState(remotes.ExperimentState.Value)
	end)

	-- The parts list is informational: parts are real objects on a rack, so this
	-- is a reminder of what is available, not an inventory to drag from.
	PartsTray.Create(definition)

	if Config.PlaytestDiagnostics and RunService:IsStudio() then
		startDebugOverlay(remotes)
	end
end

return table.freeze(ExperimentController)
