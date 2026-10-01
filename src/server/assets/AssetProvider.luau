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

	* AssetProvider.GetVisualBounds(model) and AlignVisual(model, target, mode)
	  place art by measuring it instead of trusting its pivot, so an export whose
	  origin is not the mesh centre still lands on the physics contract.

	* AssetProvider.HidePrimitives(container, keep) hides the primitive geometry
	  a visual replaced.  It never touches CanQuery: the physics Root has to stay
	  draggable and raycastable under the mesh.
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
local loggedKeys: { [string]: boolean } = {}

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

--[[
	A component is created many times per session, so the "loaded custom asset"
	line is worth saying once per asset, not once per clone.
]]
local function logOnce(key: string, message: string)
	if loggedKeys[key] then
		return
	end

	loggedKeys[key] = true
	log(message)
end

-- The eight corners of a box, used to measure a part's world-space extent
-- without caring how it is rotated.
local CORNER_SIGNS = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
}

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
			-- Anchors belong to game code.  An anchored mesh part welded to a
			-- component would pin the whole assembly and freeze the machine in
			-- TEST, so a visual never brings its own anchor in.
			descendant.Anchored = false
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

	-- Complexity & performance check
	local partCount = 0
	local meshCount = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") then
			meshCount += 1
			partCount += 1
		elseif descendant:IsA("BasePart") then
			partCount += 1
		end
	end

	if partCount > 25 or meshCount > 15 then
		warn(
			string.format(
				"[WZ Assets] %s performance warning: high geometry count (%d parts, %d MeshParts)",
				label,
				partCount,
				meshCount
			)
		)
	end
end

-- Visual measurement and placement --------------------------------------------

--[[
	World-space bounding box of the parts a player can actually see.

	Invisible helpers (trigger volumes, socket markers, hidden primitives) are
	ignored, so they can never drag the box away from the art.  Returns nil when
	nothing visible exists, which is the caller's cue to keep the primitive.
]]
function AssetProvider.GetVisualBounds(model: Model): (CFrame?, Vector3)
	local min: Vector3? = nil
	local max: Vector3? = nil

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 0.99 then
			local halfSize = descendant.Size * 0.5

			for _, sign in CORNER_SIGNS do
				local corner = descendant.CFrame * (halfSize * sign)
				min = if min == nil then corner else min:Min(corner)
				max = if max == nil then corner else max:Max(corner)
			end
		end
	end

	if min == nil or max == nil then
		return nil, Vector3.zero
	end

	return CFrame.new((min + max) * 0.5), max - min
end

--[[
	Places a cloned visual on the physics part it skins, measured rather than
	assumed.  An imported model's pivot is whatever Blender last set, so aligning
	by pivot is a coin flip; aligning by the mesh's own bounds always lands.

		mode "Center"  the visual's centre sits on target.Position
		mode "Bottom"  the visual's underside rests on the plane through
		               target.Position (a floor pivot), lifted by half its height

	Rotation is deliberately left alone.  The art's own orientation is the
	artist's business, and the component's rotation is applied to the whole
	assembly afterwards.

	Returns false when the model has no visible geometry, so the caller can fall
	back to the primitive instead of parenting an invisible visual.
]]
function AssetProvider.AlignVisual(model: Model, target: CFrame, mode: string?): boolean
	local bounds, size = AssetProvider.GetVisualBounds(model)
	if bounds == nil then
		return false
	end

	local desired = target.Position
	if mode == "Bottom" then
		desired += Vector3.new(0, size.Y * 0.5, 0)
	end

	model:PivotTo(model:GetPivot() + (desired - bounds.Position))

	return true
end

--[[
	Hides the primitive geometry a welded visual has replaced.

	Only direct BasePart children of the container are touched.  A cloned visual
	parented under that same container is a Model, so it can never be hidden by
	accident, and an invisible helper such as a goal trigger is passed in `keep`
	so its transparency and shadow settings stay exactly as built.

	CanQuery is never modified here: the physics Root must keep receiving
	raycasts so the DragDetector under the mesh still works.

	Returns how many parts were hidden.
]]
function AssetProvider.HidePrimitives(container: Instance, keep: { BasePart }?): number
	local hidden = 0

	for _, child in container:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end

		local kept = false
		if keep ~= nil then
			for _, candidate in keep do
				if candidate == child then
					kept = true
					break
				end
			end
		end

		if kept then
			continue
		end

		child.Transparency = 1
		child.CastShadow = false
		hidden += 1
	end

	return hidden
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
	logOnce(label, string.format("Loaded custom asset %s", label))

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

	local customCount = 0
	local primitiveCount = 0
	for _, rec in diagnostics do
		if rec.Status == "custom" then
			customCount += 1
		else
			primitiveCount += 1
		end
	end

	table.insert(lines, "")
	table.insert(
		lines,
		string.format(
			"%d/%d visuals are custom art, %d fall back to primitives",
			customCount,
			customCount + primitiveCount,
			primitiveCount
		)
	)

	print(table.concat(lines, "\n"))
end

--[[
	Clears the log so diagnostics re-run cleanly after a level restart.
]]
function AssetProvider.ResetDiagnostics()
	table.clear(diagnostics)
	table.clear(loggedKeys)
	diagnosticPrinted = false
end

return table.freeze(AssetProvider)
