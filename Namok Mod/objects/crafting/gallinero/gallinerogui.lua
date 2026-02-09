function init()
  self.promise = nil
end

function update(dt)
  if self.promise == nil then
    local containerId = pane.containerEntityId()
    if containerId then
      self.promise = world.sendEntityMessage(containerId, "getTableData")
    end
  end

  if self.promise ~= nil and self.promise:finished() then
    if self.promise:succeeded() then
      local res = self.promise:result()
      if res then updateLabels(res) end
    end
    self.promise = nil
  end
end

function updateLabels(res)
  local pLabel = "--"
  if res.isResting then 
    pLabel = "^yellow;Descanso"
  elseif res.productionTimer and res.productionTimer > 0 then 
    pLabel = formatTime(res.productionTimer) 
  end
  widget.setText("timerProduction", pLabel) 

  local labels = {"timerA", "timerB", "timerC", "timerD"}
  for i, lName in ipairs(labels) do
    local data = res.incubation[i]
    if data and data.timer and data.timer > 0 then
      widget.setText(lName, formatTime(data.timer))
    else
      widget.setText(lName, "--")
    end
  end
end

function formatTime(s)
  return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end