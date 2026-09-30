--!strict

--[[
	ExperimentToast

	One line of flavour, centered near the top, gone again in about two seconds.

	Behaviour is deliberately small: fade in, hold, fade out, and only ever one
	at a time - a new message replaces the one on screen and restarts the
	timer, so a failing machine cannot wallpaper the player's view.

	The position is above the play area rather than over it: the machine has to
	stay visible while the child watches what it just did.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local ExperimentToast = {}

export type Handle = {
	Show: (message: string) -> (),
}

local FADE_IN = 0.14
local FADE_OUT = 0.3
local HOLD = 2

local VISIBLE_BACKGROUND = 0.15
local VISIBLE_TEXT = 0

function ExperimentToast.Create(): Handle
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "WorkshopZeroToast"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 52)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.BackgroundColor3 = Color3.fromRGB(24, 22, 28)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 22)
	padding.PaddingRight = UDim.new(0, 22)
	padding.Parent = frame

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 21
	label.TextColor3 = Color3.fromRGB(255, 236, 190)
	label.TextTransparency = 1
	label.TextWrapped = false
	label.Text = ""
	label.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Transparency = 0.5
	stroke.Thickness = 2
	stroke.Parent = label

	local generation = 0

	local function fade(background: number, text: number, duration: number)
		TweenService:Create(frame, TweenInfo.new(duration), { BackgroundTransparency = background })
			:Play()
		TweenService:Create(label, TweenInfo.new(duration), { TextTransparency = text }):Play()
	end

	local function show(message: string)
		if message == "" then
			return
		end

		generation += 1
		local mine = generation

		label.Text = message
		frame.Visible = true
		fade(VISIBLE_BACKGROUND, VISIBLE_TEXT, FADE_IN)

		task.delay(FADE_IN + HOLD, function()
			if generation ~= mine then
				return
			end

			fade(1, 1, FADE_OUT)

			task.delay(FADE_OUT, function()
				if generation == mine then
					frame.Visible = false
				end
			end)
		end)
	end

	return {
		Show = show,
	}
end

return table.freeze(ExperimentToast)
