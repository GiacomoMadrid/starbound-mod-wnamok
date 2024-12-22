local oldInit = init
local oldUpdate = update

function init()
  if oldInit then oldInit() end
end

function update(dt, fireMode, shiftHeld)
  if oldUpdate then oldUpdate(dt, fireMode, shiftHeld) end

  -- Solo ejecuta `checkTarget` si el arma está disparando
  if fireMode == "primary" then
    local status, err = pcall(checkTarget)
    if not status then
      sb.logError("Error in checkTarget: %s", err)
    end
  end
end

function checkTarget()
  local aimPosition = activeItem.ownerAimPosition()
  if not aimPosition then return end

  local nearbyEntities = world.entityQuery(aimPosition, 2.0, {includedTypes = {"npc", "monster"}})

  for _, entityId in ipairs(nearbyEntities) do
    -- Verifica que la entidad existe y está muerta
    if world.entityExists(entityId) and world.entityHealth(entityId)[1] <= 10 then
      local targetType = world.entityType(entityId)
      local targetKind = world.entitySpecies(entityId)
      local treasurePool = nil

      -- Selección del treasurePool según tipo de entidad
      if targetType == "robot" then
        treasurePool = "brainrobot"

      elseif targetType == "npc" then
        if targetKind == "glitch" then
          treasurePool = "brainnpcglitch"
        else
          treasurePool = "brainnpc"
        end

      elseif  targetType == "monster" then
        local monsterType = world.monsterType(entityId) or "default"
        if monsterType == "quadruped" then
          treasurePool = "brainquadruped"
        elseif monsterType == "flying" then
          treasurePool = "brainflying"
        else
          treasurePool = "brain"
        end
      end

      -- Valida la posición y genera el tesoro
      local position = world.entityPosition(entityId)
      if position and treasurePool then
        local posX = tonumber(position[1])
        local posY = tonumber(position[2])
        if posX and posY then
          sb.logInfo("Spawning treasure '%s' at position (%f, %f)", treasurePool, posX, posY)
          world.spawnTreasure({posX, posY}, treasurePool)
        else
          sb.logWarn("Invalid position: %s", position)
        end
      else
        sb.logWarn("Failed to spawn treasure: treasurePool=%s, position=%s", treasurePool, position)
      end
    end
  end
end