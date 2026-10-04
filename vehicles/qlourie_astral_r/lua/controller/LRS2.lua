		-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.type = "auxilliary"

local abs = math.abs
local min = math.min
local max = math.max

--front
local dampers = {}
local dampersLookup = {}
local debugWheel
local debugTime = 0
local debugState
local debugDuration = 0
local loadSmoother = newTemporalSmoothing(1000, 1000)
local loadSmoother2 = newTemporalSmoothing(1000, 1000)

function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

function printTable(t, indent)
	indent = indent or ""
	for k, v in pairs(t) do
		if type(v) == "table" then
			print(indent .. "[" .. k .. "] => Table:")
			printTable(v, indent .. "	")
		else
			print(indent .. "[" .. k .. "] => " .. tostring(v))
		end
	end
end

function applyLRS(damper, LRSMulti, DSVMulti)
	local baseDamping = damper.damping
	if not baseDamping then
		log("W", "applyLRS", "No damping data for damper " .. tostring(damper.name))
		return
	end
	if damper.damperCid then
		obj:setBoundedBeamDamp(
			damper.damperCid,
			baseDamping.bump1 * DSVMulti,
			baseDamping.LSRebound* LRSMulti,
			baseDamping.bump2* DSVMulti,
			baseDamping.HSRebound* LRSMulti,
			baseDamping.velocity1,
			baseDamping.velocityRebound
		)
	end
end

local function update(dt)
	for _, damper in ipairs(dampers) do
		local LRSMulti = 1
		local DSVMulti = 1
		if damper.LRS then --LRS
			local loadLength = obj:getBeamLength(damper.LRS.LRSCid)
			local loadSmooth = loadSmoother:get(loadLength, dt)
			damper.LRS.active = false
			--print(loadSmooth)
			if loadSmooth >= damper.LRS.LRSp and damper.blocker ~=1 then
				LRSMulti = LRSMulti * damper.LRS.LRSf
				damper.LRS.active = true
				--print(LRSMulti)
			else
				--print(LRSMulti)
			end
		end

		if damper.DSV then --DSV
			local loadLen = obj:getBeamLength(damper.DSV.DSVCid)
			local loadLenSmooth = loadSmoother:get(loadLen, dt)
			local loadVel = obj:getBeamVelocity(damper.DSV.DSVCid)
			local loadVelSmooth = loadSmoother2:get(loadVel, dt)
			--print(loadLenSmooth)
			--print(loadVelSmooth)
			if loadVelSmooth <= -0.462 and loadLenSmooth <= damper.DSV.DSVp then
				DSVMulti = 1 + (0.167 * damper.DSV.DSVf)
				--print(DSVMulti)
			elseif loadVelSmooth >= 0.227 and loadLenSmooth >= damper.DSV.DSVp2 then
				DSVMulti = 1 - (0.133 * damper.DSV.DSVf)
				--print(DSVMulti)
			else
				DSVMulti = 1
				--print("DSVNOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO")
			end
		end

		applyLRS(damper, LRSMulti, DSVMulti)
		if damper.name == debugWheel then
			local active = damper.LRS and damper.LRS.active or false
			local transition = ""
			if active ~= debugState then
				if debugState ~= nil then
					transition = string.format(" | previous %s %.4fs", debugState and "OPEN" or "CLOSED", debugDuration)
				end
				debugState = active
				debugDuration = 0
			end
			debugTime = debugTime + dt
			debugDuration = debugDuration + dt
			print(string.format("[LRS %s] t=%.4fs %s %.4fs%s", debugWheel, debugTime, active and "OPEN" or "CLOSED", debugDuration, transition))
		end
	end
end

local function reset()
	debugTime = 0
	debugState = nil
	debugDuration = 0
end

local function init(jbeamData)
	debugWheel = nil
	reset()
	dampers = {}
	dampersLookup = {}

	local beamNameLookup = {}
	for _, b in pairs(v.data.beams) do
		if b.name then
			beamNameLookup[b.name] = b
		end
	end

	local dampersTable = tableFromHeaderTable(jbeamData.dampers or {})
	for _, damperData in pairs(dampersTable) do
		local beam = beamNameLookup[damperData.beamName]
		if beam then
			local hsBeam = beamNameLookup[damperData.beamName .. "_HS"]
			local damping = {
				bump1 = beam.beamDamp,
				bump2 = beam.beamDampFast,
				LSRebound = beam.beamDampRebound,
				HSRebound = beam.beamDampReboundFast,
				velocity1 = beam.beamDampVelocitySplit,
				velocityRebound = beam.beamDampVelocitySplitRebound,
			}
			damping.HSbump = damping.bump2 + (hsBeam and hsBeam.beamDampFast or 0)
			damping.velocity2 = hsBeam and hsBeam.beamDampVelocitySplit or nil
			local damper = {name = damperData.name, damperCid = beam.cid, damping = damping}
			table.insert(dampers, damper)
			dampersLookup[damper.name] = damper
		else
			log("E", "LRS", "Invalid damper beam: " .. tostring(damperData.beamName))
		end
	end

	--inject loads table
	local loadsTable = tableFromHeaderTable(jbeamData.loads or {})
	for _, loadData in pairs(loadsTable) do
		local damper = dampersLookup[loadData.name]
		if damper then
			if loadData.LRSName then --LRS
				local LRSbeam = beamNameLookup[loadData.LRSName]
				local LRScid = LRSbeam and LRSbeam.cid
				if LRScid then
					damper.LRS={
						LRSCid = LRScid,
						LRSp = loadData.LRSp or 0.12,
						LRSf = loadData.LRSf or 0.5,
					}
				else
					log("W", "LRS", "Invalid LRS beam: "..tostring(loadData.LRSName..", LRS not activated"))
				end
			end
			if loadData.DSVName then --DSV
				local DSVbeam = beamNameLookup[loadData.DSVName]
				local DSVcid = DSVbeam and DSVbeam.cid
				if DSVcid then
					damper.DSV={
						DSVCid = DSVcid,
						DSVp = loadData.DSVp or 0.11,
						DSVp2 = loadData.DSVp2 or loadData.DSVp + 0.01,
						DSVf = loadData.DSVf or 1,
					}
				else
					log("W", "LRS", "Invalid DSV beam: "..tostring(loadData.DSVName..", DSV not activated"))
				end
			end
			if loadData.blocker then
				damper.blocker = loadData.blocker
			end
		else
			log("E", "LRS", "No matching damper for load '"..tostring(loadData.name).."'")
		end
	end

end

local function setDebug(name)
	if name and not dampersLookup[name] then
		log("W", "LRS", "No damper named " .. tostring(name) .. " in this controller")
		return
	end
	debugWheel = name
	reset()
end

M.init = init
M.reset = reset
M.update = update
M.applyLRS = applyLRS
M.getDampers = printTable(dampers)
M.setDebug = setDebug

return M