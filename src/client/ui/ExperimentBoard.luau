--!strict

--[[
	ExperimentBoard

	A modal dialog allowing players to view the session experiments, see which
	are unlocked, and switch between unlocked experiments.

	Includes lightweight confirmation if switching during BUILD with an altered machine.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local player = Players.LocalPlayer

local ExperimentBoard = {}

export type BoardConfig = {
	OnSelectExperiment: (experimentId: string) -> (),
	HasAlteredMachine: () -> boolean,
	IsBuildMode: () -> boolean,
}

export type BoardHandle = {
	Show: () -> (),
	Hide: () -> (),
	SetUnlockedIndex: (index: number) -> (),
	SetCurrentExperimentId: (id: string) -> (),
}

local CARD_BG = Color3.fromRGB(24, 26, 32)
local UNLOCKED_ITEM_BG = Color3.fromRGB(36, 40, 50)
local LOCKED_ITEM_BG = Color3.fromRGB(28, 30, 36)
-- Free build reads as its own kind of thing, not a sixth experiment.
local FREE_ITEM_BG = Color3.fromRGB(38, 52, 44)
local TITLE_COLOR = Color3.fromRGB(255, 214, 92)
local TEXT_COLOR = Color3.fromRGB(230, 234, 242)
local MUTED_COLOR = Color3.fromRGB(130, 136, 150)
local PLAY_BTN_COLOR = Color3.fromRGB(52, 132, 84)
local CURRENT_TAG_COLOR = Color3.fromRGB(70, 95, 120)

function ExperimentBoard.Create(config: BoardConfig): BoardHandle
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "WorkshopZeroExperimentBoard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = playerGui

	-- Dimmer background
	local dimmer = Instance.new("TextButton")
	dimmer.Name = "Dimmer"
	dimmer.Size = UDim2.fromScale(1, 1)
	dimmer.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	dimmer.BackgroundTransparency = 0.5
	dimmer.BorderSizePixel = 0
	dimmer.AutoButtonColor = false
	dimmer.Text = ""
	dimmer.ZIndex = 1
	dimmer.Parent = gui

	-- Main card
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(420, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = CARD_BG
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Parent = dimmer

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = card

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 20)
	cardPadding.PaddingBottom = UDim.new(0, 20)
	cardPadding.PaddingLeft = UDim.new(0, 22)
	cardPadding.PaddingRight = UDim.new(0, 22)
	cardPadding.Parent = card

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Vertical
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Padding = UDim.new(0, 10)
	cardLayout.Parent = card

	-- Header row: Title + Close button
	local headerRow = Instance.new("Frame")
	headerRow.Name = "HeaderRow"
	headerRow.LayoutOrder = 1
	headerRow.Size = UDim2.new(1, 0, 0, 32)
	headerRow.BackgroundTransparency = 1
	headerRow.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 1, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = TITLE_COLOR
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "EXPERIMENTS"
	title.Parent = headerRow

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.fromScale(1, 0.5)
	closeBtn.Size = UDim2.fromOffset(30, 30)
	closeBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
	closeBtn.BorderSizePixel = 0
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.TextColor3 = TEXT_COLOR
	closeBtn.Text = "✕"
	closeBtn.Parent = headerRow

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 6)
	closeBtnCorner.Parent = closeBtn

	-- List of experiment items
	local itemsList = Instance.new("ScrollingFrame")
	itemsList.Name = "ItemsList"
	itemsList.LayoutOrder = 2
	itemsList.Size = UDim2.new(1, 0, 0, 360)
	itemsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	itemsList.CanvasSize = UDim2.new(0, 0, 0, 0)
	itemsList.ScrollBarThickness = 6
	itemsList.ScrollBarImageColor3 = Color3.fromRGB(80, 85, 100)
	itemsList.BorderSizePixel = 0
	itemsList.BackgroundTransparency = 1
	itemsList.ScrollingDirection = Enum.ScrollingDirection.Y
	itemsList.Selectable = false
	itemsList.Parent = card

	local itemsPadding = Instance.new("UIPadding")
	itemsPadding.PaddingRight = UDim.new(0, 8)
	itemsPadding.Parent = itemsList

	local itemsLayout = Instance.new("UIListLayout")
	itemsLayout.FillDirection = Enum.FillDirection.Vertical
	itemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	itemsLayout.Padding = UDim.new(0, 8)
	itemsLayout.Parent = itemsList

	-- Confirmation overlay frame (inside card)
	local confirmFrame = Instance.new("Frame")
	confirmFrame.Name = "ConfirmFrame"
	confirmFrame.Size = UDim2.fromScale(1, 1)
	confirmFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	confirmFrame.BackgroundTransparency = 0.05
	confirmFrame.BorderSizePixel = 0
	confirmFrame.Visible = false
	confirmFrame.ZIndex = 10
	confirmFrame.Parent = card

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 14)
	confirmCorner.Parent = confirmFrame

	local confirmPadding = Instance.new("UIPadding")
	confirmPadding.PaddingTop = UDim.new(0, 24)
	confirmPadding.PaddingBottom = UDim.new(0, 24)
	confirmPadding.PaddingLeft = UDim.new(0, 24)
	confirmPadding.PaddingRight = UDim.new(0, 24)
	confirmPadding.Parent = confirmFrame

	local confirmLayout = Instance.new("UIListLayout")
	confirmLayout.FillDirection = Enum.FillDirection.Vertical
	confirmLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	confirmLayout.SortOrder = Enum.SortOrder.LayoutOrder
	confirmLayout.Padding = UDim.new(0, 12)
	confirmLayout.Parent = confirmFrame

	local confirmTitle = Instance.new("TextLabel")
	confirmTitle.LayoutOrder = 1
	confirmTitle.Size = UDim2.new(1, 0, 0, 28)
	confirmTitle.BackgroundTransparency = 1
	confirmTitle.Font = Enum.Font.GothamBold
	confirmTitle.TextSize = 20
	confirmTitle.TextColor3 = TITLE_COLOR
	confirmTitle.Text = "LEAVE THIS EXPERIMENT?"
	confirmTitle.Parent = confirmFrame

	local confirmBody = Instance.new("TextLabel")
	confirmBody.LayoutOrder = 2
	confirmBody.Size = UDim2.new(1, 0, 0, 36)
	confirmBody.BackgroundTransparency = 1
	confirmBody.Font = Enum.Font.GothamMedium
	confirmBody.TextSize = 14
	confirmBody.TextColor3 = TEXT_COLOR
	confirmBody.TextWrapped = true
	confirmBody.Text = "Your current machine will be cleared."
	confirmBody.Parent = confirmFrame

	local confirmBtnRow = Instance.new("Frame")
	confirmBtnRow.LayoutOrder = 3
	confirmBtnRow.Size = UDim2.new(1, 0, 0, 44)
	confirmBtnRow.BackgroundTransparency = 1
	confirmBtnRow.Parent = confirmFrame

	local confirmBtnLayout = Instance.new("UIListLayout")
	confirmBtnLayout.FillDirection = Enum.FillDirection.Horizontal
	confirmBtnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	confirmBtnLayout.Padding = UDim.new(0, 12)
	confirmBtnLayout.Parent = confirmBtnRow

	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveBtn"
	leaveBtn.LayoutOrder = 1
	leaveBtn.Size = UDim2.new(0.5, -6, 1, 0)
	leaveBtn.BackgroundColor3 = Color3.fromRGB(175, 60, 50)
	leaveBtn.BorderSizePixel = 0
	leaveBtn.Font = Enum.Font.GothamBold
	leaveBtn.TextSize = 16
	leaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	leaveBtn.Text = "LEAVE"
	leaveBtn.Parent = confirmBtnRow

	local leaveCorner = Instance.new("UICorner")
	leaveCorner.CornerRadius = UDim.new(0, 8)
	leaveCorner.Parent = leaveBtn

	local stayBtn = Instance.new("TextButton")
	stayBtn.Name = "StayBtn"
	stayBtn.LayoutOrder = 2
	stayBtn.Size = UDim2.new(0.5, -6, 1, 0)
	stayBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 78)
	stayBtn.BorderSizePixel = 0
	stayBtn.Font = Enum.Font.GothamBold
	stayBtn.TextSize = 16
	stayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	stayBtn.Text = "STAY"
	stayBtn.Parent = confirmBtnRow

	local stayCorner = Instance.new("UICorner")
	stayCorner.CornerRadius = UDim.new(0, 8)
	stayCorner.Parent = stayBtn

	-- State
	local currentUnlockedIndex = 1
	local currentActiveId = ""
	local pendingTargetId: string? = nil

	local function hide()
		confirmFrame.Visible = false
		pendingTargetId = nil
		gui.Enabled = false
	end

	closeBtn.Activated:Connect(hide)

	stayBtn.Activated:Connect(function()
		confirmFrame.Visible = false
		pendingTargetId = nil
	end)

	leaveBtn.Activated:Connect(function()
		local target = pendingTargetId
		hide()
		if target ~= nil then
			config.OnSelectExperiment(target)
		end
	end)

	local function requestSelect(targetId: string)
		if targetId == currentActiveId then
			hide()
			return
		end

		if config.IsBuildMode() and config.HasAlteredMachine() then
			pendingTargetId = targetId
			confirmFrame.Visible = true
		else
			hide()
			config.OnSelectExperiment(targetId)
		end
	end

	local function refreshItems()
		for _, child in itemsList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		local ordered = ExperimentDefinitions.GetOrdered()

		-- The numbered experiments, then Open Workshop as a separate row.
		-- It is always listed so a child can see it exists, and playable only
		-- once every numbered experiment is finished.
		local rows: { { Definition: ExperimentTypes.ExperimentDefinition, IsFree: boolean } } = {}
		for _, def in ordered do
			table.insert(rows, { Definition = def, IsFree = false })
		end
		table.insert(rows, { Definition = ExperimentDefinitions.GetOpenWorkshop(), IsFree = true })

		for index, row in rows do
			local def = row.Definition
			local isUnlocked = if row.IsFree
				then ExperimentDefinitions.IsOpenWorkshopUnlocked(currentUnlockedIndex)
				else def.Number <= currentUnlockedIndex
			local isCurrent = def.Id == currentActiveId

			local item = Instance.new("Frame")
			item.Name = string.format("Item_%s", def.Id)
			item.LayoutOrder = index
			item.Size = UDim2.new(1, 0, 0, 56)
			if not isUnlocked then
				item.BackgroundColor3 = LOCKED_ITEM_BG
			elseif row.IsFree then
				item.BackgroundColor3 = FREE_ITEM_BG
			else
				item.BackgroundColor3 = UNLOCKED_ITEM_BG
			end
			item.BorderSizePixel = 0
			item.Parent = itemsList

			local itemCorner = Instance.new("UICorner")
			itemCorner.CornerRadius = UDim.new(0, 8)
			itemCorner.Parent = item

			local itemPadding = Instance.new("UIPadding")
			itemPadding.PaddingLeft = UDim.new(0, 14)
			itemPadding.PaddingRight = UDim.new(0, 12)
			itemPadding.Parent = item

			local numLabel = Instance.new("TextLabel")
			numLabel.Name = "NumLabel"
			numLabel.Size = UDim2.new(0, 36, 1, 0)
			numLabel.Position = UDim2.new(0, 0, 0, 0)
			numLabel.BackgroundTransparency = 1
			numLabel.Font = Enum.Font.GothamBold
			numLabel.TextSize = 14
			numLabel.TextColor3 = if isUnlocked then TITLE_COLOR else MUTED_COLOR
			numLabel.TextXAlignment = Enum.TextXAlignment.Left
			numLabel.Text = if row.IsFree then "FREE" else string.format("%03d", def.Number)
			numLabel.Parent = item

			local textContainer = Instance.new("Frame")
			textContainer.Name = "TextContainer"
			textContainer.Size = UDim2.new(1, -130, 1, 0)
			textContainer.Position = UDim2.fromOffset(40, 0)
			textContainer.BackgroundTransparency = 1
			textContainer.Parent = item

			local textLayout = Instance.new("UIListLayout")
			textLayout.FillDirection = Enum.FillDirection.Vertical
			textLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			textLayout.SortOrder = Enum.SortOrder.LayoutOrder
			textLayout.Padding = UDim.new(0, 2)
			textLayout.Parent = textContainer

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "NameLabel"
			nameLabel.Size = UDim2.new(1, 0, 0, 18)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 14
			nameLabel.TextColor3 = if isUnlocked then TEXT_COLOR else MUTED_COLOR
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Text = if isUnlocked then def.Name else "???"
			nameLabel.Parent = textContainer

			local objectiveLabel = Instance.new("TextLabel")
			objectiveLabel.Name = "ObjectiveLabel"
			objectiveLabel.Size = UDim2.new(1, 0, 0, 14)
			objectiveLabel.BackgroundTransparency = 1
			objectiveLabel.Font = Enum.Font.GothamMedium
			objectiveLabel.TextSize = 11
			objectiveLabel.TextColor3 = MUTED_COLOR
			objectiveLabel.TextXAlignment = Enum.TextXAlignment.Left
			objectiveLabel.Text = if isUnlocked then def.Objective else "Locked"
			objectiveLabel.Parent = textContainer

			-- Right-hand button / tag
			if isCurrent then
				local tag = Instance.new("TextLabel")
				tag.Name = "CurrentTag"
				tag.AnchorPoint = Vector2.new(1, 0.5)
				tag.Position = UDim2.fromScale(1, 0.5)
				tag.Size = UDim2.fromOffset(72, 28)
				tag.BackgroundColor3 = CURRENT_TAG_COLOR
				tag.BorderSizePixel = 0
				tag.Font = Enum.Font.GothamBold
				tag.TextSize = 12
				tag.TextColor3 = Color3.fromRGB(220, 240, 255)
				tag.Text = "CURRENT"
				tag.Parent = item

				local tagCorner = Instance.new("UICorner")
				tagCorner.CornerRadius = UDim.new(0, 6)
				tagCorner.Parent = tag
			elseif isUnlocked then
				local playBtn = Instance.new("TextButton")
				playBtn.Name = "PlayBtn"
				playBtn.AnchorPoint = Vector2.new(1, 0.5)
				playBtn.Position = UDim2.fromScale(1, 0.5)
				playBtn.Size = UDim2.fromOffset(72, 32)
				playBtn.BackgroundColor3 = PLAY_BTN_COLOR
				playBtn.BorderSizePixel = 0
				playBtn.Font = Enum.Font.GothamBold
				playBtn.TextSize = 13
				playBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				playBtn.Text = "PLAY"
				playBtn.Parent = item

				local btnCorner = Instance.new("UICorner")
				btnCorner.CornerRadius = UDim.new(0, 6)
				btnCorner.Parent = playBtn

				local targetId = def.Id
				playBtn.Activated:Connect(function()
					requestSelect(targetId)
				end)
			else
				local lockedLabel = Instance.new("TextLabel")
				lockedLabel.Name = "LockedLabel"
				lockedLabel.AnchorPoint = Vector2.new(1, 0.5)
				lockedLabel.Position = UDim2.fromScale(1, 0.5)
				lockedLabel.Size = UDim2.fromOffset(72, 28)
				lockedLabel.BackgroundTransparency = 1
				lockedLabel.Font = Enum.Font.GothamMedium
				lockedLabel.TextSize = 12
				lockedLabel.TextColor3 = MUTED_COLOR
				lockedLabel.Text = "🔒 LOCKED"
				lockedLabel.Parent = item
			end
		end
	end

	return {
		Show = function()
			confirmFrame.Visible = false
			pendingTargetId = nil
			refreshItems()
			gui.Enabled = true
		end,
		Hide = hide,
		SetUnlockedIndex = function(index: number)
			currentUnlockedIndex = index
			refreshItems()
		end,
		SetCurrentExperimentId = function(id: string)
			currentActiveId = id
			refreshItems()
		end,
	}
end

return table.freeze(ExperimentBoard)
