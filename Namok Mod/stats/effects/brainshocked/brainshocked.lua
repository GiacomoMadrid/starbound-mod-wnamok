require "/scripts/util.lua"

function init()
	if not world.entityType(entity.id()) then return end

	canExplode = false
    isMonster = false
    isNPC = false
    isCritter = false

	if (status.resourceMax("health") < config.getParameter("minMaxHealth", 0)) or (not world.entityExists(entity.id())) then
		return
	end

	entType = world.entityType(entity.id())
	
    if not blocker then blocker=config.getParameter("blocker","brainshocked") end
    if entType == "monster" then
        isMonster = true
        local minBaseHealth = config.getParameter("minBaseHealth",10)
        local eConfig = root.monsterParameters(world.entityTypeName(entity.id()))
        subType = eConfig.bodyMaterialKind or status.statusProperty("targetMaterialKind") or (eConfig.statusSettings and eConfig.statusSettings.statusProperties and eConfig.statusSettings.statusProperties.targetMaterialKind)
        
        if minBaseHealth then
            local baseHealth = eConfig.statusSettings and eConfig.statusSettings.stats and eConfig.statusSettings.stats.maxHealth and eConfig.statusSettings.stats.maxHealth.baseValue or 0
            
            if baseHealth > minBaseHealth then
                canExplode = true
            end
        else
            canExplode = true
        end

    elseif entType == "npc" then
        isNPC = true
        subType = world.entitySpecies(entity.id())
        canExplode = true
    
    elseif entType == "critter" then
        isCritter = true
        canExplode = true
    end
	


	self.didInit=true
end

function update(dt)
	if not self.didInit then init() end
	if not self.didInit then return end
	if canExplode and (status.resourcePercentage("health") <= 0.01) then
		explode()
	end
end

function uninit()
end

function explode()
	if not blocker then blocker=config.getParameter("blocker","brainshocked") end
	if not exploded then
		if not status.statPositive(blocker) then
			local treasureP = "money" -- Por defecto, entrega pixels, esto para inicializar la variable     
            if isMonster then
                local monsterType = world.monsterType(entity.id()) or "default"
                
                if monsterType == "smallquadruped" or monsterType == "largequadruped" then
                    treasureP = "brainquadruped"
                
                elseif monsterType == "smallflying" or monsterType == "largeflying" then
                    treasureP = "brainflying"                
                
                elseif monsterType == "fish" or monsterType == "largefish" then
                    treasureP = "brainfish"
                
                elseif monsterType == "robotchicken" or monsterType == "robothen" or monsterType == "bobot" or monsterType == "minidrone" or monsterType == "firebobot"  or monsterType == "triplod" or monsterType == "scandroid" or monsterType == "glitchspider" or monsterType == "pipkin" then
                    treasureP = "brainrobot"                
                
                elseif monsterType == "apexbrainmutant" then
                    treasureP = "brainnpc"       

                elseif monsterType == "moontant" then
                    treasureP = "erchiusbrain" 

                elseif monsterType == "chicken" or monsterType == "hen" or monsterType == "mooshi" then
                    treasureP = "inferiorbrain"
                
                elseif monsterType == "nutmidge" then
                    treasureP = "nutmidgebrain"
                
                elseif monsterType == "robot" or targetType == "robotic" then --consistencia para mods ajenos que tengan robots no registrados
                    treasureP = "brainrobot"

                else
                    treasureP = "braindefault"
                end

            elseif isNPC then           
                if subType == "glitch" then
                    treasureP = "brainnpcglitch"
            
                else
                    treasureP = "brainnpc"
                end  

            elseif isCritter then
                treasureP = "braincritter"
            end            

            status.addPersistentEffect(blocker,{stat=blocker,amount=1})
			world.spawnTreasure(entity.position(),treasureP,world.threatLevel())
		end
		canExplode=false
		exploded = true
	end
end