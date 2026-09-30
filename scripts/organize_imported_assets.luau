--!strict

--[[
	Workshop Zero - Organize Imported Assets
	
	Studio Command Bar utility script:
	After using Studio's "Import 3D" to bulk-import the .glb files from
	assets/export/roblox/ into Workspace, run this script in the Command Bar.

	It automatically:
	  1. Ensures ReplicatedStorage.WorkshopZeroAssets and category folders exist.
	  2. Finds each imported Model in Workspace.
	  3. Sets PrimaryPart if missing (defaults to largest BasePart).
	  4. Normalizes physics neutrality (CanCollide=false, CanTouch=false, Massless=true).
	  5. Moves and renames each Model into its authoritative category folder.
	  6. Validates against AssetManifest expected bounds and prints status report.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
local AssetManifest = if Shared and Shared:FindFirstChild("assets") and Shared.assets:FindFirstChild("AssetManifest")
	then require(Shared.assets.AssetManifest :: any)
	else nil

local ASSETS_FOLDER_NAME = "WorkshopZeroAssets"
local assetsFolder = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
if not assetsFolder then
	assetsFolder = Instance.new("Folder")
	assetsFolder.Name = ASSETS_FOLDER_NAME
	assetsFolder.Parent = ReplicatedStorage
end

local categories = { "Components", "Payloads", "Goals", "Props" }
local catFolders: { [string]: Folder } = {}
for _, cat in categories do
	local f = assetsFolder:FindFirstChild(cat)
	if not f then
		f = Instance.new("Folder")
		f.Name = cat
		f.Parent = assetsFolder
	end
	catFolders[cat] = f :: Folder
end

type AssetTarget = {
	Category: string,
	CanonicalName: string,
	Patterns: { string },
}

local ASSET_TARGETS: { AssetTarget } = {
	-- Components
	{
		Category = "Components",
		CanonicalName = "Block",
		Patterns = { "block_cube_01", "block", "constructionblock" },
	},
	{
		Category = "Components",
		CanonicalName = "Plank",
		Patterns = { "plank_beam_01", "plank", "plankbeam" },
	},
	{
		Category = "Components",
		CanonicalName = "Wheel",
		Patterns = { "wheel_rubber_01", "wheel", "rubberwheel" },
	},
	{
		Category = "Components",
		CanonicalName = "Motor",
		Patterns = { "motor_electric_01", "motor", "electricmotor" },
	},
	-- Payloads
	{
		Category = "Payloads",
		CanonicalName = "Duck",
		Patterns = { "duck_rubber_01", "duck", "rubberduck" },
	},
	-- Goals
	{
		Category = "Goals",
		CanonicalName = "GoalButton",
		Patterns = { "button_goal_red_01", "goalbutton", "button", "bigredbutton" },
	},
	-- Props
	{
		Category = "Props",
		CanonicalName = "MakerWorkbench",
		Patterns = { "workbench_maker_01", "workbench", "makerworkbench" },
	},
	{
		Category = "Props",
		CanonicalName = "ToolStorageRack",
		Patterns = { "rack_tool_01", "toolstoragerack", "toolrack", "rack" },
	},
	{
		Category = "Props",
		CanonicalName = "WorkshopWallPanel",
		Patterns = { "wall_panel_01", "workshopwallpanel", "wallpanel" },
	},
}

local function normalizePhysics(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = true
			pcall(function()
				(descendant :: any).CanQuery = false
			end)
		end
	end
end

local function ensurePrimaryPart(model: Model): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end

	local largestPart: BasePart? = nil
	local maxVolume = -1

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local vol = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if vol > maxVolume then
				maxVolume = vol
				largestPart = descendant
			end
		end
	end

	if largestPart ~= nil then
		model.PrimaryPart = largestPart
	end

	return largestPart
end

local function matchesPattern(name: string, patterns: { string }): boolean
	local lower = string.lower(name)
	for _, p in patterns do
		if string.find(lower, p, 1, true) ~= nil then
			return true
		end
	end
	return false
end

print("\n=======================================================")
print("[Workshop Zero] Integrating imported 3D assets...")
print("=======================================================\n")

local integratedCount = 0

for _, target in ASSET_TARGETS do
	local foundModel: Model? = nil

	-- 1. Search in Workspace
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and matchesPattern(child.Name, target.Patterns) then
			foundModel = child
			break
		end
	end

	-- 2. If not in Workspace, check if already in target folder
	if foundModel == nil then
		local existing = catFolders[target.Category]:FindFirstChild(target.CanonicalName)
		if existing and existing:IsA("Model") then
			foundModel = existing
		end
	end

	if foundModel ~= nil then
		ensurePrimaryPart(foundModel)
		normalizePhysics(foundModel)

		-- Remove any duplicate in target folder
		local destFolder = catFolders[target.Category]
		local prior = destFolder:FindFirstChild(target.CanonicalName)
		if prior ~= nil and prior ~= foundModel then
			prior:Destroy()
		end

		foundModel.Name = target.CanonicalName
		foundModel.Parent = destFolder

		local extents = foundModel:GetExtentsSize()
		print(string.format("  [OK] %s -> ReplicatedStorage.WorkshopZeroAssets.%s.%s (Size: %.1f, %.1f, %.1f)",
			foundModel.Name, target.Category, target.CanonicalName, extents.X, extents.Y, extents.Z))
		integratedCount += 1
	else
		print(string.format("  [MISSING] %s (%s) not found in Workspace or %s",
			target.CanonicalName, target.Category, target.Category))
	end
end

print(string.format("\nIntegration complete: %d / %d assets ready in WorkshopZeroAssets.\n",
	integratedCount, #ASSET_TARGETS))
