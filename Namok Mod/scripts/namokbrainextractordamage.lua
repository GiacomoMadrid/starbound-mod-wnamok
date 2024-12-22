function applyDamageRequest(damageRequest)
  if damageRequest.damageSourceKind == "namokbrainextractor" then
    local entityId = damageRequest.targetEntityId
    if entityId and world.entityExists(entityId) then
      local health = world.entityHealth(entityId)
      if health and health[1] <= 10 then -- La entidad está muriendo
        generateTreasure(entityId)
      end
    end
  end
end

function generateTreasure(entityId)
  local targetType = world.entityType(entityId)
  local targetKind = world.entitySpecies(entityId)
  local treasurePool = nil

  if targetType == "monster" then
    local monsterType = world.monsterType(entityId) or "default"

    if monsterType == "smallquadruped" or monsterType == "largequadruped" then
      treasurePool = "brainquadruped"

    elseif monsterType == "smallflying" or monsterType == "largeflying" then
      treasurePool = "brainflying"
    
    elseif monsterType == "fish" or monsterType == "largefish" then
      treasurePool = "brainfish"

    elseif monsterType == "robotic" or monsterType == "bobot" or monsterType == "minidrone" or monsterType == "firebobot"  or monsterType == "triplod" or monsterType == "scandroid" or monsterType == "glitchspider" or monsterType == "pipkin" then
      treasurePool = "brainrobot"
    
    elseif monsterType == "apexbrainmutant" or monsterType == "moontant" then
      treasurePool = "brainnpc"
    
    elseif monsterType == "chicken" or monsterType == "hen" or monsterType == "mooshi" then
      treasurePool = "inferiorbrain"

    else
      treasurePool = "brain"
    end

  elseif targetType == "npc" then
    if targetKind == "glitch" then
      treasurePool = "brainnpcglitch"

    else
      treasurePool = "brainnpc"
    end

  elseif targetType == "robot" or targetType == "robotic" then
    treasurePool = "brainrobot"
  end

  local position = world.entityPosition(entityId)
  if position and treasurePool then
    sb.logInfo("D Spawning treasure '%s' at position %s", treasurePool, position)
    world.spawnTreasure(position, treasurePool)
  else
    sb.logWarn("D Failed to spawn treasure: treasurePool=%s, position=%s", treasurePool, position)
  end
end