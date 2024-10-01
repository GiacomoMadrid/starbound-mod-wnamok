function init()
  -- Definir los slots de entrada y salida
  self.inputSlot = 0 -- Slot de entrada (primer slot del itemGrid)
  self.outputSlots = {1, 2, 3, 4, 5, 6, 7, 8, 9} -- Slots de salida

  -- Definir el tiempo de procesamiento
  self.processingTime = 0.25 -- Tiempo para procesar un ítem
  self.processingTimer = 0

  -- Variable para controlar el ítem en proceso
  self.activeItem = nil

  -- Cargar todas las recetas desde el archivo unificado
  self.recipes = root.assetJson("/recipes/extractornamok1_recipes.json")
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
    local inputItem = world.containerItemAt(entity.id(), self.inputSlot)
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
    self.processingTimer = self.processingTime
    self.activeItem = recipe
    -- Remover la cantidad necesaria del ítem de entrada
    world.containerConsumeAt(entity.id(), self.inputSlot, recipe.input[1].count)
  end
end

function completeProcessing()
  if self.activeItem then
    -- Asegurarse de que self.activeItem.output no sea nil
    if self.activeItem.output == nil then
      sb.logError("La receta activa no tiene salidas definidas.")
      return
    end

    -- Definir el tamaño máximo de la pila (ajústalo según lo necesario, generalmente es 1000)
    local maxStackSize = 1000

    -- Distribuir los ítems de salida a los slots de salida
    for i, output in ipairs(self.activeItem.output) do
      local outputItem = {name = output.item, count = output.count}
      
      -- Insertar el ítem en el siguiente slot de salida disponible
      local placed = false
      for _, slot in ipairs(self.outputSlots) do
        local existingStack = world.containerItemAt(entity.id(), slot)
        
        -- Asegurarse de que el existingStack es válido
        if existingStack == nil then
          existingStack = {name = outputItem.name, count = 0}
        end
        
        -- Verificar si el slot tiene espacio suficiente
        if (existingStack.name == outputItem.name and (existingStack.count + outputItem.count <= maxStackSize)) or existingStack.name == nil then
          world.containerPutItemsAt(entity.id(), outputItem, slot)
          placed = true
          break
        end
      end

      -- Si no hay espacio, devolver los ítems al jugador
      if not placed then
        world.spawnItem(outputItem, entity.position())
      end
    end

    -- Reiniciar el proceso
    self.activeItem = nil
  end
end