--!strict

--[[
	AssetProvider

	Optional visual asset bridge.

	Workshop Zero separates physics from presentation:

		Root              simple Roblox primitive  <-- physics, mass, collision
		Visual            imported mesh             <-- appearance only

	This module supplies the "Visual" side.  It looks in a Studio-owned folder:

		ReplicatedStorage
		`-- WorkshopZeroAssets
		    |-- Components
		    |   |-- Plank
		    |   |-- Block
		    |   `-- Wheel
		    |-- Payloads
		    |   `-- Duck
		    |-- Goals
		    |   `-- GoalButton
		    `-- Props

	"Studio-owned" means Rojo never maps WorkshopZeroAssets.  The folder
	survives a Rojo sync because it is placed in ReplicatedStorage by hand in
	Studio, in a location Rojo does not write to.

	CONTRACT
	--------
	* AssetProvider.Get(category, name) -> Model?
	  Returns a clone if the asset exists; nil if not.
	  Never errors.  The game is fully playable with no asset folder at all.

	* Every cloned model has its BaseParts set to:
	      CanCollide = false
	      CanTouch   = false
	      Massless   = true
	  so an imported mesh never becomes an unintended physics body.

	* Studio-only: AssetProvider.PrintDiagnostics() writes a one-time summary
	  to Output listing which assets were found and which fell back to primitive.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ASSETS_FOLDER_NAME = "WorkshopZeroAssets"

local AssetProvider = {}

local diagnosticKeys: { string } = {}
local diagnosticStatus: { [string]: string } = {}
local diagnosticPrinted = false

local function recordDiagnostic(name: string, status: string)
	if diagnosticStatus[name] == nil then
		table.insert(diagnosticKeys, name)
	end
	diagnosticStatus[name] = status
end

local function log(message: string)
	if RunService:IsStudio() then
		print(string.format("[WZ Assets] %s", message))
	end
end

local function getAssetsRoot(): Instance?
	return ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
end

--[[
	Normalise the physics properties of every BasePart inside a cloned visual.
	The component Root (physics body) lives outside this model, so nothing here
	touches the gameplay collider.
]]
local function normaliseVisualPhysics(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
			pcall(function()
				(descendant :: any).CanQuery = false
			end)
		end
	end
end

--[[
	Studio-only validation.  Problems here do not prevent the asset from being
	used; a warning is the maximum consequence.
]]
local function validateVisual(model: Model, label: string)
	if not RunService:IsStudio() then
		return
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant.CanCollide then
				warn(
					string.format(
						"[WZ Assets] %s: %s has CanCollide=true after normalise",
						label,
						descendant.Name
					)
				)
			end
			if not descendant.Massless then
				warn(string.format("[WZ Assets] %s: %s is not Massless", label, descendant.Name))
			end
		end
	end

	if model.PrimaryPart == nil then
		warn(string.format("[WZ Assets] %s: no PrimaryPart - pivot offsets will not apply", label))
	end
end

-- Public API -------------------------------------------------------------------

--[[
	AssetProvider.Get(category, name)

	category  e.g. "Components", "Payloads", "Goals", "Props"
	name      e.g. "Plank", "Duck", "GoalButton"

	Returns a cloned Model with normalised physics, or nil if the asset does
	not exist.  Never errors.
]]
function AssetProvider.Get(category: string, name: string): Model?
	local root = getAssetsRoot()
	local label = string.format("%s/%s", category, name)

	if root == nil then
		recordDiagnostic(name, "primitive")
		return nil
	end

	local categoryFolder = root:FindFirstChild(category)
	if categoryFolder == nil then
		recordDiagnostic(name, "primitive")
		return nil
	end

	local template = categoryFolder:FindFirstChild(name)
	if template == nil or not template:IsA("Model") then
		recordDiagnostic(name, "primitive")
		return nil
	end

	local clone = template:Clone()
	normaliseVisualPhysics(clone)

	if RunService:IsStudio() then
		validateVisual(clone, label)
	end

	recordDiagnostic(name, "custom")
	log(string.format("Loaded custom asset %s", label))

	return clone
end

--[[
	Writes one clean summary to Studio Output.  Call once, after all assets
	have been requested.  Subsequent calls are no-ops.
]]
function AssetProvider.PrintDiagnostics()
	if not RunService:IsStudio() then
		return
	end

	if diagnosticPrinted then
		return
	end

	diagnosticPrinted = true

	if #diagnosticKeys == 0 then
		print("[WZ Assets] No assets were requested yet.")
		return
	end

	local lines = { "[WZ Assets]" }
	for _, key in diagnosticKeys do
		table.insert(lines, string.format("  %-12s %s", key, diagnosticStatus[key]))
	end

	print(table.concat(lines, "\n"))
end

--[[
	Clears the log so diagnostics re-run cleanly after a level restart.
]]
function AssetProvider.ResetDiagnostics()
	table.clear(diagnosticKeys)
	table.clear(diagnosticStatus)
	diagnosticPrinted = false
end

return table.freeze(AssetProvider)
