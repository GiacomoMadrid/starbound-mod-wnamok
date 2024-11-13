function init()
  self.defenseBonus = config.getParameter("amount", 20)
  effect.addStatModifierGroup({
    {stat = "protection", amount = self.defenseBonus}
  })
end

function update(dt)
  
end

function uninit()
 
end