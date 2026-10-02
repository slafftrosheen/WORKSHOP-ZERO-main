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
local LogicConfig = require(Shared.logic.LogicConfig)

local ExperimentToast = require(script.Parent.Parent.ui.ExperimentToast)
local PartsTray = require(script.Parent.Parent.ui.PartsTray)
local ExperimentBoard = require(script.Parent.Parent.ui.ExperimentBoard)

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
	SetDefinition: (definition: ExperimentTypes.ExperimentDefinition) -> (),
}

type SuccessHandle = {
	Show: (attempts: number, partsUsed: number) -> (),
	Hide: () -> (),
	SetDefinition: (definition: ExperimentTypes.ExperimentDefinition) -> (),
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
	local titleLabel =
		createLine(card, 1, 16, definition.IntroTitle, 13, Color3.fromRGB(150, 156, 170), false)
	local nameLabel = createLine(card, 2, 42, definition.Name, 30, TITLE_COLOR, true)
	local objectiveLabel = createLine(card, 3, 24, definition.Objective, 17, TEXT_COLOR, false)
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
		SetDefinition = function(newDef: ExperimentTypes.ExperimentDefinition)
			titleLabel.Text = newDef.IntroTitle
			nameLabel.Text = newDef.Name
			objectiveLabel.Text = newDef.Objective
			startButton.Text = newDef.IntroButton
		end,
	}
end

local function createSuccess(
	onRestart: () -> (),
	onNext: () -> (),
	onOpenBoard: () -> (),
	getUnlockedIndex: () -> number
): SuccessHandle
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
	local titleLabel = createLine(card, 1, 44, definition.SuccessTitle, 32, TITLE_COLOR, true)
	local lineLabel = createLine(card, 2, 26, definition.SuccessLine, 18, TEXT_COLOR, false)

	local attemptsLabel = createLine(card, 3, 22, "", 16, TEXT_COLOR, false)
	local partsLabel = createLine(card, 4, 22, "", 16, TEXT_COLOR, false)

	-- Discovery Card section
	local discoveryBox = Instance.new("Frame")
	discoveryBox.Name = "DiscoveryBox"
	discoveryBox.LayoutOrder = 5
	discoveryBox.Size = UDim2.fromScale(1, 0)
	discoveryBox.AutomaticSize = Enum.AutomaticSize.Y
	discoveryBox.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
	discoveryBox.BorderSizePixel = 0
	discoveryBox.Parent = card

	local discCorner = Instance.new("UICorner")
	discCorner.CornerRadius = UDim.new(0, 8)
	discCorner.Parent = discoveryBox

	local discPadding = Instance.new("UIPadding")
	discPadding.PaddingTop = UDim.new(0, 10)
	discPadding.PaddingBottom = UDim.new(0, 10)
	discPadding.PaddingLeft = UDim.new(0, 14)
	discPadding.PaddingRight = UDim.new(0, 14)
	discPadding.Parent = discoveryBox

	local discLayout = Instance.new("UIListLayout")
	discLayout.FillDirection = Enum.FillDirection.Vertical
	discLayout.SortOrder = Enum.SortOrder.LayoutOrder
	discLayout.Padding = UDim.new(0, 3)
	discLayout.Parent = discoveryBox

	createLine(discoveryBox, 1, 14, "DISCOVERY", 11, Color3.fromRGB(255, 214, 92), true)
	local discTitleLabel = createLine(
		discoveryBox,
		2,
		20,
		definition.DiscoveryTitle,
		16,
		Color3.fromRGB(255, 255, 255),
		true
	)
	local discBodyLabel = createLine(
		discoveryBox,
		3,
		30,
		definition.DiscoveryBody,
		13,
		Color3.fromRGB(200, 206, 220),
		false
	)

	createLine(card, 6, 8, "", 8, TEXT_COLOR, false)

	local nextButton = createCardButton(card, 7, "NEXT EXPERIMENT", Color3.fromRGB(52, 132, 84))
	local boardButton = createCardButton(card, 8, "EXPERIMENTS", Color3.fromRGB(48, 54, 68))
	local again = createCardButton(card, 9, definition.RestartButton, Color3.fromRGB(154, 96, 44))
	local moreSoonLabel = createLine(card, 10, 24, "", 14, Color3.fromRGB(150, 156, 170), false)

	nextButton.Activated:Connect(function()
		gui.Enabled = false
		onNext()
	end)

	boardButton.Activated:Connect(function()
		gui.Enabled = false
		onOpenBoard()
	end)

	again.Activated:Connect(function()
		gui.Enabled = false
		onRestart()
	end)

	local function refreshSuccessUi()
		titleLabel.Text = definition.SuccessTitle
		lineLabel.Text = definition.SuccessLine
		discTitleLabel.Text = definition.DiscoveryTitle
		discBodyLabel.Text = definition.DiscoveryBody
		again.Text = definition.RestartButton

		local nextDef = ExperimentDefinitions.GetNext(definition.Id)
		if nextDef ~= nil then
			nextButton.Visible = true
			moreSoonLabel.Visible = false
			boardButton.Text = "EXPERIMENTS"
		else
			nextButton.Visible = false
			boardButton.Text = "ALL EXPERIMENTS"

			-- "MORE EXPERIMENTS SOON" was a lie the moment Open Workshop
			-- and the automation experiments existed: past the last numbered
			-- one there is always free build waiting.
			if ExperimentDefinitions.IsOpenWorkshopUnlocked(getUnlockedIndex()) then
				moreSoonLabel.Text = "THE OPEN WORKSHOP IS YOURS. BUILD ANYTHING."
			else
				moreSoonLabel.Text = "MORE EXPERIMENTS SOON"
			end
			moreSoonLabel.Visible = true
		end
	end

	return {
		Show = function(attempts: number, partsUsed: number)
			refreshSuccessUi()
			attemptsLabel.Text = string.format("Attempts: %d", attempts)
			partsLabel.Text = string.format("Parts used: %d", partsUsed)
			gui.Enabled = true
		end,

		Hide = function()
			gui.Enabled = false
		end,

		SetDefinition = function(_newDef: ExperimentTypes.ExperimentDefinition)
			refreshSuccessUi()
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

local function countConnections(): (number, number)
	local runtime = findRuntimeFolder()
	if runtime == nil then
		return 0, 0
	end

	local container = runtime:FindFirstChild(Config.ConnectionsFolderName)
	if container == nil then
		return 0, 0
	end

	local total = 0
	local powered = 0
	for _, child in container:GetChildren() do
		if child:IsA("Constraint") then
			total += 1
			if child:GetAttribute(Config.AttributePowered) == true then
				powered += 1
			end
		end
	end

	return total, powered
end

local function countBehaviourComponents(): number
	local runtime = findRuntimeFolder()
	if runtime == nil then
		return 0
	end

	local count = 0
	for _, child in runtime:GetDescendants() do
		if child:IsA("Model") and child:GetAttribute(Config.AttributeComponentType) == "Fan" then
			count += 1
		end
	end

	return count
end

local function countActuators(): (number, number, number, number, number)
	local runtime = findRuntimeFolder()
	if runtime == nil then
		return 0, 0, 0, 0, 0
	end

	local rotaryMotors = 0
	local servos = 0
	local winches = 0
	local pistons = 0
	local controlledActuators = 0

	for _, descendant in runtime:GetDescendants() do
		if descendant:IsA("Model") then
			local compType = descendant:GetAttribute(Config.AttributeComponentType)
			if compType == "Motor" then
				rotaryMotors += 1
			elseif compType == "Servo" then
				servos += 1
			elseif compType == "Winch" then
				winches += 1
			elseif compType == "Piston" then
				pistons += 1
			end

			if
				(
					compType == "Motor"
					or compType == "Winch"
					or compType == "Servo"
					or compType == "Piston"
				) and descendant:GetAttribute("WZ_ActuatorControlled") == true
			then
				controlledActuators += 1
			end
		end
	end

	return rotaryMotors, servos, winches, pistons, controlledActuators
end

local function countLogicStats(): (number, number, number)
	local runtime = findRuntimeFolder()
	if runtime == nil then
		return 0, 0, 0
	end

	local logicNodes = 0
	local wires = 0
	local activeSignals = 0

	for _, descendant in runtime:GetDescendants() do
		if descendant:IsA("Model") then
			local compType = descendant:GetAttribute(Config.AttributeComponentType)
			if
				compType == "Switch"
				or compType == "PressureSensor"
				or compType == "ProximitySensor"
				or compType == "Timer"
				or compType == "AND"
				or compType == "OR"
				or compType == "NOT"
				or compType == "SignalLamp"
			then
				logicNodes += 1
			end
		elseif descendant:IsA("Beam") and descendant:GetAttribute("WZ_ControlWire") == true then
			wires += 1
		elseif
			descendant:IsA("Attachment")
			and descendant:GetAttribute(LogicConfig.AttributeSignalPort) == true
		then
			if descendant:GetAttribute("WZ_SignalValue") == true then
				activeSignals += 1
			end
		end
	end

	return logicNodes, wires, activeSignals
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
	label.Size = UDim2.fromOffset(260, 320)
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

		local totalConns, poweredAxles = countConnections()
		local activeBehaviours = countBehaviourComponents()
		local logicNodes, wires, activeSignals = countLogicStats()
		local rotaryMotors, servos, winches, pistons, controlledActuators = countActuators()

		label.Text = string.format(
			"EXPERIMENT (F8)\nExperiment: %s\nExperimentState: %s\nSimulationState: %s\nAttempt: %d\nParts used: %d\nConnections: %d\nPowered axles: %d\nActive behaviour: %d\nRotary motors: %d\nServos: %d\nWinches: %d\nPistons: %d\nControlled actuators: %d\nLogic nodes: %d\nSignal wires: %d\nActive signals: %d\nLogic tick rate: %d Hz\nDuck speed: %.1f\nDuck height: %.1f",
			definition.Id,
			remotes.ExperimentState.Value,
			remotes.SimulationState.Value,
			remotes.ExperimentAttempt.Value,
			remotes.ExperimentPartsUsed.Value,
			totalConns,
			poweredAxles,
			activeBehaviours,
			rotaryMotors,
			servos,
			winches,
			pistons,
			controlledActuators,
			logicNodes,
			wires,
			activeSignals,
			LogicConfig.LogicTickRate,
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

	local initialId = remotes.CurrentExperimentId.Value
	if initialId ~= "" then
		local initialDef = ExperimentDefinitions.Get(initialId)
		if initialDef ~= nil then
			definition = initialDef
		end
	end

	local board = ExperimentBoard.Create({
		OnSelectExperiment = function(targetId: string)
			remotes.RequestExperimentAction:FireServer({
				Action = "Select",
				ExperimentId = targetId,
			})
		end,
		HasAlteredMachine = function()
			return remotes.ExperimentPartsUsed.Value > 0
		end,
		IsBuildMode = function()
			return remotes.SimulationState.Value == "Build"
		end,
	})

	local toast = ExperimentToast.Create()
	local intro = createIntro()
	local success = createSuccess(function()
		remotes.RequestExperimentAction:FireServer("Restart")
	end, function()
		remotes.RequestExperimentAction:FireServer("Next")
	end, function()
		board.Show()
	end, function()
		return remotes.UnlockedExperimentIndex.Value
	end)

	local partsTray = PartsTray.Create(definition, function()
		board.Show()
	end, function()
		-- CLEAR WORKSHOP is the ordinary experiment-layer restart wearing a
		-- different label, so the rack always comes back the same way.
		remotes.RequestExperimentAction:FireServer("Restart")
	end)

	board.SetUnlockedIndex(remotes.UnlockedExperimentIndex.Value)
	board.SetCurrentExperimentId(remotes.CurrentExperimentId.Value)

	remotes.UnlockedExperimentIndex:GetPropertyChangedSignal("Value"):Connect(function()
		board.SetUnlockedIndex(remotes.UnlockedExperimentIndex.Value)
	end)

	local function orientCameraToExperiment(geo: ExperimentTypes.LevelGeometry)
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local lookTarget = Vector3.new(
			0,
			(geo.DuckSpawn.Y + geo.ButtonPosition.Y) * 0.5 + 1.5,
			(geo.DuckSpawn.Z + geo.ButtonPosition.Z) * 0.5
		)
		local eyePos =
			Vector3.new(geo.PlayerSpawn.X - 10, geo.PlayerSpawn.Y + 14, geo.PlayerSpawn.Z - 12)
		camera.CFrame = CFrame.lookAt(eyePos, lookTarget)
	end

	remotes.CurrentExperimentId:GetPropertyChangedSignal("Value"):Connect(function()
		local newDef = ExperimentDefinitions.Get(remotes.CurrentExperimentId.Value)
		if newDef ~= nil then
			definition = newDef
			partsTray.SetDefinition(newDef)
			intro.SetDefinition(newDef)
			success.SetDefinition(newDef)
			board.SetCurrentExperimentId(newDef.Id)
			orientCameraToExperiment(newDef.Geometry)
			if ExperimentTypes.ToExperimentState(remotes.ExperimentState.Value) == "Build" then
				intro.Show()
			end
		end
	end)

	remotes.FailureToast.OnClientEvent:Connect(function(message: unknown)
		if type(message) == "string" then
			toast.Show(message)
		end
	end)

	-- The physical EXPERIMENTS panel on the wall asked for the board. The
	-- server decided which client; this only draws what it was asked for.
	remotes.OpenExperimentBoard.OnClientEvent:Connect(function()
		board.Show()
	end)

	local function applyExperimentState(value: string)
		local state = ExperimentTypes.ToExperimentState(value) or "Loading"
		controls.SetExperimentState(state)

		if state == "Success" then
			intro.Hide()
			partsTray.SetVisible(false)

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
			partsTray.SetVisible(false)
		elseif state == "Build" then
			partsTray.SetVisible(true)
		end
	end

	local initial = ExperimentTypes.ToExperimentState(remotes.ExperimentState.Value) or "Loading"
	if initial == "Loading" or initial == "Build" then
		orientCameraToExperiment(definition.Geometry)
		intro.Show()
	else
		intro.Hide()
	end

	controls.SetExperimentState(initial)
	success.Hide()

	remotes.ExperimentState:GetPropertyChangedSignal("Value"):Connect(function()
		applyExperimentState(remotes.ExperimentState.Value)
	end)

	if Config.PlaytestDiagnostics and RunService:IsStudio() then
		startDebugOverlay(remotes)
	end
end

return table.freeze(ExperimentController)
