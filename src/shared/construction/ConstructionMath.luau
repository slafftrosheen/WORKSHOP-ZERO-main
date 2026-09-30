--!strict

--[[
	ConstructionMath

	Pure mathematical and deterministic validation functions for Workshop Zero.
	Free of Roblox engine dependencies so calculations can be tested statically
	and evaluated identically on server and client.
]]

local ConstructionMath = {}

--[[
	Derives the cooperative motor rotation sign for an axle.
	D = Axle X Up derives the forward travel vector for the wheel.
	If multiple motors are present (e.g. left vs right on a chassis), this aligns
	their rotation to agree with the reference drive direction.
]]
function ConstructionMath.ComputeMotorSign(
	axleVector: Vector3,
	upVector: Vector3,
	refDirection: Vector3?
): (number, Vector3)
	local driveDirection = axleVector:Cross(upVector)

	if refDirection == nil or refDirection.Magnitude < 0.01 then
		return 1, driveDirection
	end

	if driveDirection:Dot(refDirection) < 0 then
		return -1, driveDirection
	end

	return 1, driveDirection
end

--[[
	Calculates directional aerodynamic thrust for a fan based on target distance
	and angle from the fan's forward blowing vector.
]]
function ConstructionMath.ComputeFanForce(
	distance: number,
	maxRange: number,
	dot: number,
	minDot: number,
	baseForce: number
): number
	if distance <= 0.5 or distance > maxRange or dot < minDot then
		return 0
	end

	local falloff = math.clamp(1 - (distance / maxRange), 0, 1)
	local angleFactor = math.clamp((dot - minDot) / (1 - minDot), 0, 1)

	return baseForce * falloff * (0.35 + 0.65 * angleFactor)
end

--[[
	Validates whether an experiment can be selected given the player's session unlocks.
]]
function ConstructionMath.IsExperimentUnlocked(
	experimentNumber: number,
	unlockedIndex: number
): boolean
	return experimentNumber <= unlockedIndex
end

return table.freeze(ConstructionMath)
