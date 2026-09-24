require "/scripts/util.lua"

function init()
  self.slots = {
    water = 0, food = 1, mooshis = 2, lojikum = 3,
    incubation = {4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
    output = {16, 17, 18, 19, 
              20, 21, 22, 23, 
              24, 25, 26, 27, 
              28, 29, 30, 31, 
              32, 33, 34, 35, 
              36, 37, 38, 39 
            }
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
  storage.activeMooshis = storage.activeMooshis or 0
  storage.isResting = storage.isResting or false
  
  -- Modificadores guardados del ciclo de producción actual
  storage.currentProduceRate = storage.currentProduceRate or 1.0
  storage.currentDoubleMilk = storage.currentDoubleMilk or 0
  storage.currentMooshiEggBonus = storage.currentMooshiEggBonus or 0
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
function getValidLojikum()
  local v = world.containerItemAt(entity.id(), self.slots.lojikum)
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

  if storage.productionTimer <= 0 and storage.activeMooshis <= 0 then
    local henStack = world.containerItemAt(entity.id(), self.slots.hens)
    if henStack and henStack.name == "mooshispawner" then
      if checkResources() then
        storage.activeMooshis = math.min(henStack.count, 8)
        world.containerConsumeAt(entity.id(), self.slots.hens, storage.activeHens)

        local mods = getModifiers()
        storage.currentProduceRate = mods.produceRate
        storage.currentDoubleMilk = mods.doubleMilkBonus
        storage.currentMooshiEggBonus = mods.mooshieggProduceProbability
        storage.currentWaterUse = mods.waterUse
        
        -- Consumo de VITAMINA: Solo si es válida
        local itemV, dataV = getValidLojikum()
        if itemV then
          -- Aplicar el bono de la vitamina consumida al rate de producción
          storage.currentProduceRate = storage.currentProduceRate * (dataV.produceRate or 1.0)
          world.containerConsumeAt(entity.id(), self.slots.lojikum, 1)
        end

        storage.productionTimer = self.productionTime
      end
    end
  end

  if storage.productionTimer > 0 then
    local consumptionRate = (storage.activeMooshis / self.productionTime) * dt
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
      if item and (item.name == "mooshiegg" or item.name == "mooshispawnerbaby") then
        state.item = item.name
        state.timer = (item.name == "mooshiegg") and self.incubationTime or self.growTime
        world.containerConsumeAt(entity.id(), slotIdx, 1)
        
        -- Consumo de VITAMINA para crianza: Solo si es válida
        local itemV, dataV = getValidLojikum()
        state.speed = 1.0 -- Velocidad base
        if itemV then
          state.speed = dataV.produceRate or 1.0
          world.containerConsumeAt(entity.id(), self.slots.lojikum, 1)
        end
      end
    end

    if state.item then
      state.timer = state.timer - (dt * state.speed)
      
      if state.timer <= 0 then
        local resultItem = (state.item == "mooshiegg") and "mooshispawnerbaby" or "mooshispawner"
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
  local report = "^orange;PRODUCCIÓN^reset;"
  
  -- Datos Producción
  local prodMooshis = storage.activeMooshis > 0 and storage.activeMooshis or 0
  local prodTime = (storage.productionTimer > 0) and formatTime(storage.productionTimer) or (storage.isResting and "^yellow;Descanso^reset;" or "--")
  local waterStr = (storage.waterBuffer > 0) and string.format("%.1f", storage.waterBuffer) or "--"
  local foodStr = (storage.foodBuffer > 0) and string.format("%.1f", storage.foodBuffer) or "--"
  
  report = report .. string.format("\nGallinas: %d/8\n^green;Tiempo:^reset; %s\n^blue;Agua:^reset; %s | ^yellow;Comida:^reset; %s", prodMooshis, prodTime, waterStr, foodStr)
  
  -- Datos Crianza
  report = report .. "\n\n^orange;CRIANZA^reset;"
  local slots = {"A^reset;", "B^reset;", "C^reset;", "D^reset;", "E^reset;", "F^reset;", "G^reset;", "H^reset;", "I^reset;", "J^reset;", "K^reset;", "L^reset;"}
  for i, name in ipairs(slots) do
    local state = storage.incubation[i]
    local line = "^green;Disponible^reset;"
    if state.item then
      local tipo = (state.item == "mooshiegg") and "Huevo" or "Mooshi Calf"
      line = string.format("%s (%s)", tipo, formatTime(state.timer))
    end
    if i % 2 == 0 then
      report = report .. "\n^yellow;Slot " .. name .. ": " .. line
    else
      report = report .. "  |  ^yellow;Slot " .. name .. ": " .. line
    end

    
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
  local m = { produceRate = 1.0, waterUse = 0, doubleMilkBonus = 0, mooshieggProduceProbability = 0 }
  local f = world.containerItemAt(entity.id(), self.slots.food)
  if f and self.foodInputs[f.name] then
    local d = self.foodInputs[f.name]
    m.produceRate = d.produceRate or 1.0
    m.waterUse = d.waterUse or 0
    m.doubleMilkBonus = d.doubleMilkBonus or 0
    m.mooshieggProduceProbability = d.mooshieggProduceProbability or 0
  end
  -- Nota: La vitamina ya no se lee aquí para el rate base, se consume al inicio
  return m
end

function finishProductionCycle()
  local mooshis = {name = "mooshispawner", count = storage.activeHens}
  local left = world.containerPutItemsAt(entity.id(), hens, self.slots.hens)
  if left then world.spawnItem(left, entity.position()) end

  for i = 1, storage.activeMooshis do
    local roll = math.random()
    local cHen = 0.02 + storage.currentMooshiEggBonus
    local cDb = 0.08 + storage.currentDoubleMilk
    if roll < cHen then addToOutput("mooshiegg", 1)
    elseif roll < (cHen + cDb) then addToOutput("milk", 2)
    else addToOutput("milk", 1) end
  end

  storage.activeMooshis = 0
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
  if storage.activeMooshis > 0 then
    world.spawnItem({name = "mooshispawner", count = storage.activeHens}, entity.position())
  end
  for _, state in ipairs(storage.incubation) do
    if state.item then
      world.spawnItem({name = state.item, count = 1}, entity.position())
    end
  end
  object.setConfigParameter("description", self.baseDescription )
end