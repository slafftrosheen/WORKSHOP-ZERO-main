--!strict

--[[
	WorkshopPresentationService

	Everything in the Workshop that exists to be read rather than played with:

		the WORKSHOP ZERO sign
		the dynamic experiment wall, facing the ExperimentBay
		the component display wall, with locked / discovered state
		the physical TEST / RESET console
		the physical EXPERIMENTS panel (an entry point, not a second board)
		two warm accent lamps, so the back wall still reads at night

	WorkshopService keeps owning the shell, the props, the ExperimentBay, the
	spawn and the lighting baseline. This module only adds presentation on top
	of a shell that already exists.

	Two rules this file exists to keep:

		Presentation may communicate construction state, but it must never
		own construction state.

	Nothing here decides anything. Every label, colour and button is a
	rendering of a replicated value the server already set, and the two
	prompts on the console call the same ExperimentService funnel the HUD
	uses - there is no second path to TEST or RESET.

	Everything is built at runtime from parts and SurfaceGuis: the scene can
	be tuned from code, and a missing art asset can never make a sign vanish.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local ComponentDefinitions = require(Shared.construction.ComponentDefinitions)
local ConstructionConfig = require(Shared.construction.ConstructionConfig)
local ConstructionTypes = require(Shared.construction.ConstructionTypes)
local ExperimentDefinitions = require(Shared.experiments.ExperimentDefinitions)
local ExperimentTypes = require(Shared.experiments.ExperimentTypes)

local AssetProvider = require(script.Parent.Parent.assets.AssetProvider)
local ExperimentService = require(script.Parent.Parent.experiments.ExperimentService)
local WorkshopService = require(script.Parent.WorkshopService)

local Config = ConstructionConfig

local WorkshopPresentationService = {}

-- Visual language ------------------------------------------------------------
--
-- Industrial maker workshop: yellow painted steel, charcoal reinforcement,
-- warm off-white type. Not a spaceship, not a factory, not a baseplate.

local COLORS = {
	Panel = Color3.fromRGB(32, 34, 40),
	PanelInset = Color3.fromRGB(26, 28, 34),
	Charcoal = Color3.fromRGB(44, 46, 52),
	Steel = Color3.fromRGB(96, 100, 110),
	Yellow = Color3.fromRGB(240, 185, 45),
	OffWhite = Color3.fromRGB(238, 232, 216),
	Text = Color3.fromRGB(234, 238, 246),
	Muted = Color3.fromRGB(150, 156, 172),
	Locked = Color3.fromRGB(120, 126, 140),
	Beak = Color3.fromRGB(245, 150, 50),
	Green = Color3.fromRGB(52, 172, 96),
	Red = Color3.fromRGB(200, 68, 58),
	Off = Color3.fromRGB(70, 74, 82),
	Bulb = Color3.fromRGB(255, 240, 210),
}

local STATUS_STYLE: { [string]: { text: Color3, background: Color3, light: Color3 } } = {
	Build = {
		text = Color3.fromRGB(150, 235, 180),
		background = Color3.fromRGB(26, 56, 42),
		light = Color3.fromRGB(70, 210, 120),
	},
	Testing = {
		text = Color3.fromRGB(255, 202, 122),
		background = Color3.fromRGB(66, 46, 20),
		light = Color3.fromRGB(242, 170, 56),
	},
	Success = {
		text = Color3.fromRGB(212, 238, 255),
		background = Color3.fromRGB(30, 54, 78),
		light = Color3.fromRGB(150, 200, 255),
	},
	Loading = {
		text = Color3.fromRGB(172, 178, 194),
		background = Color3.fromRGB(34, 36, 44),
		light = Color3.fromRGB(120, 126, 140),
	},
}

-- Scene layout ---------------------------------------------------------------
--
-- The back wall belongs to WorkshopService (130 wide, 32 tall, front face at
-- z = -41). These are the readable things hung on it, left to right:
--
--   COMPONENT WALL   wall panel   EXPERIMENT WALL   wall panel   CONNECTOR BOARD
--       x=-34          x=-18           x=0            x=+18          x=+34
--
-- with the sign above the centre and the console on the floor below, left of
-- centre, just outside the ExperimentBay.

local WALL_FACE_Z = -41
local PANEL_Z = -40.7 -- centre of a 0.6-thick panel, flush on the wall face

type PanelSpec = {
	X: number,
	Y: number,
	Width: number,
	Height: number,
	Thickness: number,
}

local SIGN: PanelSpec = { X = 0, Y = 26, Width = 26, Height = 8, Thickness = 0.6 }
local EXPERIMENT_WALL: PanelSpec = { X = 0, Y = 13, Width = 24, Height = 14, Thickness = 0.6 }
local COMPONENT_WALL: PanelSpec = { X = -34, Y = 13, Width = 12, Height = 14, Thickness = 0.6 }
local EXPERIMENTS_PANEL: PanelSpec = { X = 34, Y = 6.5, Width = 10, Height = 3, Thickness = 0.4 }

local CONSOLE = { X = -11, Z = -38, Width = 8, Depth = 4 }

-- Canvas sizes keep the same aspect as the part they are drawn on, so a
-- SurfaceGui never stretches its type.
local SIGN_CANVAS = Vector2.new(1300, 400)
local EXPERIMENT_CANVAS = Vector2.new(1200, 700)
local COMPONENT_CANVAS = Vector2.new(900, 1050)
local PANEL_CANVAS = Vector2.new(1000, 300)

local CELL_COLUMNS = 4
local CELL_WIDTH = 210
local CELL_HEIGHT = 440
local GRID_X = 30
local GRID_Y = 130

-- The order the wall shows the catalogue in. Which parts are *discovered* is
-- derived from the experiment inventories, never written here.
local COMPONENT_ORDER = { "Plank", "Block", "Wheel", "Motor", "Spring", "Fan", "Hook", "Winch" }

-- Runtime state --------------------------------------------------------------

type DisplayPart = {
	Part: BasePart,
	Transparency: number,
}

type ComponentCell = {
	ComponentType: string,
	NameLabel: TextLabel,
	Parts: { DisplayPart },
	Locked: boolean,
}

type ExperimentWall = {
	NumberLabel: TextLabel,
	NameLabel: TextLabel,
	ObjectiveLabel: TextLabel,
	StatusLabel: TextLabel,
	StatusFrame: Frame,
}

type ConsoleHandles = {
	TestCap: BasePart,
	ResetCap: BasePart,
	TestPrompt: ProximityPrompt,
	ResetPrompt: ProximityPrompt,
	TestWord: TextLabel,
	ResetWord: TextLabel,
	StatusLight: BasePart,
	StatusWord: TextLabel,
}

type Display = {
	Wall: ExperimentWall,
	Console: ConsoleHandles,
	Cells: { ComponentCell },
}

local display: Display? = nil
local started = false
local capTweens: { [BasePart]: Tween } = {}

local currentDefinition: ExperimentTypes.ExperimentDefinition = ExperimentDefinitions.GetDefault()
local experimentState: ExperimentTypes.ExperimentState = "Loading"
local simulationState: ConstructionTypes.SimulationState = "Build"
local unlockedIndex = 1

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Presentation] %s", message))
	end
end

-- Small building blocks -------------------------------------------------------

local function createPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	parent: Instance,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = material
	part.CollisionGroup = Config.CollisionGroupEnvironment
	part.Parent = parent

	return part
end

--[[
	A flat panel hanging on the back wall, with its SurfaceGui already sized to
	the same aspect ratio as the part so the type never stretches.
]]
local function createWallPanel(
	spec: PanelSpec,
	canvas: Vector2,
	name: string,
	parent: Instance
): (Part, SurfaceGui)
	local panel = createPart(
		name,
		Vector3.new(spec.Width, spec.Height, spec.Thickness),
		CFrame.new(spec.X, spec.Y, PANEL_Z),
		parent,
		COLORS.Panel,
		Enum.Material.Metal
	)

	local gui = Instance.new("SurfaceGui")
	gui.Name = name .. "Gui"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = canvas
	-- The sign and the boards must be legible whatever the hour is.
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = panel

	local frame = Instance.new("Frame")
	frame.Name = "Trim"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = COLORS.Panel
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Yellow
	stroke.Thickness = 5
	stroke.Transparency = 0.25
	stroke.Parent = frame

	return panel, gui
end

local function createLabel(
	parent: Instance,
	name: string,
	position: Vector2,
	size: Vector2,
	textSize: number,
	color: Color3,
	text: string,
	bold: boolean
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromOffset(position.X, position.Y)
	label.Size = UDim2.fromOffset(size.X, size.Y)
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextSize = textSize
	label.TextColor3 = color
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent

	return label
end

local function centreText(label: TextLabel)
	label.TextXAlignment = Enum.TextXAlignment.Center
end

local function createAccent(parent: Instance, height: number)
	local bar = Instance.new("Frame")
	bar.Name = "Accent"
	bar.Size = UDim2.new(1, 0, 0, height)
	bar.BackgroundColor3 = COLORS.Yellow
	bar.BorderSizePixel = 0
	bar.ZIndex = 2
	bar.Parent = parent
end

--[[
	Splits an objective across two balanced lines.

	"Get the duck to the button." becomes "GET THE DUCK / TO THE BUTTON", and
	the copy comes from ExperimentDefinitions either way: nothing about an
	experiment is written on the wall in this file.
]]
local function twoLineShout(objective: string): string
	local clean = string.upper(string.gsub(objective, "%.$", ""))
	local words = string.split(clean, " ")
	if #words <= 2 then
		return clean
	end

	local bestSplit = 1
	local bestScore = math.huge
	for index = 1, #words - 1 do
		local first = table.concat(words, " ", 1, index)
		local second = table.concat(words, " ", index + 1, #words)
		local score = math.max(#first, #second)
		if score < bestScore then
			bestScore = score
			bestSplit = index
		end
	end

	return table.concat(words, " ", 1, bestSplit) .. "\n" .. table.concat(words, " ", bestSplit + 1)
end

-- Sign -------------------------------------------------------------------------

local function buildSign(shell: Instance)
	local _, gui = createWallPanel(SIGN, SIGN_CANVAS, "WorkshopZeroSign", shell)

	-- A small procedural duck: circle head, oval body, orange beak. No emoji,
	-- no image asset, nothing that can fail to load.
	local duck = Instance.new("Frame")
	duck.Name = "Duck"
	duck.Position = UDim2.fromOffset(60, 90)
	duck.Size = UDim2.fromOffset(220, 230)
	duck.BackgroundTransparency = 1
	duck.Parent = gui

	local function blob(
		name: string,
		position: Vector2,
		size: Vector2,
		color: Color3,
		round: number
	)
		local part = Instance.new("Frame")
		part.Name = name
		part.Position = UDim2.fromOffset(position.X, position.Y)
		part.Size = UDim2.fromOffset(size.X, size.Y)
		part.BackgroundColor3 = color
		part.BorderSizePixel = 0
		part.Parent = duck

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = part
	end

	blob("Body", Vector2.new(0, 110), Vector2.new(170, 120), COLORS.OffWhite, 1)
	blob("Head", Vector2.new(85, 30), Vector2.new(100, 100), COLORS.OffWhite, 1)
	blob("Beak", Vector2.new(170, 74), Vector2.new(36, 22), COLORS.Beak, 0)
	blob("Eye", Vector2.new(124, 54), Vector2.new(16, 16), Color3.fromRGB(30, 30, 38), 1)

	createLabel(
		gui,
		"Workshop",
		Vector2.new(330, 40),
		Vector2.new(930, 110),
		96,
		COLORS.OffWhite,
		"WORKSHOP",
		true
	)
	-- ZERO is the dominant word on the sign, by design.
	createLabel(
		gui,
		"Zero",
		Vector2.new(330, 150),
		Vector2.new(930, 230),
		210,
		COLORS.Yellow,
		"ZERO",
		true
	)

	log(string.format("Sign built at (%d, %d)", SIGN.X, SIGN.Y))
end

-- Experiment wall ---------------------------------------------------------------

local function buildExperimentWall(shell: Instance): ExperimentWall
	local _, gui = createWallPanel(EXPERIMENT_WALL, EXPERIMENT_CANVAS, "ExperimentWall", shell)
	createAccent(gui, 16)

	local numberLabel = createLabel(
		gui,
		"Number",
		Vector2.new(40, 40),
		Vector2.new(600, 230),
		215,
		COLORS.Yellow,
		"01",
		true
	)
	local nameLabel = createLabel(
		gui,
		"Title",
		Vector2.new(40, 275),
		Vector2.new(1120, 110),
		84,
		COLORS.OffWhite,
		"SAVE THE DUCK",
		true
	)
	local objectiveLabel = createLabel(
		gui,
		"Objective",
		Vector2.new(40, 400),
		Vector2.new(1120, 170),
		54,
		COLORS.Text,
		"GET THE DUCK\nTO THE BUTTON",
		false
	)
	objectiveLabel.TextWrapped = true
	objectiveLabel.TextYAlignment = Enum.TextYAlignment.Top

	local statusFrame = Instance.new("Frame")
	statusFrame.Name = "StatusPill"
	statusFrame.Position = UDim2.fromOffset(40, 590)
	statusFrame.Size = UDim2.fromOffset(420, 80)
	statusFrame.BackgroundColor3 = STATUS_STYLE.Loading.background
	statusFrame.BorderSizePixel = 0
	statusFrame.Parent = gui

	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 14)
	statusCorner.Parent = statusFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.fromScale(1, 1)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 50
	statusLabel.TextColor3 = STATUS_STYLE.Loading.text
	statusLabel.Text = "LOADING"
	statusLabel.Parent = statusFrame

	return {
		NumberLabel = numberLabel,
		NameLabel = nameLabel,
		ObjectiveLabel = objectiveLabel,
		StatusLabel = statusLabel,
		StatusFrame = statusFrame,
	}
end

-- Component wall -----------------------------------------------------------------

local function newPrimitiveModel(componentType: string): Model
	local definition = ComponentDefinitions.Get(componentType)

	local model = Instance.new("Model")
	model.Name = componentType

	local part = Instance.new("Part")
	part.Name = "Shape"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	if definition ~= nil then
		part.Shape = definition.Shape
		part.Size = definition.Size
		part.Color = definition.Color
		part.Material = definition.Material
	else
		part.Size = Vector3.new(2, 2, 2)
		part.Color = COLORS.Muted
		part.Material = Enum.Material.SmoothPlastic
	end

	part.Parent = model
	model.PrimaryPart = part

	return model
end

--[[
	One display-only model for a component: the imported art when it exists,
	a plain primitive when it does not.

	Never a construction component: no DragDetector, no ComponentId, no
	constraint, no physics. Every part is frozen so even a WorldModel has
	nothing to simulate.
]]
local function buildDisplayModel(componentType: string): (Model, { DisplayPart })
	local model: Model
	local visual = AssetProvider.Get("Components", componentType)

	if visual ~= nil then
		for _, descendant in visual:GetDescendants() do
			if descendant:IsA("DragDetector") then
				-- Construction identity does not belong on a wall.
				descendant:Destroy()
			end
		end
	end

	-- Art with no visible geometry would hang an empty card on the wall. The
	-- primitive is the honest answer here for the same reason it is on the
	-- machine itself.
	if visual ~= nil and AssetProvider.GetVisualBounds(visual) == nil then
		visual:Destroy()
		visual = nil
	end

	if visual ~= nil then
		model = visual
	else
		model = newPrimitiveModel(componentType)
	end

	if model.PrimaryPart == nil then
		local first = model:FindFirstChildOfClass("BasePart")
		if first ~= nil then
			model.PrimaryPart = first
		end
	end

	local records: { DisplayPart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(records, { Part = descendant, Transparency = descendant.Transparency })

			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
			descendant.Massless = true
		end
	end

	return model, records
end

local function buildComponentWall(shell: Instance): { ComponentCell }
	local _, gui = createWallPanel(COMPONENT_WALL, COMPONENT_CANVAS, "ComponentWall", shell)
	createAccent(gui, 14)

	createLabel(
		gui,
		"Header",
		Vector2.new(GRID_X, 40),
		Vector2.new(840, 60),
		46,
		COLORS.Muted,
		"COMPONENTS",
		true
	)

	local cells: { ComponentCell } = {}

	for index, componentType in COMPONENT_ORDER do
		local column = (index - 1) % CELL_COLUMNS
		local row = math.floor((index - 1) / CELL_COLUMNS)

		local cell = Instance.new("Frame")
		cell.Name = componentType
		cell.Position = UDim2.fromOffset(GRID_X + column * CELL_WIDTH, GRID_Y + row * CELL_HEIGHT)
		cell.Size = UDim2.fromOffset(CELL_WIDTH, CELL_HEIGHT)
		cell.BackgroundTransparency = 1
		cell.Parent = gui

		local card = Instance.new("Frame")
		card.Name = "Card"
		card.Position = UDim2.fromOffset(5, 5)
		card.Size = UDim2.fromOffset(CELL_WIDTH - 10, CELL_HEIGHT - 30)
		card.BackgroundColor3 = COLORS.PanelInset
		card.BorderSizePixel = 0
		card.Parent = cell

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = card

		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "Viewport"
		viewport.Position = UDim2.fromOffset(10, 10)
		viewport.Size = UDim2.fromOffset(CELL_WIDTH - 30, 300)
		viewport.BackgroundColor3 = COLORS.PanelInset
		viewport.Ambient = Color3.fromRGB(158, 158, 168)
		viewport.LightColor = Color3.fromRGB(255, 250, 242)
		viewport.BorderSizePixel = 0
		viewport.Parent = card

		local camera = Instance.new("Camera")
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		local world = Instance.new("WorldModel")
		world.Parent = viewport

		local nameLabel = createLabel(
			card,
			"Name",
			Vector2.new(10, 330),
			Vector2.new(CELL_WIDTH - 30, 60),
			40,
			COLORS.Text,
			string.upper(componentType),
			true
		)
		centreText(nameLabel)

		local model, records = buildDisplayModel(componentType)
		model.Parent = world

		-- Centre it in front of the camera, imported art origin or not.
		local bounds, measured = AssetProvider.GetVisualBounds(model)
		if bounds ~= nil then
			local pivot = model:GetPivot()
			model:PivotTo(pivot + (Vector3.zero - bounds.Position))
		end

		local definition = ComponentDefinitions.Get(componentType)
		local fallback = if definition ~= nil then definition.Size else Vector3.new(2, 2, 2)
		local size = if measured.Magnitude > 0.05 then measured else fallback

		local radius = math.max(size.Magnitude * 0.5, 1.5)
		local direction = Vector3.new(0.55, 0.4, -0.73).Unit
		camera.CFrame = CFrame.lookAt(direction * (radius * 2.8), Vector3.zero)

		table.insert(cells, {
			ComponentType = componentType,
			NameLabel = nameLabel,
			Parts = records,
			Locked = false,
		})
	end

	return cells
end

-- Physical console ----------------------------------------------------------------

local function pressButton(cap: BasePart, base: CFrame)
	local previous = capTweens[cap]
	if previous ~= nil then
		previous:Cancel()
	end

	local down = base * CFrame.new(0, -0.25, 0)
	local downTween =
		TweenService:Create(cap, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { CFrame = down })
	capTweens[cap] = downTween
	downTween:Play()

	task.delay(0.1, function()
		if cap.Parent == nil then
			return
		end

		local running = capTweens[cap]
		if running ~= nil then
			running:Cancel()
		end

		local upTween = TweenService:Create(
			cap,
			TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = base }
		)
		capTweens[cap] = upTween
		upTween:Play()
	end)
end

local function buildConsole(shell: Instance): ConsoleHandles
	local consoleFolder = Instance.new("Folder")
	consoleFolder.Name = "TestConsole"
	consoleFolder.Parent = shell

	local x = CONSOLE.X
	local z = CONSOLE.Z

	local base = createPart(
		"ConsoleBase",
		Vector3.new(CONSOLE.Width + 1, 0.5, CONSOLE.Depth + 1),
		CFrame.new(x, 0.25, z),
		consoleFolder,
		COLORS.Charcoal,
		Enum.Material.Metal
	)
	base.CanCollide = true

	local body = createPart(
		"ConsoleBody",
		Vector3.new(CONSOLE.Width, 3.4, CONSOLE.Depth),
		CFrame.new(x, 2.2, z),
		consoleFolder,
		COLORS.Steel,
		Enum.Material.Metal
	)
	body.CanCollide = true

	local top = createPart(
		"ConsoleTop",
		Vector3.new(CONSOLE.Width + 0.6, 0.5, CONSOLE.Depth + 0.6),
		CFrame.new(x, 4.15, z),
		consoleFolder,
		COLORS.Yellow,
		Enum.Material.Metal
	)
	top.CanCollide = true

	-- Front face: which button is which, and the console's own name.
	local face = Instance.new("SurfaceGui")
	face.Name = "FaceGui"
	face.Face = Enum.NormalId.Back
	face.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	face.CanvasSize = Vector2.new(800, 340)
	face.LightInfluence = 0
	face.Parent = body

	local testWord = createLabel(
		face,
		"TestWord",
		Vector2.new(80, 110),
		Vector2.new(200, 60),
		42,
		COLORS.Green,
		"TEST",
		true
	)
	centreText(testWord)

	local resetWord = createLabel(
		face,
		"ResetWord",
		Vector2.new(520, 110),
		Vector2.new(200, 60),
		42,
		COLORS.Red,
		"RESET",
		true
	)
	centreText(resetWord)

	local title = createLabel(
		face,
		"ConsoleTitle",
		Vector2.new(0, 220),
		Vector2.new(800, 70),
		46,
		COLORS.OffWhite,
		"TEST CONSOLE",
		true
	)
	centreText(title)

	-- The status light: a glowing bar across the front, word included, so the
	-- console reads on its own from close up.
	local light = createPart(
		"StatusLight",
		Vector3.new(6, 0.8, 0.3),
		CFrame.new(x, 3.3, z + CONSOLE.Depth * 0.5 + 0.15),
		consoleFolder,
		COLORS.Off,
		Enum.Material.Neon
	)

	local lightGui = Instance.new("SurfaceGui")
	lightGui.Name = "LightGui"
	lightGui.Face = Enum.NormalId.Back
	lightGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	lightGui.CanvasSize = Vector2.new(600, 80)
	lightGui.LightInfluence = 0
	lightGui.Parent = light

	local statusWord = Instance.new("TextLabel")
	statusWord.Name = "Word"
	statusWord.Size = UDim2.fromScale(1, 1)
	statusWord.BackgroundTransparency = 1
	statusWord.Font = Enum.Font.GothamBold
	statusWord.TextSize = 44
	statusWord.TextColor3 = Color3.fromRGB(24, 26, 32)
	statusWord.Text = "LOADING"
	statusWord.Parent = lightGui

	-- Two chunky round buttons in dark sockets, exactly as the scene sketch
	-- asks for: a ConsoleBody, a TestButton, a ResetButton and a StatusLight.
	local function makeButton(
		name: string,
		buttonX: number,
		color: Color3
	): (Model, BasePart, ProximityPrompt)
		local button = Instance.new("Model")
		button.Name = name .. "Button"
		button.Parent = consoleFolder

		local socket = createPart(
			"Socket",
			Vector3.new(0.3, 3.8, 3.8),
			CFrame.new(buttonX, 4.55, z) * CFrame.Angles(0, 0, math.rad(90)),
			button,
			COLORS.Charcoal,
			Enum.Material.Metal
		)
		socket.Shape = Enum.PartType.Cylinder

		local cap = createPart(
			"Cap",
			Vector3.new(0.6, 3.0, 3.0),
			CFrame.new(buttonX, 4.9, z) * CFrame.Angles(0, 0, math.rad(90)),
			button,
			color,
			Enum.Material.SmoothPlastic
		)
		cap.Shape = Enum.PartType.Cylinder
		button.PrimaryPart = cap

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = name .. "Prompt"
		prompt.ActionText = if name == "Test" then "TEST" else "RESET"
		prompt.ObjectText = "TEST CONSOLE"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = cap

		return button, cap, prompt
	end

	local _, testCap, testPrompt = makeButton("Test", x - 2.2, COLORS.Green)
	local _, resetCap, resetPrompt = makeButton("Reset", x + 2.2, COLORS.Red)

	-- Captured now, while the caps are at rest: a press that read its own
	-- current CFrame would slowly weld the button into the console.
	local testBase = testCap.CFrame
	local resetBase = resetCap.CFrame

	-- The console calls the same ExperimentService funnel the HUD calls. It is
	-- a second *button*, never a second path.
	testPrompt.Triggered:Connect(function(player: Player)
		if ExperimentService.HandleSimulationRequest(player, "Test") then
			pressButton(testCap, testBase)
		end
	end)

	resetPrompt.Triggered:Connect(function(player: Player)
		if ExperimentService.HandleSimulationRequest(player, "Reset") then
			pressButton(resetCap, resetBase)
		end
	end)

	log(string.format("Test console built at (%d, 0, %d)", x, z))

	return {
		TestCap = testCap,
		ResetCap = resetCap,
		TestPrompt = testPrompt,
		ResetPrompt = resetPrompt,
		TestWord = testWord,
		ResetWord = resetWord,
		StatusLight = light,
		StatusWord = statusWord,
	}
end

-- Experiments panel ----------------------------------------------------------------

local function buildExperimentsPanel(shell: Instance, remotes: ExperimentTypes.ExperimentRemotes)
	local panel, gui = createWallPanel(EXPERIMENTS_PANEL, PANEL_CANVAS, "ExperimentsPanel", shell)
	createAccent(gui, 14)

	local title = createLabel(
		gui,
		"Title",
		Vector2.new(0, 60),
		Vector2.new(1000, 110),
		76,
		COLORS.OffWhite,
		"EXPERIMENTS",
		true
	)
	centreText(title)

	local hint = createLabel(
		gui,
		"Hint",
		Vector2.new(0, 175),
		Vector2.new(1000, 70),
		40,
		COLORS.Muted,
		"OPEN THE BOARD",
		false
	)
	centreText(hint)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ExperimentsPrompt"
	prompt.ActionText = "OPEN"
	prompt.ObjectText = "EXPERIMENTS"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = panel

	-- The panel is an entry point. The board itself stays on the client, and
	-- only the player who pressed gets asked to open it.
	prompt.Triggered:Connect(function(player: Player)
		remotes.OpenExperimentBoard:FireClient(player)
	end)

	log(
		string.format(
			"Experiments panel built at (%d, %d)",
			EXPERIMENTS_PANEL.X,
			EXPERIMENTS_PANEL.Y
		)
	)
end

-- Ambient ---------------------------------------------------------------------

local function buildAmbient(shell: Instance)
	local lamps = Instance.new("Folder")
	lamps.Name = "PresentationLamps"
	lamps.Parent = shell

	for _, x in { -17, 17 } do
		createPart(
			"LampFixture",
			Vector3.new(1.6, 1.6, 1.2),
			CFrame.new(x, SIGN.Y, WALL_FACE_Z + 0.6),
			lamps,
			COLORS.Charcoal,
			Enum.Material.Metal
		)

		local bulb = createPart(
			"LampBulb",
			Vector3.new(1.2, 0.7, 1.2),
			CFrame.new(x, SIGN.Y, WALL_FACE_Z + 1.4),
			lamps,
			COLORS.Bulb,
			Enum.Material.Neon
		)

		local light = Instance.new("PointLight")
		light.Name = "AccentLight"
		light.Color = Color3.fromRGB(255, 236, 208)
		light.Brightness = 1.4
		light.Range = 26
		light.Shadows = false
		light.Parent = bulb
	end
end

-- Refresh --------------------------------------------------------------------

local function statusKey(): string
	if experimentState == "Success" then
		return "Success"
	elseif experimentState == "Loading" then
		return "Loading"
	elseif experimentState == "Testing" then
		return "Testing"
	end

	return "Build"
end

local function applyCellLock(cell: ComponentCell, locked: boolean)
	if cell.Locked == locked then
		return
	end
	cell.Locked = locked

	if locked then
		-- A dimmed silhouette and a question mark: the shape of the thing,
		-- without giving away what it is.
		for _, record in cell.Parts do
			record.Part.Transparency = 0.72
		end
		cell.NameLabel.Text = "???"
		cell.NameLabel.TextColor3 = COLORS.Locked
	else
		for _, record in cell.Parts do
			record.Part.Transparency = record.Transparency
		end
		cell.NameLabel.Text = string.upper(cell.ComponentType)
		cell.NameLabel.TextColor3 = COLORS.Text
	end
end

local function refresh()
	local current = display
	if current == nil then
		return
	end

	-- Experiment wall ------------------------------------------------------
	if not ExperimentDefinitions.IsOpenWorkshopId(currentDefinition.Id) then
		current.Wall.NumberLabel.Text = string.format("%02d", currentDefinition.Number)
	else
		-- Open Workshop is not a number, and must not read as experiment 000.
		current.Wall.NumberLabel.Text = "FREE"
	end
	current.Wall.NameLabel.Text = currentDefinition.Name
	current.Wall.ObjectiveLabel.Text = twoLineShout(currentDefinition.Objective)

	local key = statusKey()
	local style = STATUS_STYLE[key]
	current.Wall.StatusLabel.Text = string.upper(key)
	current.Wall.StatusLabel.TextColor3 = style.text
	current.Wall.StatusFrame.BackgroundColor3 = style.background

	-- Console --------------------------------------------------------------
	local building = simulationState == "Build"
		and experimentState ~= "Success"
		and experimentState ~= "Loading"
	local testing = simulationState == "Testing" and experimentState ~= "Success"

	local console = current.Console
	console.TestPrompt.Enabled = building
	console.ResetPrompt.Enabled = testing
	console.TestWord.TextColor3 = if building then COLORS.Green else COLORS.Off
	console.ResetWord.TextColor3 = if testing then COLORS.Red else COLORS.Off
	console.TestCap.Color = if building then COLORS.Green else COLORS.Off
	console.ResetCap.Color = if testing then COLORS.Red else COLORS.Off
	console.StatusLight.Color = style.light
	console.StatusWord.Text = string.upper(key)

	-- Component wall -------------------------------------------------------
	for _, cell in current.Cells do
		local introducedAt = ExperimentDefinitions.GetComponentIntroducedAt(cell.ComponentType)
		local discovered = introducedAt == nil or unlockedIndex >= introducedAt
		applyCellLock(cell, not discovered)
	end
end

-- Wiring --------------------------------------------------------------------

local function watch(remotes: ExperimentTypes.ExperimentRemotes)
	remotes.CurrentExperimentId:GetPropertyChangedSignal("Value"):Connect(function()
		local found = ExperimentDefinitions.Get(remotes.CurrentExperimentId.Value)
		if found ~= nil then
			currentDefinition = found
		end
		refresh()
	end)

	remotes.ExperimentState:GetPropertyChangedSignal("Value"):Connect(function()
		local parsed = ExperimentTypes.ToExperimentState(remotes.ExperimentState.Value)
		if parsed ~= nil then
			experimentState = parsed
		end
		refresh()
	end)

	remotes.SimulationState:GetPropertyChangedSignal("Value"):Connect(function()
		local value = remotes.SimulationState.Value
		if value == "Build" or value == "Testing" or value == "Resetting" then
			simulationState = value
		end
		refresh()
	end)

	remotes.UnlockedExperimentIndex:GetPropertyChangedSignal("Value"):Connect(function()
		unlockedIndex = remotes.UnlockedExperimentIndex.Value
		refresh()
	end)
end

-- Start -----------------------------------------------------------------------

--[[
	Called once by the server bootstrap, after the remotes exist and before
	the first experiment loads, so the wall is already correct when the bay
	fills in.
]]
function WorkshopPresentationService.Start(remotes: ExperimentTypes.ExperimentRemotes)
	if started or Config.EnablePrototypeWorkshop then
		return
	end
	started = true

	local shell = WorkshopService.GetShell()

	-- Idempotent against a shell that already carries presentation: replace
	-- it rather than stacking a second sign on top of the first.
	for _, name in
		{
			"WorkshopZeroSign",
			"ExperimentWall",
			"ComponentWall",
			"ExperimentsPanel",
			"TestConsole",
			"PresentationLamps",
		}
	do
		local stale = shell:FindFirstChild(name)
		if stale ~= nil then
			stale:Destroy()
		end
	end

	buildSign(shell)
	local wall = buildExperimentWall(shell)
	local cells = buildComponentWall(shell)
	buildExperimentsPanel(shell, remotes)
	local console = buildConsole(shell)
	buildAmbient(shell)

	display = {
		Wall = wall,
		Console = console,
		Cells = cells,
	}

	-- Seed from whatever the server has already decided.
	local initialDefinition = ExperimentDefinitions.Get(remotes.CurrentExperimentId.Value)
	if initialDefinition ~= nil then
		currentDefinition = initialDefinition
	end

	local parsedState = ExperimentTypes.ToExperimentState(remotes.ExperimentState.Value)
	if parsedState ~= nil then
		experimentState = parsedState
	end

	local simState = remotes.SimulationState.Value
	if simState == "Build" or simState == "Testing" or simState == "Resetting" then
		simulationState = simState
	end

	unlockedIndex = remotes.UnlockedExperimentIndex.Value

	watch(remotes)
	refresh()

	log("Presentation attached to the Workshop shell")
end

function WorkshopPresentationService.IsBuilt(): boolean
	return display ~= nil
end

return table.freeze(WorkshopPresentationService)
