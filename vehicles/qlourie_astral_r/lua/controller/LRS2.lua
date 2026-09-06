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
local dampingGroups = {}
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
			baseDamping.LSBump * DSVMulti,
			baseDamping.LSRebound* LRSMulti,
			baseDamping.HSBump* DSVMulti,
			baseDamping.HSRebound* LRSMulti,
			baseDamping.velocityBump,
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
			--print(loadSmooth)
			if loadSmooth >= damper.LRS.LRSp and damper.blocker ~=1 then
				LRSMulti = LRSMulti * damper.LRS.LRSf
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
	end
end

local function reset()
end

local function init(jbeamData)
	dampers = {}
	dampersLookup = {}
	dampingGroups = {}

	local beamNameLookup = {}
	for _, b in pairs(v.data.beams) do
		if b.name then
			beamNameLookup[b.name] = b.cid
		end
	end

	--construct dampers table
	local dampersTable = tableFromHeaderTable(jbeamData.dampers or {})
	for _, damperData in pairs(dampersTable) do
		local cid = beamNameLookup[damperData.beamName]
		if cid then
			local damper = {
				name = damperData.name,
				damperCid = cid,
			}
			table.insert(dampers, damper)
			dampersLookup[damper.name] = damper
		else
			log("E", "LRS", "Invalid damper beam: "..tostring(damperData.beamName))
		end
	end

	--inject loads table
	local loadsTable = tableFromHeaderTable(jbeamData.loads or {})
	for _, loadData in pairs(loadsTable) do
		local damper = dampersLookup[loadData.name]
		if damper then
			if loadData.LRSName then --LRS
				local LRScid = beamNameLookup[loadData.LRSName]
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
				local DSVcid = beamNameLookup[loadData.DSVName]
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

	--construct damping table
	local dampingTable = tableFromHeaderTable(jbeamData.damping or {})
	for _, dampingData in pairs(dampingTable) do
		local name = dampingData.name
		dampingGroups[name]= {
			LSBump = dampingData.beamDamp,
			HSBump = dampingData.beamDampFast,
			LSRebound = dampingData.beamDampRebound,
			HSRebound = dampingData.beamDampReboundFast,
			velocityBump = dampingData.beamDampVelocitySplit,
			velocityRebound = dampingData.beamDampVelocitySplitRebound,
		}
	end

	--inject damping table
	for _, damper in ipairs(dampers) do
		local damping = dampingGroups[damper.name]
		if damping then
			damper.damping = damping
		else
			log("W", "LRS", "No damping data for damper: " .. tostring(damper.name))
		end
	end

	--Fvck LUA
	if dampers[1] == dampersLookup["FR"] then
		--print("YEEEEEEEEEEEEEEESSSSSSSSSSSSSSSS")
	end

	--dump(dampersLookup)
	printTable(dampers)
	--printTable(dampingGroups)
end

M.init = init
M.reset = reset
M.update = update
M.applyLRS = applyLRS

return M