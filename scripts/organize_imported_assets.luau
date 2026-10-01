--!strict

--[[
	Workshop Zero - Organize Imported Assets

	A Studio Command Bar utility.  Import the .glb files from
	assets/export/roblox/ with File -> Import 3D, then copy this whole file,
	paste it into the Command Bar and press Enter.

	It is the bridge between "nine meshes were imported into Studio" and "the
	game renders them instead of its primitives".

	What it does:
	  1. Ensures ReplicatedStorage.WorkshopZeroAssets and its category folders.
	  2. Finds each imported model, wherever the importer dropped it.
	  3. Guarantees a PrimaryPart, so model pivots behave.
	  4. Normalizes physics: CanCollide=false, CanTouch=false, Massless=true,
	     Anchored=false.  Anchors are game code's business: a stray anchored
	     mesh part would pin a whole machine during TEST.
	  5. Renames each model to its canonical asset name and files it under the
	     right category folder.
	  6. Reports measured size against AssetManifest, so a mis-scaled export is
	     loud instead of mysterious.

	Missing files are fine.  Any asset the game cannot find keeps its primitive,
	and every experiment stays playable.

	Pivots are no longer part of this contract.  AssetProvider measures the
	bounding box of each cloned visual and places it - components by their
	centre, payloads, goals and props by their underside - so an export origin
	that is not the mesh centre cannot bury art in the floor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ASSETS_FOLDER_NAME = "WorkshopZeroAssets"
local CATEGORIES = { "Components", "Payloads", "Goals", "Props" }

type AssetTarget = {
	Category: string,
	CanonicalName: string,
	SourceFile: string,
	Patterns: { string },
}

-- Kept in the same order as docs/ASSET_WISHLIST.md.
local ASSET_TARGETS: { AssetTarget } = {
	{
		Category = "Components",
		CanonicalName = "Plank",
		SourceFile = "plank_beam_01.glb",
		Patterns = { "plank_beam_01", "plank", "plankbeam" },
	},
	{
		Category = "Components",
		CanonicalName = "Block",
		SourceFile = "block_cube_01.glb",
		Patterns = { "block_cube_01", "block", "constructionblock" },
	},
	{
		Category = "Components",
		CanonicalName = "Wheel",
		SourceFile = "wheel_rubber_01.glb",
		Patterns = { "wheel_rubber_01", "wheel", "rubberwheel" },
	},
	{
		Category = "Components",
		CanonicalName = "Motor",
		SourceFile = "motor_electric_01.glb",
		Patterns = { "motor_electric_01", "motor", "electricmotor" },
	},
	{
		Category = "Payloads",
		CanonicalName = "Duck",
		SourceFile = "duck_rubber_01.glb",
		Patterns = { "duck_rubber_01", "duck", "rubberduck" },
	},
	{
		Category = "Goals",
		CanonicalName = "GoalButton",
		SourceFile = "button_goal_red_01.glb",
		Patterns = { "button_goal_red_01", "goalbutton", "bigredbutton", "button_goal" },
	},
	{
		Category = "Props",
		CanonicalName = "MakerWorkbench",
		SourceFile = "workbench_maker_01.glb",
		Patterns = { "workbench_maker_01", "workbench", "makerworkbench" },
	},
	{
		Category = "Props",
		CanonicalName = "ToolStorageRack",
		SourceFile = "rack_tool_01.glb",
		Patterns = { "rack_tool_01", "toolstoragerack", "toolrack" },
	},
	{
		Category = "Props",
		CanonicalName = "WorkshopWallPanel",
		SourceFile = "wall_panel_01.glb",
		Patterns = { "wall_panel_01", "workshopwallpanel", "wallpanel" },
	},
}

local manifestModule: any = nil
local shared = ReplicatedStorage:FindFirstChild("Shared")
if shared ~= nil then
	local assets = shared:FindFirstChild("assets")
	if assets ~= nil then
		local module = assets:FindFirstChild("AssetManifest")
		if module ~= nil and module:IsA("ModuleScript") then
			manifestModule = require(module)
		end
	end
end

-- Helpers ---------------------------------------------------------------------

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function matchesPattern(name: string, patterns: { string }): boolean
	local lower = string.lower(name)
	for _, pattern in patterns do
		if string.find(lower, pattern, 1, true) ~= nil then
			return true
		end
	end
	return false
end

--[[
	Depth-first search.  The 3D importer drops models straight into Workspace,
	but a user who imported into a folder, or into ReplicatedStorage while a
	folder was selected, should still be served.
]]
local function findImported(root: Instance, patterns: { string }): Instance?
	local stack: { Instance } = { root }
	while #stack > 0 do
		local current = table.remove(stack)
		if current == nil then
			break
		end

		for _, child in current:GetChildren() do
			if
				(child:IsA("Model") or child:IsA("MeshPart"))
				and matchesPattern(child.Name, patterns)
			then
				return child
			end
			table.insert(stack, child)
		end
	end

	return nil
end

local function ensureModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	end

	if instance:IsA("MeshPart") then
		-- A single-mesh import: wrap it so the game always deals with a Model.
		local wrapper = Instance.new("Model")
		wrapper.Name = instance.Name
		instance.Parent = wrapper
		return wrapper
	end

	return nil
end

local function normalizePhysics(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = true
			-- Anchors belong to game code: props are anchored when they are
			-- placed, components are anchored in BUILD and freed in TEST.
			descendant.Anchored = false
			pcall(function()
				(descendant :: any).CanQuery = false
			end)
		end
	end
end

local function findLargestPart(model: Model): BasePart?
	local largest: BasePart? = nil
	local largestVolume = -1

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > largestVolume then
				largestVolume = volume
				largest = descendant
			end
		end
	end

	return largest
end

local function measure(model: Model): Vector3
	local min: Vector3? = nil
	local max: Vector3? = nil
	local signs = {
		Vector3.new(-1, -1, -1),
		Vector3.new(-1, -1, 1),
		Vector3.new(-1, 1, -1),
		Vector3.new(-1, 1, 1),
		Vector3.new(1, -1, -1),
		Vector3.new(1, -1, 1),
		Vector3.new(1, 1, -1),
		Vector3.new(1, 1, 1),
	}

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			for _, sign in signs do
				local corner = descendant.CFrame * (descendant.Size * 0.5 * sign)
				min = if min == nil then corner else min:Min(corner)
				max = if max == nil then corner else max:Max(corner)
			end
		end
	end

	if min == nil or max == nil then
		return Vector3.zero
	end

	return max - min
end

local function expectedBounds(category: string, canonicalName: string): Vector3?
	if manifestModule == nil then
		return nil
	end

	local entry = manifestModule.GetEntry(category, canonicalName)
	if entry == nil then
		return nil
	end

	return entry.ExpectedBounds
end

local function describeSize(category: string, canonicalName: string, actual: Vector3): string
	local expected = expectedBounds(category, canonicalName)
	local actualText = string.format("%.2f x %.2f x %.2f", actual.X, actual.Y, actual.Z)

	if expected == nil then
		return string.format("%s studs", actualText)
	end

	local expectedText = string.format("%.2f x %.2f x %.2f", expected.X, expected.Y, expected.Z)
	local ratio = if expected.Magnitude > 0.01 then actual.Magnitude / expected.Magnitude else 1
	local note = if ratio > 2.5 or ratio < 0.4 then "  <-- OFF-SCALE, fix in Blender" else ""

	return string.format("%s studs (expected %s)%s", actualText, expectedText, note)
end

-- Run ------------------------------------------------------------------------

local assetsFolder = ensureFolder(ReplicatedStorage, ASSETS_FOLDER_NAME)
local categoryFolders: { [string]: Folder } = {}
for _, category in CATEGORIES do
	categoryFolders[category] = ensureFolder(assetsFolder, category)
end

print("\n=======================================================")
print("[Workshop Zero] Organising imported visual assets...")
print("=======================================================\n")

local integrated = 0

for _, target in ASSET_TARGETS do
	local destination = categoryFolders[target.Category]
	local existing = destination:FindFirstChild(target.CanonicalName)

	-- Prefer a freshly imported copy; fall back to an asset that is already
	-- filed, so re-running this script is harmless.
	local found = findImported(Workspace, target.Patterns)
	if found == nil then
		found = findImported(ReplicatedStorage, target.Patterns)
	end
	if found == nil then
		found = existing
	end

	local model = if found ~= nil then ensureModel(found) else nil

	if model == nil then
		print(
			string.format(
				"  [MISSING] %-18s import %s to use custom art (primitive stays)",
				target.CanonicalName,
				target.SourceFile
			)
		)
		continue
	end

	normalizePhysics(model)

	if model.PrimaryPart == nil then
		local largest = findLargestPart(model)
		if largest ~= nil then
			model.PrimaryPart = largest
		end
	end

	if existing ~= nil and existing ~= model then
		print(
			string.format(
				"  [REPLACED] old %s removed from %s",
				target.CanonicalName,
				target.Category
			)
		)
		existing:Destroy()
	end

	model.Name = target.CanonicalName
	model.Parent = destination

	local size = measure(model)
	print(
		string.format(
			"  [OK] %-18s -> %s.%s  %s",
			target.CanonicalName,
			target.Category,
			target.CanonicalName,
			describeSize(target.Category, target.CanonicalName, size)
		)
	)

	integrated += 1
end

print(
	string.format(
		"\n%d / %d assets filed under ReplicatedStorage.%s\n",
		integrated,
		#ASSET_TARGETS,
		ASSETS_FOLDER_NAME
	)
)

print("Next:")
print("  1. Delete the leftovers in Workspace (the importer leaves its output there).")
print("  2. Save the place. These models are Studio-owned; Rojo never writes here.")
print("  3. Press Play. Studio Output reports the whole bridge, for example:")
print("       [WZ Assets]")
print("       Components")
print("         Block              custom")
print("         Plank              custom")
print("       ...")
print("       9/17 visuals are custom art, 8 fall back to primitives")
print("  Primitive fallbacks are expected wherever art does not exist yet")
print("  (Spring, Fan, Hook, Winch, Crate, ConnectorBoard).\n")
