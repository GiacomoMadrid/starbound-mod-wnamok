require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"
require "/scripts/util.lua"

function init()
	if not world.entityType(entity.id()) then return end

	canExplode = false
    isMonster = false
    isNPC = false
    isCritter = false

	if not world.entityExists(entity.id()) then
		return
	end

	entType = world.entityType(entity.id())
	
    if not blocker then blocker=config.getParameter("blocker","wingranjacapturado") end
    if entType == "monster" then
        isMonster = true
        local eConfig = root.monsterParameters(world.entityTypeName(entity.id()))
        subType = eConfig.bodyMaterialKind or status.statusProperty("targetMaterialKind") or (eConfig.statusSettings and eConfig.statusSettings.statusProperties and eConfig.statusSettings.statusProperties.targetMaterialKind)
        canExplode = true

    end
	self.didInit=true
end

function update(dt)
	if not self.didInit then init() end
	if not self.didInit then return end
	if canExplode then
		explode()
	end
end

function uninit()
end

function explode()
	if not blocker then blocker=config.getParameter("blocker","wingranjacapturado") end
	if not exploded then
		if not status.statPositive(blocker) then
			local treasureP = "money" -- Por defecto, entrega pixels, esto para inicializar la variable     
            if isMonster then
                local monsterType = world.monsterType(entity.id()) or "default"
                
                if monsterType == "moooshi" then
                    treasureP = "moooshispawner"
                
                elseif monsterType == "hen" then
                    treasureP = "henspawner"

                elseif monsterType == "moooshibaby" then
                    treasureP = "moooshispawnerbaby"
                
                elseif monsterType == "henbaby" then
                    treasureP = "henspawnerbaby"

                else
                    return
                end            
            else
                return            
            end 
            
            status.addPersistentEffect(blocker,{stat=blocker,amount=1})
			world.spawnTreasure(entity.position(),treasureP,world.threatLevel())
		end
		canExplode=false
		exploded = true
	end
end