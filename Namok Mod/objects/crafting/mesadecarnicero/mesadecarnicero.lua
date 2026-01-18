function init()
  -- Definir los slots de entrada y salida
  self.inputSlot = 0 -- Slot de entrada (primer slot del itemGrid)
  self.outputSlots = {1, 2, 3, 4, 5, 6, 7, 8, 9} -- Slots de salida

  -- Definir el tiempo de procesamiento
  self.processingTime = 0.5 -- Tiempo para procesar un ítem
  self.processingTimer = 0

  -- Variable para controlar el ítem en proceso
  self.activeItem = nil

  -- Cargar todas las recetas desde el archivo unificado
  self.recipes = root.assetJson("/recipes/mesadecarnicero_recipes.json")
end

function update(dt)
  -- Verificar si estamos procesando un ítem
  if self.processingTimer > 0 then
    self.processingTimer = self.processingTimer - dt
    if self.processingTimer <= 0 then
      -- Proceso completado
      completeProcessing()
    end
  else
    -- Verificar si hay un ítem de entrada y si podemos procesarlo
    local inputItem = world.containerItemAt(entity.id(), self.inputSlot) or nil
    if inputItem ~= nil and isRecipeValid(inputItem) then
      -- Iniciar el procesamiento
      startProcessing(inputItem)
    end
  end
end

function isRecipeValid(item)
  -- Validar si el ítem corresponde a una receta válida
  local recipe = getRecipeForItem(item)
  return recipe ~= nil
end

function getRecipeForItem(item)
  -- Buscar la receta correspondiente al ítem de entrada
  for _, recipe in ipairs(self.recipes) do
    if recipe.input[1].item == item.name and recipe.input[1].count <= item.count then
      return recipe
    end
  end
  return nil
end

function startProcessing(item)
  -- Obtener la receta
  local recipe = getRecipeForItem(item)
  if recipe then
    -- Iniciar el procesamiento
    self.processingTimer = recipe.duration or self.processingTime
    self.activeItem = recipe
    -- Remover la cantidad necesaria del ítem de entrada
    world.containerConsumeAt(entity.id(), self.inputSlot, recipe.input[1].count)
  end
end

function onTakeAllPressed()
  -- Recorre todos los slots de salida y entrega los ítems al jugador
  for _, slot in ipairs(self.outputSlots) do
    local outputItem = world.containerItemAt(entity.id(), slot)
    if outputItem ~= nil then
      -- Quitar el ítem del contenedor y dárselo al jugador
      world.containerConsumeAt(entity.id(), slot, outputItem.count)
      world.spawnItem(outputItem, world.entityPosition(player.id()))
    end
  end
end

function completeProcessing()
  if self.activeItem then
    -- Asegurarse de que self.activeItem.output no sea nil
    if self.activeItem.output == nil then
      sb.logError("La receta activa no tiene salidas definidas.")
      return
    end
    
    -- Distribuir los ítems de salida a los slots de salida
    for i, output in ipairs(self.activeItem.output) do
      local item = {name = output.item, count = output.count}
      outputToButcherTable(entity.id(), self.outputSlots, item)
    end
    
    -- Reiniciar el proceso
    self.activeItem = nil
  end
  sb.logInfo("----------------------------------------------------------")
end

function getMaxStack(itemName)
  local cfg = root.itemConfig(itemName)
  if not cfg or not cfg.config then return 1000 end
  if cfg.config.maxStack == nil then return 1000 end
  return math.min(cfg.config.maxStack, 1000)
end


function countItemInContainer(containerId, itemName)
  local total = 0
  local size = world.containerSize(containerId)

  for i = 0, size - 1 do
    local item = world.containerItemAt(containerId, i)
    if item and item.name == itemName then
      total = total + item.count
    end
  end

  return total
end

function stackIntoOutputSlots(containerId, outputSlots, item)
  local remaining = item.count
  local maxStack = getMaxStack(item.name)

  for _, slot in ipairs(outputSlots) do
    if remaining <= 0 then break end

    local current = world.containerItemAt(containerId, slot)
    if current and current.name == item.name and (maxStack >= current.count) then
      local space = maxStack - current.count
      if space > 0 then
        local toAdd = math.min(space, remaining)
        
        if  maxStack < 1000 then break end
        --[[ 
        Por alguna razón, la función containerPutItemsAt() aparentemente falla cuando el maxStack del item
        no es 1000, motivo por el cual los items cuyo maxStack sea menor a 1000 serán invocados en otro
         slot si es que está disponible, de lo contrario serán invocados con spawnItem()
        ]]
        world.containerPutItemsAt(containerId, { name = item.name, count = toAdd }, slot)
        sb.logInfo("Agregando: %s de %s al slot %s", toAdd, item.name, slot)
        local numItem = countItemInContainer(containerId, item.name)
        sb.logInfo("Cantidad total de %s en el contenedor: %s", item.name, numItem)
        remaining = remaining - toAdd
        sb.logInfo("Sobrante: %s de %s", remaining, item.name)
      end
    end
  end

  if remaining > 0 then
    return { name = item.name, count = remaining }
  end

  return nil
end

function putIntoEmptyOutputSlots(containerId, outputSlots, item)
  local remaining = item.count
  local maxStack = getMaxStack(item.name)

  for _, slot in ipairs(outputSlots) do
    if remaining <= 0 then break end

    if world.containerItemAt(containerId, slot) == nil then
      local toPut = math.min(maxStack, remaining)

      world.containerPutItemsAt(containerId, { name = item.name, count = toPut }, slot)
      sb.logInfo("Agregando: %s de %s al slot %s", toPut, item.name, slot)
      local numItem = countItemInContainer(containerId, item.name)
      sb.logInfo("Cantidad total de %s en el contenedor: %s", item.name, numItem)
      remaining = remaining - toPut
      sb.logInfo("Sobrante: %s de %s", remaining, item.name)
    end
  end

  if remaining > 0 then
    return { name = item.name, count = remaining }
  end

  return nil
end

function outputToButcherTable(containerId, outputSlots, item)
  local leftover = stackIntoOutputSlots(containerId, outputSlots, item)

  if leftover then
    leftover = putIntoEmptyOutputSlots(containerId, outputSlots, leftover)
  end

  if leftover then
    world.spawnItem(leftover, entity.position())
  end
end


--[[
  *********************** FUNCIÓN QUE NO STACKEA PERO RESPETA EL INPUT SLOT ***********************

  -- Insertar el ítem en el siguiente slot de salida disponible 
      local placed = false
      for _, slot in ipairs(self.outputSlots) do
        local existingStack = world.containerItemAt(entity.id(), slot)
        
        -- Asegurarse de que el existingStack es válido
        if existingStack == nil then
          existingStack = {name = outputItem.name, count = 0}
        end
        
        -- Verificar si el slot tiene espacio suficiente
        if (existingStack.name == outputItem.name and (existingStack.count + outputItem.count <= maxStackItem)) or existingStack.name == nil then
          world.containerPutItemsAt(entity.id(), outputItem, slot)
          local numItem =  world.containerItemAt(entity.id(), slot).count or 0
          sb.logInfo("Cantidad total del item agregado: %s", numItem)
          
          placed = true
          break
        end
      end

      -- Si no hay espacio, devolver los ítems al jugador
      if not placed then
        world.spawnItem(outputItem, entity.position())
      end
    

  *********************** FUNCIÓN QUE STACKEA PERO NO RESPETA EL INPUT SLOT ***********************
  
  for i, output in ipairs(self.activeItem.output) do
    local maxStackItem = getMaxStack(output.item)
    local outputItem = {name = output.item, count = output.count}
    sb.logInfo("Item de salida: %s MaxStack: %s", outputItem, maxStackItem)     
    

    local leftover = world.containerStackItems(entity.id(), outputItem)

    if leftover then
      local emptySlots = getEmptySlots(entity.id())
      if #emptySlots > 0 then
        leftover = world.containerPutItemsAt(entity.id(), leftover, emptySlots[1])
      end
    end

    if leftover then
      world.spawnItem(leftover, entity.position())
    end
  end

  *********************** FUNCIONES AUXILIARES DESCONTINUADAS ***********************
  
  function getEmptySlots(containerId)
    local empty = {}
    local size = world.containerSize(containerId)
    for i = 0, size - 1 do
      if world.containerItemAt(containerId, i) == nil then
        table.insert(empty, i)
      end
    end
    return empty
  end

  function getEmptyOutputSlots(containerId)
    local empty = {}
    local size = world.containerSize(containerId)
    for i = 1, size - 1 do
      if world.containerItemAt(containerId, i) == nil then
        table.insert(empty, i)
      end
    end
    return empty
  end

  function containerHasEmptySlot(containerId)
    local size = world.containerSize(containerId)
    for i = 0, size - 1 do
      if world.containerItemAt(containerId, i) == nil then
        return true
      end
    end
    return false
  end

  function containerHasEmptyOutputSlot(containerId)
    for out in self.outputSlots do
      if world.containerItemAt(containerId, out) == nil then
        return true
      end
    end
    return false
  end


]]