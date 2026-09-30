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

local Shared = ReplicatedStorage.Shared
local AssetManifest = require(Shared.assets.AssetManifest)

local ASSETS_FOLDER_NAME = "WorkshopZeroAssets"

local AssetProvider = {}

type DiagnosticRecord = {
	Category: string,
	Name: string,
	Status: string,
}

local diagnostics: { [string]: DiagnosticRecord } = {}
local diagnosticPrinted = false

local function recordDiagnostic(category: string, name: string, status: string)
	local key = string.format("%s/%s", category, name)
	diagnostics[key] = {
		Category = category,
		Name = name,
		Status = status,
	}
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
	Finds a template model in the given category folder, checking primary name
	as well as any known aliases in AssetManifest.
]]
local function findTemplate(
	categoryFolder: Instance,
	category: string,
	name: string
): (Model?, AssetManifest.AssetEntry?)
	local entry = AssetManifest.GetEntry(category, name)

	-- Direct name match
	local direct = categoryFolder:FindFirstChild(name)
	if direct ~= nil and direct:IsA("Model") then
		return direct, entry
	end

	-- Check manifest canonical name
	if entry ~= nil and entry.Name ~= name then
		local canonical = categoryFolder:FindFirstChild(entry.Name)
		if canonical ~= nil and canonical:IsA("Model") then
			return canonical, entry
		end
	end

	-- Check manifest aliases
	if entry ~= nil and entry.Aliases ~= nil then
		for _, alias in entry.Aliases do
			local candidate = categoryFolder:FindFirstChild(alias)
			if candidate ~= nil and candidate:IsA("Model") then
				return candidate, entry
			end
		end
	end

	-- Fallback: case-insensitive scan of categoryFolder
	local lowerTarget = string.lower(name)
	for _, child in categoryFolder:GetChildren() do
		if child:IsA("Model") and string.lower(child.Name) == lowerTarget then
			return child, entry
		end
	end

	return nil, entry
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
	Studio-only validation for scale, collision neutrality, and PrimaryPart presence.
]]
local function validateVisual(model: Model, label: string, entry: AssetManifest.AssetEntry?)
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
		warn(
			string.format(
				"[WZ Assets] %s: no PrimaryPart - pivot offsets will not apply correctly",
				label
			)
		)
	end

	-- Scale comparison against AssetManifest ExpectedBounds
	if entry ~= nil and entry.ExpectedBounds ~= nil then
		local extents = model:GetExtentsSize()
		local actualMag = extents.Magnitude
		local expectedMag = entry.ExpectedBounds.Magnitude

		if expectedMag > 0.01 then
			local ratio = actualMag / expectedMag
			local tolerance = entry.Tolerance or 2.5
			local minRatio = 1 / tolerance

			if ratio > tolerance or ratio < minRatio then
				warn(
					string.format(
						"[WZ Assets] %s scale warning: actual size (%.1f, %.1f, %.1f) deviates from expected (%.1f, %.1f, %.1f) by %.2fx",
						label,
						extents.X,
						extents.Y,
						extents.Z,
						entry.ExpectedBounds.X,
						entry.ExpectedBounds.Y,
						entry.ExpectedBounds.Z,
						ratio
					)
				)
			end
		end
	end
end

-- Public API -------------------------------------------------------------------

--[[
	AssetProvider.Get(category, name)

	category  e.g. "Components", "Payloads", "Goals", "Props"
	name      e.g. "Plank", "Duck", "GoalButton"

	Returns a cloned Model with normalised physics, or nil if the asset does
	not exist. Never errors.
]]
function AssetProvider.Get(category: string, name: string): Model?
	local root = getAssetsRoot()
	local label = string.format("%s/%s", category, name)

	if root == nil then
		recordDiagnostic(category, name, "primitive")
		return nil
	end

	local categoryFolder = root:FindFirstChild(category)
	if categoryFolder == nil then
		recordDiagnostic(category, name, "primitive")
		return nil
	end

	local template, entry = findTemplate(categoryFolder, category, name)
	if template == nil then
		recordDiagnostic(category, name, "primitive")
		return nil
	end

	local clone = template:Clone()
	normaliseVisualPhysics(clone)

	if RunService:IsStudio() then
		validateVisual(clone, label, entry)
	end

	recordDiagnostic(category, name, "custom")
	log(string.format("Loaded custom asset %s", label))

	return clone
end

--[[
	Convenience alias for AssetProvider.Get(category, name).
]]
function AssetProvider.GetOrNil(category: string, name: string): Model?
	return AssetProvider.Get(category, name)
end

--[[
	Returns whether a custom visual exists in WorkshopZeroAssets.
]]
function AssetProvider.Has(category: string, name: string): boolean
	local root = getAssetsRoot()
	if root == nil then
		return false
	end
	local categoryFolder = root:FindFirstChild(category)
	if categoryFolder == nil then
		return false
	end
	local template = findTemplate(categoryFolder, category, name)
	return template ~= nil
end

--[[
	Pre-validates all known assets in AssetManifest against WorkshopZeroAssets.
	Useful for early Studio diagnostics.
]]
function AssetProvider.ValidateAllKnownAssets()
	if not RunService:IsStudio() then
		return
	end

	for _, category in AssetManifest.GetAllCategories() do
		local catMap = AssetManifest.GetCategory(category)
		if catMap ~= nil then
			for _, entry in catMap do
				if not diagnostics[string.format("%s/%s", category, entry.Name)] then
					local hasAsset = AssetProvider.Has(category, entry.Name)
					recordDiagnostic(
						category,
						entry.Name,
						if hasAsset then "custom" else "primitive"
					)
				end
			end
		end
	end
end

--[[
	Writes a structured summary to Studio Output grouped by Category.
	Call once after assets have been requested. Subsequent calls are no-ops.
]]
function AssetProvider.PrintDiagnostics()
	if not RunService:IsStudio() then
		return
	end

	if diagnosticPrinted then
		return
	end

	diagnosticPrinted = true

	AssetProvider.ValidateAllKnownAssets()

	local lines = { "[WZ Assets]" }

	for _, category in AssetManifest.GetAllCategories() do
		local entriesInCategory: { DiagnosticRecord } = {}
		for _, rec in diagnostics do
			if rec.Category == category then
				table.insert(entriesInCategory, rec)
			end
		end

		if #entriesInCategory > 0 then
			table.sort(entriesInCategory, function(a, b)
				return a.Name < b.Name
			end)

			table.insert(lines, "")
			table.insert(lines, category)
			for _, rec in entriesInCategory do
				table.insert(lines, string.format("  %-18s %s", rec.Name, rec.Status))
			end
		end
	end

	print(table.concat(lines, "\n"))
end

--[[
	Clears the log so diagnostics re-run cleanly after a level restart.
]]
function AssetProvider.ResetDiagnostics()
	table.clear(diagnostics)
	diagnosticPrinted = false
end

return table.freeze(AssetProvider)
