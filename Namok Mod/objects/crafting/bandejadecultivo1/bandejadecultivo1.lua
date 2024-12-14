require "/scripts/util.lua"

timer = 0

seedslot = 0
waterslot = 1
fertslot = 2

inputSlots = {seedslot, waterslot, fertslot}



function init()
	defaults = {
		growthRate = config.getParameter("baseGrowthPerSecond", 4),  -- Multiplier on vanilla plant growth speed
		seedUse = config.getParameter("defaultSeedUse", 4),          -- Amount of seeds consumed per plant (for perennials, starting cost)
		yield = config.getParameter("baseYields", 4),                -- Multiplier on treasurepools generated
		fluidUse = config.getParameter("defaultWaterUse", 1)         -- Fluid units consumed per stage
	
	}
	multipliers = { growthRate=true } -- Which stats should be calculated as multipliers

	if not storage.fert then storage.fert = {} end
	if not storage.water then storage.water = {} end

	self.liquidInputs = config.getParameter("waterInputs")
	self.fertInputs = config.getParameter("fertInputs")	

	object.setInteractive(true)

	storage.growth = storage.growth or 0 				--Plant growth completed
	storage.fluid = storage.fluid or 0					--Stored fluid
	storage.currentStage = storage.currentStage or 1	--Current plant stage
	storage.hasFluid = storage.hasFluid or false		--If false soil is dry and no further growth.

	if storage.activeConsumption == nil then storage.activeConsumption = false end
	
end

--Updates the state of the object.
function update(dt)
	-- Updates container status (for ITD management)
	if not transferUtilDeltaTime or (transferUtilDeltaTime > 1) then
		transferUtilDeltaTime=0
		transferUtil.loadSelfContainer()
	else
		transferUtilDeltaTime=transferUtilDeltaTime+dt
	end

	-- Check tray inputs
	local water,fert=checkTrayInputs()
	storage.activeConsumption = false

	--Try to start growing if data indicates we aren't.
	if not storage.currentseed then
		if not doSeedIntake() then			
			handleTooltip({water=water,fert=fert})--update description
			return
		end
	end

	growPlant(dt)

	handleTooltip({water=water,fert=fert,seed=storage.currentseed})--update description

	storage.activeConsumption = true
	if object.outputNodeCount() > 0 then
		object.setOutputNodeLevel(0,true)
	end
	updateState()
end

--Tries to relocate an item in a specific slot while avoiding key slots.
--If all the item stack in a slot can't be moved remainder is put back and overflow is returned.
local function fu_relocateItem(slot, avoidSlots)
	local item = world.containerTakeAt(entity.id(), slot)
	-- Use store instead of send/store to avoid confusion of item possibly being consumed.
	local overflow = fu_storeItems(item, avoidSlots)
	if overflow then
		world.containerPutItemsAt(entity.id(), overflow, slot)
		return overflow
	end
	return
end

-- Checks tray water and fertilizer inputs for validity.
-- Pushes invalid items into storage (if there is room).
-- Updates description based on inputs.
-- Only does work if state of inputs has changed.
-- NOTE: Intentionally does not check seed input slot.
function checkTrayInputs()
	-- Gather information about the items in input slots
	local inputWater = world.containerItemAt(entity.id(), waterslot)
	local inputFert = world.containerItemAt(entity.id(), fertslot)

	-- Cache check, if key details are unchanged then there is no work to do.
	local bWater = not inputWater and not storage.cacheWater or
			inputWater and storage.cacheWater and inputWater.name == storage.cacheWaterName
	local bFert = not inputFert and not storage.cacheFert or
			inputFert and storage.cacheFert and inputFert.name == storage.cacheFertName
	if bWater and bFert then return end

	-- Fetch tray data for inputs.
	local water = inputWater and self.liquidInputs[inputWater.name] or nil
	local fert = inputFert and self.fertInputs[inputFert.name] or nil

	-- Relocate invalid inputs
	if inputWater and not water then inputWater = fu_relocateItem(waterslot, inputSlots) end
	if inputFert and not fert then inputFert = fu_relocateItem(fertslot, inputSlots) end

	-- Update cache
	storage.cacheWaterName = inputWater and inputWater.name or nil
	storage.cacheFertName = inputFert and inputFert.name or nil

	return water,fert
end


-- Generate new description
function handleTooltip(args)

	--growth rate 
	local growthrate=getFertSum('growthRate', args.fert, args.water)
	local growthrate2=growthrate
	growthrate=util.round(growthrate,2)
	growthrate2=util.round(growthrate2,2)
	local growthString
    growthString='Vel. crecimiento: ^green;' .. growthrate2 .. "^reset;\n"

	--seed use and seed display
	local seedString=""
	if args.seed and args.seed.name then
		seedString=root.itemConfig(args.seed.name).config.shortdescription
		seedString=" (^yellow;" .. seedString .. "^reset;)"
	end

	local seedUseWith=getFertSum('seedUse', args.fert, args.water)
	local seedUseWithout=getFertSum('seedUse', "absolutelynothing", "absolutelynothing")
	if seedUseWith<seedUseWithout then
		seedUseWith="^green;"..seedUseWith.."^reset;"
	elseif seedUseWith>seedUseWithout then
		seedUseWith="^red;"..seedUseWith.."^reset;"
	end
	seedString='Semillas en uso: ' .. seedUseWith .. seedString .. "\n"

	--seed min and max duration display
	if args.seed and args.seed.name then
		seedString=seedString.."Stage ^yellow;"..storage.currentStage..": ^reset; ^green;"..math.floor(storage.growth).."^reset; / ^green;"..storage.stage[storage.currentStage].val.."^reset;\n"
	end

	--yield calc
	local yieldWith=getFertSum('yield', args.fert, args.water)
	local yieldWithout=getFertSum('yield', "absolutelynothing", "absolutelynothing")
	if yieldWith>yieldWithout then
		yieldWith="^green;"..yieldWith.."^reset;"
	elseif yieldWith<yieldWithout then
		yieldWith="^red;"..yieldWith.."^reset;"
	end
	local yieldString='Yield Count: ' .. yieldWith .. "\n"

	--water use calc
	local waterUseWith=getFertSum('fluidUse', args.fert, args.water)
	local waterUseWithout=getFertSum('fluidUse', "absolutelynothing", "absolutelynothing")
	if waterUseWith<waterUseWithout then
		waterUseWith="^green;"..waterUseWith.."^reset;"
	elseif waterUseWith>waterUseWithout then
		waterUseWith="^red;"..waterUseWith.."^reset;"
	end
	local waterUseString='Fluido usado: ' .. waterUseWith .. "\n"

	--water value calc
	local waterValueString='Water Value: '
	local waterValue=(args.water and args.water.value or 0)
	if waterValue>0 then
		waterValueString=waterValueString.."^green;"..waterValue.."^reset;"
	else
		waterValueString=waterValueString..waterValue
	end

	--set desc!
	local desc = seedString..yieldString..growthString..waterUseString..waterValueString
	object.setConfigParameter('description', desc)
end

--Returns active seed when tray is removed from world
function die()
	if storage.currentseed then
		--storage.currentseed.count = getFertSum("seedUse")
		world.spawnItem(storage.currentseed, entity.position())
	end
end

-- Upates growth animation
function updateState()
	--Compute which graphic should be displayed and update.
	local growthperc = (storage.growthcap ~= 0) and (100*math.min(storage.growth, storage.growthCap)/storage.growthCap) or 0
	animator.setAnimationState("growth", sb.print(math.min(math.floor(growthperc / 25), 3)))
end

-- Performs a plant growth tick, including water consumption and harvesting
function growPlant(dt)
	-- Little cheat ;-) (always gets current stage)
	local stage = function() return storage.stage[storage.currentStage] end

	-- Fluid check
	storage.hasFluid = doFluidConsume()
	if not storage.hasFluid then return end

	-- Add growth
	storage.growth = storage.growth + getFertSum("growthRate") * dt

	-- If current stage is complete, consume fluid units and increment stage
	if storage.growth >= stage().val then
		storage.fluid = storage.fluid - getFertSum("fluidUse")
		storage.currentStage = storage.currentStage + 1
	end

	-- If the new stage is a harvesting stage, harvest and handle perennial
	if stage().harvestPool then
		local tblmerge = function(tb1, tb2) for _,v in pairs(tb2) do table.insert(tb1, v) end end
		local output = {}
		for _=1,getFertSum("yield") do
			tblmerge(output, root.createTreasure(stage().harvestPool, 1))
		end
		--sb.logInfo("%s",output)

		local seedavoid = {waterslot, fertslot} -- Map for allowing seeds to be output into the input slot
		for _,item in ipairs(output) do
			-- Preserve customized seeds on output
			if item.name == storage.currentseed.name then
				item.parameters = storage.currentseed.parameters
			end
			fu_sendOrStoreItems(0, item, item.name == storage.currentseed.name and seedavoid or inputSlots)
		end

		-- Perennial plants should return yeild of seeds for balance purposes.
		-- By returning yield seeds we handle part of perennials regrowing from the same seed.
		if stage().resetToStage then
			--storage.currentseed.count = getFertSum("yield")--doesnt care how many are consumed, just flatout sets it to the yield. this results in massive seed production. double soup has yield 4, -1 seed, which results in net 2 seeds per interval. removing this 'feature'
			fu_sendOrStoreItems(0, storage.currentseed, seedAvoid)
			storage.perennialSeedName = storage.currentseed.name
		end

		-- Done growing reset for next cycle.
		storage.currentseed = nil
	end
end

-- Gets the current effective value of a fertilizer-affected modifier.
function getFertSum(name, fert, water)
	fert = fert or storage.fert
	water = water or storage.water
	if multipliers[name] then
		local rate = (fert[name] or 1) * (water[name] or 1)
		return defaults[name] * (rate <= 0 and 1 or rate)
	end
	local bonus = (fert[name] or 0) + (water[name] or 0)
	return math.max(defaults[name] + bonus, 0)
end

--Updates internal fluid levels, consumes required fluid units, and updates any fluid bonuses.
--optional arg fluidNeed is amount of fluid required to top up to.
function doWaterIntake(fluidNeed)
	local water = world.containerItemAt(entity.id(), waterslot)

	if water and self.liquidInputs[water.name] then
		storage.water = self.liquidInputs[water.name]
		local amt = math.min(water.count, math.ceil(fluidNeed / storage.water.value))
		storage.fluid = storage.fluid + (amt * storage.water.value)
		world.containerConsumeAt(entity.id(),waterslot,amt)
		return true
	end
	storage.water = {}
	return false
end

--Attempts to use up some fluid
function doFluidConsume()
	local useFluid = getFertSum("fluidUse")
	if storage.fluid < useFluid then
		if not doWaterIntake(useFluid - storage.fluid) then return false end
	end
	return true
end

--Fetch the seed from the storage slot, also does validity check.
function readContainerSeed()
	local seed = world.containerItemAt(entity.id(), seedslot)
	if not seed then return end
	--Verify the seed is valid for use.
	local seedConfig = root.itemConfig(seed).config
	if seedConfig.objectType ~= "farmable" then return nil end
	return seed
end

--Reads the currentseed's data.  Return false if there was a problem with the
--seed/data.
function readSeedData()
	if not storage.currentseed then return false end
	if storage.currentseed.name == "sapling" then return false end
	local stages = (storage.currentseed.parameters and storage.currentseed.parameters.stages) or root.itemConfig(storage.currentseed).config.stages
	storage.stages = #stages
	storage.stage = stages
	return true
end

--[[
Notes on how Starbound handles perennials and reason for some odd code below.
First, Starbound, in C, is 0 based arrays while Lua is 1 based arrays. (resetToStage + 1)
Second, Starbound appears to do bounds checking on the resetToStage property. (min & max calls)
Third, Starbound gracefully handles if a seed changes data, mods (resetToStage check in if condition)
]]--
--Generates growth data to tell when a plant is ready for harvest and when it
--needs to be watered.
--Also handles some of perennial growth mechanics.
function genGrowthData()
	storage.growthCap = 0
	for _,stage in ipairs(storage.stage) do
		storage.growthCap = storage.growthCap + (stage.duration and stage.duration[1] or 0)
		stage.val = storage.growthCap
	end

	-- Set currentStage and possibly growth depending on perennial seed data
	if storage.perennialSeedName and storage.stage[storage.stages].resetToStage and
		storage.currentseed.name == storage.perennialSeedName then
		storage.currentStage = math.min(storage.stages, math.max(1, storage.stage[storage.stages].resetToStage + 1))
		storage.growth = storage.currentStage == 1 and 0 or	storage.stage[storage.currentStage - 1].val
	else
		storage.currentStage = 1
	end
	--Clear the old perennial data.
	storage.perennialSeedName = nil
end

--Initialize plant activity
function doSeedIntake()
	storage.growth = 0
	animator.setAnimationState("growth", "0")
	storage.currentseed = nil

	--Read/init seed data
	local seed = readContainerSeed()
	if not seed then return false end
	storage.currentseed = seed
	if not readSeedData() then
		storage.currentseed = nil
		return false
	end

	--set defaults that fertilizer can change or modify
	resetBonuses()

	--Since we might need to consume multiple seeds we delay fertilizer USE
	--until we know we have enough resources to proceed.
	--Otherwise we could end up consuming all the fertilizer without growing anything.
	local fertName = doFertProcess()

	--verify we have enough seeds to proceed.
	if storage.currentseed.count < getFertSum("seedUse") then
		storage.currentseed = nil
		storage.fert = {}
		return false
	end

	--Generate growth data.
	genGrowthData()

	--All state tests passed and we are ready to grow, consume some items.

	--Consume a unit of fertilizer.
	if fertName then
		world.containerConsumeAt(entity.id(),fertslot,1)
	end

	--Consume seed.
	local consumed=getFertSum("seedUse")
	world.containerConsumeAt(entity.id(),seedslot,consumed)
	storage.currentseed.count=consumed

	return true
end

--Reads the current fertilizer slot and modifies growing state data
--Returns false if nothing to do, true if successful
function doFertProcess()
	local fert = world.containerItemAt(entity.id(), fertslot)

	if fert and self.fertInputs[fert.name] and fert.count > 0 then
		storage.fert = self.fertInputs[fert.name]
		return fert.name
	end
	storage.fert = {}
	return nil
end

function resetBonuses()
	storage.fert = {}
	storage.water = {}
end


------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------ FU functions ----------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------

-- *********************************************** fu_storageutils.lua ***********************************************

function fu_storeItems(items, avoidSlots, spawnLeftovers)
	local function fu_getOutputSlotsFor(something)
		-- TODO: use world.containerItemsFitWhere? Seems not too useful
		local empty = {} -- empty slots in the outputs
		local slots = {} -- slots with a stack of "something"

		for i = 0, world.containerSize(entity.id()) do -- iterate all output slots
			local stack = world.containerItemAt(entity.id(), i) -- get the stack on i
			if stack then -- not empty
				if stack.name == something then -- its "something"
					table.insert(slots,i) -- possible drop slot
				end
			else -- empty
				table.insert(empty, i)
			end
		end

		for _, e in ipairs(empty) do -- add empty slots to the end
			table.insert(slots,e)
		end
		return slots
	end

	local function contains(list, item)
		for _, i in ipairs(list) do
			if i == item then return true end
		end
		return false
	end


	if avoidSlots then
		local slots = fu_getOutputSlotsFor(items.name)
		for _, i in ipairs(slots) do
			if not contains(avoidSlots, i) then
				items = world.containerPutItemsAt(entity.id(), items, i)
				if items == nil then
					break
				end
			end
		end
	else
		items = world.containerAddItems(entity.id(), items)
	end

	if spawnLeftovers and items and items.count > 0 then
		world.spawnItem(items.name, entity.position(), items.count)
		return nil
	end
	return items
end

-- Interoperability with Peasly Wellbott's Item Broadcaster
-- We don't do affinities, hyperstorage or animation; we always try to store the item
local function fu_itemBroadcast_sendItems(node, itemDescriptor)
	storage.fu_storage_knownPeers = {}

	-- get info on chests in range of connected receivers
	for i in ipairs( object.getOutputNodeIds(node) or {} ) do
		world.callScriptedEntity(i, "returnBeaconHandshake")
	end

	-- try to store items in them

	-- sb.logInfo ('sending %s to objects %s', itemDescriptor, storage.fu_storage_knownPeers)
	for _, chest in ipairs(storage.fu_storage_knownPeers) do
		itemDescriptor = world.containerAddItems(chest, itemDescriptor)
		-- sb.logInfo("result: %s", itemDescriptor)
		if not itemDescriptor or itemDescriptor.count == 0 then break end
	end

	-- done; return what remains
	return itemDescriptor
end

-- Required for receiving responses from Item Broadcaster's item receivers
function acknowledgeBeaconPeers(ids)
	-- record storage objects except for self
	for _, j in ipairs(ids) do
		if j[1] ~= entity.id() then table.insert(storage.fu_storage_knownPeers, j[1]) end
	end
end

function fu_sendItems(node, itemDescriptor)
	-- if connected to an object receiver, try to send the item(s)

	-- Wired Industry's item router is one such device
	-- There is an ambiguity if the receiver returns nil (indicating all items stored)
	-- This is also what is returned if the receive function can not be called...
	local unfail = { name = itemDescriptor.name, count = 0, data = itemDescriptor.data }

	local connectedIds = object.getOutputNodeIds(0)
	for i in ipairs(connectedIds) do
		-- Wired Industry interop
		if world.getObjectParameter(i, "acceptsItems") then
			-- sb.logInfo ('sending %s to object %s', itemDescriptor, i)
			itemDescriptor = world.callScriptedEntity(i, "receiveItem", itemDescriptor)
			-- sb.logInfo ('result: %s', itemDescriptor)
			if not itemDescriptor or itemDescriptor.count == 0 then break end
		end

		-- Item Broadcaster interop
		itemDescriptor = fu_itemBroadcast_sendItems(node, itemDescriptor)
		if not itemDescriptor or itemDescriptor.count == 0 then break end
	end

	return itemDescriptor or unfail -- deal with that ambiguity, hopefully
end

function fu_sendOrStoreItems(node, itemDescriptor, avoidSlots, spawnLeftovers)
	local remain = fu_sendItems(node, itemDescriptor)
	if remain.count then
		-- some unsent; store locally
		remain = fu_storeItems(remain, avoidSlots, spawnLeftovers)
	end
	return remain
end


-- *********************************************** kheAA/transferUtil.lua ***********************************************


transferUtil={}
disabled=false
unhandled={}
transferUtil.itemTypes = nil

function transferUtil.init()
	if storage==nil then
		storage={}
	end
	
	self.disabled=(entity.entityType() ~= "object") or nil
	if self.disabled then
		sb.logInfo("transferUtil automation functions are disabled on non-objects (current is \"%s\") for safety reasons.",entity.entityType())
		return
	end
	storage.position=storage.position or entity.position()
	transferUtil.vars={}
	transferUtil.vars.logicNode=config.getParameter("kheAA_logicNode")
	transferUtil.vars.inDataNode=config.getParameter("kheAA_inDataNode")
	transferUtil.vars.outDataNode=config.getParameter("kheAA_outDataNode")
	transferUtil.vars.defaultMaxStack = root.assetJson("/items/defaultParameters.config").defaultMaxStack
	transferUtil.vars.itemDataCache = {}
	transferUtil.vars.didInit=true
end

function transferUtil.initTypes()
	transferUtil.itemTypes = root.assetJson("/scripts/kheAA/transferconfig.config").categories
end

function transferUtil.containerAwake(targetContainer,targetPos)
	if type(targetPos) ~= "table" then
		return nil,nil
	elseif util.tableSize(targetPos) > 2 then
		targetPos={targetPos[1],targetPos[2]}
	elseif util.tableSize(targetPos)<2 then
		return nil,nil
	end
	local awake=transferUtil.zoneAwake(transferUtil.pos2Rect(targetPos,0.1))
	if awake==nil then
		return nil,nil
	elseif awake then
		ping=world.objectAt(targetPos)
		if ping ~= nil then
			if ping ~= targetContainer then
				if world.containerSize(ping) ~= nil then
					return true, ping
				else
					return false,nil
				end
			else
				return true,nil
			end
		else
			return false,nil
		end
	end
	return nil,nil
end

function transferUtil.zoneAwake(targetBox)
	if self.disabled then return end
	if not targetBox then return end
	if not transferUtil.vars or not transferUtil.vars.didInit then
		transferUtil.init()
	end
	if type(targetBox) ~= "table" then
		dbg({"zoneawake failure, invalid input:",targetBox})
		return nil
	else
		if util.tableSize(targetBox) ~= 4 then
			dbg({"zoneawake failure, invalid input:",targetBox})
			return nil
		end
	end
	if not world.regionActive(targetBox) then
		world.loadRegion(targetBox)
	else
		return true
	end
	if world.regionActive(targetBox) then
		return true
	else
		return false
	end
end

function transferUtil.throwItemsAt(target,targetPos,item,drop)
	if item.count~=math.floor(item.count) or item.count<=0 then return false end
	local stackCap=handleCache(item).maxStack
	if item.count>stackCap then
		item.count=stackCap
	end
	drop=drop or false

	if target==nil and targetPos==nil then
		if drop then
			world.spawnItem(item,entity.position())
			return true,item.count,true
		else
			return false
		end
	end

	local awake,ping=transferUtil.containerAwake(target,targetPos)
	if awake then
		if ping ~= nil then		
			target=ping
		end
	elseif drop then
		world.spawnItem(item,entity.position())
		return true,item.count,true
	else
		return false
	end

	if world.containerSize(target) == nil or world.containerSize(target) == 0 then
		if drop then
		    world.spawnItem(item,targetPos)
			return true,item.count,true
		else
			return false
		end
	end
	
	local leftOverItems = world.containerAddItems(target, item)
	if leftOverItems ~= nil then
		if drop then
			world.spawnItem(leftOverItems,targetPos)
			return true, item.count, true
		else
			return true,item.count-leftOverItems.count
		end
	end

	return true, item.count
end

function transferUtil.updateNodeLists()
	local uInP=transferUtil.updateInputs()
	local uOutP=transferUtil.updateOutputs()
	return uInP and uOutP
end

function transferUtil.updateInputs()
	if not transferUtil.vars or not transferUtil.vars.didInit then
		transferUtil.init()
	end

	transferUtil.vars.input={}

	transferUtil.vars.inContainers={}

	if self.disabled then return end
	if not transferUtil.vars.inDataNode then
		return false
	end

	transferUtil.vars.inputList=copy(object.getInputNodeIds(transferUtil.vars.inDataNode))
	local buffer={}
	for inputSource in pairs(transferUtil.vars.inputList) do
		local source=inputSource
		if source then
			local temp=world.callScriptedEntity(source,"transferUtil.sendContainerInputs")
			if temp ~= nil then
				for entId,position in pairs(temp) do
					buffer[entId]=position
				end
			end
		end
	end
	transferUtil.vars.inContainers=buffer
	return true
end

function transferUtil.updateOutputs()
	if not transferUtil.vars or not transferUtil.vars.didInit then
		transferUtil.init()
	end

	transferUtil.vars.output={}

	transferUtil.vars.outContainers={}
	transferUtil.vars.upstreamCount=0

	if self.disabled then return end
	if not transferUtil.vars.outDataNode then
		return false
	end

	transferUtil.vars.outputList=copy(object.getOutputNodeIds(transferUtil.vars.outDataNode))
	local buffer={}
	for outputSource in pairs(transferUtil.vars.outputList) do
		local source=outputSource
		if source then
			-- this is for loop prevention, if a repeater forms a loop with another repeater, both clear their object lists and refuse to hold any data. prevents fossilization.
			if transferUtil.vars.inputList[source] and world.callScriptedEntity(source,"transferUtil.isRelayNode") then
				transferUtil.vars.inputList={}
				transferUtil.vars.outputList={}
				transferUtil.vars.outContainers={}
				transferUtil.vars.inContainers={}
				transferUtil.vars.upstreamCount=0
				return false
			end

			if world.callScriptedEntity(source,"transferUtil.checkUpstreamContainers") then
				transferUtil.vars.upstreamCount=transferUtil.vars.upstreamCount+1
			end

			local temp=world.callScriptedEntity(source,"transferUtil.sendContainerOutputs")
			if temp ~= nil then
				for entId,position in pairs(temp) do
					buffer[entId]=position
					transferUtil.vars.upstreamCount=transferUtil.vars.upstreamCount+1
				end
			end
		end
	end
	transferUtil.vars.outContainers=buffer
	return true
end

function transferUtil.findNearest(source,sourcePos,targetList)
	if not source or not targetList then
		return nil
	elseif util.tableSize(targetList) == 0 then
		return nil
	end
	local target = nil
	local distance = math.huge
	local targetPos = nil
	for i2,position in pairs(targetList) do
		if i2 ~= source then
			local dist = world.magnitude(position,sourcePos)
			if distance > dist then
				target=i2
				targetPos=position
				distance=dist
			end
		end
	end
	return target,targetPos
end

function transferUtil.checkUpstreamContainers()
	return ((transferUtil.vars and transferUtil.vars.upstreamCount) or 0)>0
end

function transferUtil.hasUpstreamContainers()
	return util.tableSize(transferUtil.vars.outContainers)>0
end

function transferUtil.pos2Rect(pos,size)
	if not size then size = 0 end
	return({pos[1]-size,pos[2]-size,pos[1]+size,pos[2]+size})
end

function transferUtil.tFirstIndex(entry,t1)
	for k,v in pairs(t1) do
		if entry==v then
			return k
		end
	end
	return 0
end

function transferUtil.compareItems(itemA, itemB)
	if not itemA or not itemB then
		return false;
	elseif itemA.name == itemB.name then
		return true;
	end
	return false

end

function transferUtil.compareTypes(itemA, itemB)
	if not itemA or not itemB then
		return false;
	end
	if transferUtil.getType(itemA) == transferUtil.getType(itemB) then
		return true;
	end
	return false
end
function transferUtil.compareCategories(itemA, itemB)
	if not itemA or not itemB then
		return false;
	end
	if transferUtil.getCategory(itemA) == transferUtil.getCategory(itemB) then
		return true;
	end
	return false
end

function transferUtil.sendConfig()
	return storage;
end

function transferUtil.recvConfig(conf)
	storage=conf
end

function transferUtil.sendContainerInputs()
	return transferUtil and transferUtil.vars and (not transferUtil.isRouterNode()) and transferUtil.vars.inContainers or {}
end

function transferUtil.sendContainerOutputs()
	return transferUtil and transferUtil.vars and (not transferUtil.isRouterNode()) and transferUtil.vars.outContainers or {}
end

function transferUtil.powerLevel(node,explicit)
	if not node then
		return not explicit
	end
	if explicit==nil then
		explicit=false
	end
	if(object.inputNodeCount()<1)then
		return true
	end
	if object.isInputNodeConnected(node) then
		return object.getInputNodeLevel(node)
	else
		return not explicit
	end
end

function handleCache(item)
	if (not transferUtil.vars.itemDataCache[item.name])
	or (item.parameters.category and (item.parameters.category~=transferUtil.vars.itemDataCache[item.name].itemCat)) then

		local buffer=root.itemConfig(item)
		local buffer2={}
		if item.name == "sapling" then
			buffer2.itemCat=item.name
		elseif buffer.parameters.currency or buffer.config.currency or item.currency then
			buffer2.itemCat="currency"
		elseif buffer.parameters and buffer.parameters.category then
			buffer2.itemCat=buffer.parameters.category
		elseif buffer.config.category then
			buffer2.itemCat=buffer.config.category
		elseif buffer.config.category then
			buffer2.itemCat=buffer.config.category
		elseif buffer.category then
			buffer2.itemCat=buffer.category
		elseif buffer.config.projectileType then
			buffer2.itemCat="throwableitem"		
		end
		buffer2.maxStack=buffer.parameters.maxStack or buffer.config.maxStack or transferUtil.vars.defaultMaxStack
		transferUtil.vars.itemDataCache[item.name]=buffer2
	end
	return transferUtil.vars.itemDataCache[item.name]
end

function transferUtil.getType(item)
	if not item.name then
		return "unhandled"
	end
	local itemCache=handleCache(item)
	if itemCache and itemCache.itemCat then
		return string.lower(itemCache.itemCat)
	elseif not unhandled[item.name] then	
		unhandled[item.name]=true
	end
	return "unhandled"
end

function transferUtil.leftToList(input)
	local buffer={}
	for k in pairs(input) do
		buffer[#buffer + 1]=k
	end
	return buffer
end

function transferUtil.getCategory(item)
	local itemCat=transferUtil.getType(item)
	return transferUtil.itemTypes[itemCat] or "unhandled"
end

function transferUtil.loadSelfContainer()
	if not transferUtil.vars or not transferUtil.vars.didInit then
		transferUtil.init()
	end
	transferUtil.vars.containerId=entity.id()
	transferUtil.unloadSelfContainer()
	transferUtil.vars.inContainers[transferUtil.vars.containerId]=storage.position
	transferUtil.vars.outContainers[transferUtil.vars.containerId]=storage.position
end

function transferUtil.unloadSelfContainer()
	if not transferUtil.vars or not transferUtil.vars.didInit then
		transferUtil.init()
	end
	transferUtil.vars.inContainers={}
	transferUtil.vars.outContainers={}
end

function transferUtil.isRelayNode()
	return transferUtil.vars.isRelayNode
end

function transferUtil.isRouterNode()
	return transferUtil.vars.isRouter
end

function dbg(args)
	sb.logInfo(sb.printJson(args))
end

