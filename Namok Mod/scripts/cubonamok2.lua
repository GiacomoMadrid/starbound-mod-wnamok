function init()
  activeItem.setHoldingItem(false)
end

function activate(fireMode, shiftHeld)
  local interactData = root.assetJson("/interface/scripted/cubonamok2/cubonamok.config")
  interactData.gui.data.data = {
    storedItems = config.getParameter("storedItems"),
    backpackSettings = config.getParameter("backpackSettings"),
    price = config.getParameter("price")
  }
  activeItem.interact("ScriptPane", interactData)
  item.consume(1)
  if animator.hasSound("open") then
    animator.playSound("open")
  end
end
