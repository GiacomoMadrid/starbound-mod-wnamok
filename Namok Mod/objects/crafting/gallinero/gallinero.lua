require "/scripts/util.lua"

function init()
  self.slots = {
    water = 0, food = 1, hens = 2, vitamin = 3,
    incubation = {4, 5, 6, 7},
    output = {8, 9, 10, 11, 12, 13, 14, 15, 16}
  }

  self.productionTime = config.getParameter("productionTime", 300) -- 5 minutos para producir huevos
  self.restTime = 20 -- 20 segundos de descanso entre producción
  self.incubationTime = config.getParameter("incubationTime", 180) -- 3 minutos para eclosionar
  self.growTime = 480 -- 8 minutos para crecer

  self.waterInputs = config.getParameter("waterInputs", {})
  self.foodInputs = config.getParameter("foodInputs", {})
  self.lojikumInputs = config.getParameter("lojikumInputs", {})
  self.baseDescription = config.getParameter("description", "")

  storage.waterBuffer = storage.waterBuffer or 0
  storage.foodBuffer = storage.foodBuffer or 0
  storage.productionTimer = storage.productionTimer or 0
  storage.restTimer = storage.restTimer or 0
  storage.activeHens = storage.activeHens or 0
  storage.isResting = storage.isResting or false
  
  -- Modificadores guardados del ciclo de producción actual
  storage.currentProduceRate = storage.currentProduceRate or 1.0
  storage.currentDoubleEgg = storage.currentDoubleEgg or 0
  storage.currentHenEggBonus = storage.currentHenEggBonus or 0
  storage.currentWaterUse = storage.currentWaterUse or 0

  -- Estructura de incubación con velocidad individual por slot
  storage.incubation = storage.incubation or {
    {timer = 0, item = nil, speed = 1.0}, {timer = 0, item = nil, speed = 1.0},
    {timer = 0, item = nil, speed = 1.0}, {timer = 0, item = nil, speed = 1.0}
  }

  message.setHandler("getTableData", function()
    return {
      productionTimer = storage.productionTimer,
      restTimer = storage.restTimer,
      isResting = storage.isResting,
      incubation = storage.incubation
    }
  end)
end

function update(dt)
  handleProduction(dt)
  handleIncubation(dt)
  updateDescription()
end

-- Función auxiliar para validar vitamina
function getValidVitamin()
  local v = world.containerItemAt(entity.id(), self.slots.vitamin)
  if v and self.lojikumInputs[v.name] then
    return v, self.lojikumInputs[v.name]
  end
  return nil, nil
end

function handleProduction(dt)
  if storage.isResting then
    storage.restTimer = math.max(0, storage.restTimer - dt)
    if storage.restTimer <= 0 then storage.isResting = false end
    return
  end

  if storage.productionTimer <= 0 and storage.activeHens <= 0 then
    local henStack = world.containerItemAt(entity.id(), self.slots.hens)
    if henStack and henStack.name == "henspawner" then
      if checkResources() then
        storage.activeHens = math.min(henStack.count, 8)
        world.containerConsumeAt(entity.id(), self.slots.hens, storage.activeHens)

        local mods = getModifiers()
        storage.currentProduceRate = mods.produceRate
        storage.currentDoubleEgg = mods.doubleeggBonus
        storage.currentHenEggBonus = mods.heneggProduceProbability
        storage.currentWaterUse = mods.waterUse
        
        -- Consumo de VITAMINA: Solo si es válida
        local itemV, dataV = getValidVitamin()
        if itemV then
          -- Aplicar el bono de la vitamina consumida al rate de producción
          storage.currentProduceRate = storage.currentProduceRate * (dataV.produceRate or 1.0)
          world.containerConsumeAt(entity.id(), self.slots.vitamin, 1)
        end

        storage.productionTimer = self.productionTime
      end
    end
  end

  if storage.productionTimer > 0 then
    local consumptionRate = (storage.activeHens / self.productionTime) * dt
    storage.waterBuffer = math.max(0, storage.waterBuffer - (consumptionRate * (1 + storage.currentWaterUse)))
    storage.foodBuffer = math.max(0, storage.foodBuffer - consumptionRate)
    storage.productionTimer = storage.productionTimer - (dt * storage.currentProduceRate)

    if storage.productionTimer <= 0 then finishProductionCycle() end
  end
end

function handleIncubation(dt)
  -- Para la crianza, el consumo de vitamina ocurre por cada slot individualmente al iniciar
  for i, slotIdx in ipairs(self.slots.incubation) do
    local state = storage.incubation[i]
    local item = world.containerItemAt(entity.id(), slotIdx)

    if not state.item then
      if item and (item.name == "henegg" or item.name == "henspawnerbaby") then
        state.item = item.name
        state.timer = (item.name == "henegg") and self.incubationTime or self.growTime
        world.containerConsumeAt(entity.id(), slotIdx, 1)
        
        -- Consumo de VITAMINA para crianza: Solo si es válida
        local itemV, dataV = getValidVitamin()
        state.speed = 1.0 -- Velocidad base
        if itemV then
          state.speed = dataV.produceRate or 1.0
          world.containerConsumeAt(entity.id(), self.slots.vitamin, 1)
        end
      end
    end

    if state.item then
      state.timer = state.timer - (dt * state.speed)
      
      if state.timer <= 0 then
        local resultItem = (state.item == "henegg") and "henspawnerbaby" or "henspawner"
        if addToOutput(resultItem, 1) == nil then
          state.item = nil
          state.timer = 0
          state.speed = 1.0
        end
      end
    end
  end
end

-- Genera el reporte para el globo de descripción al escanear
function updateDescription()
  local report = "^orange;PRODUCCIÓN:^reset;"
  
  -- Datos Producción
  local prodHens = storage.activeHens > 0 and storage.activeHens or 0
  local prodTime = (storage.productionTimer > 0) and formatTime(storage.productionTimer) or (storage.isResting and "^yellow;Descanso^reset;" or "--")
  local waterStr = (storage.waterBuffer > 0) and string.format("%.1f", storage.waterBuffer) or "--"
  local foodStr = (storage.foodBuffer > 0) and string.format("%.1f", storage.foodBuffer) or "--"
  
  report = report .. string.format("\nGallinas: %d/8\nTiempo: %s\nAgua: %s | Comida: %s", prodHens, prodTime, waterStr, foodStr)
  
  -- Datos Crianza
  report = report .. "\n\n^orange;CRIANZA:^reset;"
  local slots = {"A", "B", "C", "D"}
  for i, name in ipairs(slots) do
    local state = storage.incubation[i]
    local line = "Disponible"
    if state.item then
      local tipo = (state.item == "henegg") and "Huevo" or "Pollito"
      line = string.format("%s (%s)", tipo, formatTime(state.timer))
    end
    report = report .. "\nSlot " .. name .. ": " .. line
  end
  
  object.setConfigParameter("description", report)
end

function formatTime(s)
  if s <= 0 then return "0:00" end
  return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end

-- Resto de funciones se mantienen igual
function checkResources()
  if storage.waterBuffer <= 0 then
    local w = world.containerItemAt(entity.id(), self.slots.water)
    if w and self.waterInputs[w.name] then
      storage.waterBuffer = self.waterInputs[w.name].value
      world.containerConsumeAt(entity.id(), self.slots.water, 1)
    end
  end
  if storage.foodBuffer <= 0 then
    local f = world.containerItemAt(entity.id(), self.slots.food)
    if f and self.foodInputs[f.name] then
      storage.foodBuffer = self.foodInputs[f.name].value
      world.containerConsumeAt(entity.id(), self.slots.food, 1)
    end
  end
  return (storage.waterBuffer > 0 and storage.foodBuffer > 0)
end

function getModifiers()
  local m = { produceRate = 1.0, waterUse = 0, doubleeggBonus = 0, heneggProduceProbability = 0 }
  local f = world.containerItemAt(entity.id(), self.slots.food)
  if f and self.foodInputs[f.name] then
    local d = self.foodInputs[f.name]
    m.produceRate = d.produceRate or 1.0
    m.waterUse = d.waterUse or 0
    m.doubleeggBonus = d.doubleeggBonus or 0
    m.heneggProduceProbability = d.heneggProduceProbability or 0
  end
  -- Nota: La vitamina ya no se lee aquí para el rate base, se consume al inicio
  return m
end

function finishProductionCycle()
  local hens = {name = "henspawner", count = storage.activeHens}
  local left = world.containerPutItemsAt(entity.id(), hens, self.slots.hens)
  if left then world.spawnItem(left, entity.position()) end

  for i = 1, storage.activeHens do
    local roll = math.random()
    local cHen = 0.02 + storage.currentHenEggBonus
    local cDb = 0.08 + storage.currentDoubleEgg
    if roll < cHen then addToOutput("henegg", 1)
    elseif roll < (cHen + cDb) then addToOutput("egg", 2)
    else addToOutput("egg", 1) end
  end

  storage.activeHens = 0
  storage.isResting = true
  storage.restTimer = self.restTime
end

function addToOutput(name, count)
  local item = {name = name, count = count}
  for _, s in ipairs(self.slots.output) do
    item = world.containerPutItemsAt(entity.id(), item, s)
    if not item then return nil end
  end
  if item and item.count > 0 then
    world.spawnItem(item.name, entity.position(), item.count)
  end
  return nil
end

function die()  
  if storage.activeHens > 0 then
    world.spawnItem({name = "henspawner", count = storage.activeHens}, entity.position())
  end
  for _, state in ipairs(storage.incubation) do
    if state.item then
      world.spawnItem({name = state.item, count = 1}, entity.position())
    end
  end
  object.setConfigParameter("description", self.baseDescription )
end