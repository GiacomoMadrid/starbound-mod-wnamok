require "/scripts/norx.lua"
require "/scripts/sha3.lua"
require "/scripts/bin.lua"
require "/scripts/json.lua"

function init()
  price = widget.getData("data").price
  currentPage = 1
  settingsPage = 1

  backpackSettings = widget.getData("data").backpackSettings
  storedItems = widget.getData("data").storedItems

  backpackSettings, storedItems = versioning(backpackSettings, storedItems)
  toggleBag(true, 1)

  local imagePath = "/interface/scripted/cubonamok2/"
  for _,v in pairs({"Header", "Body", "Footer"}) do
    widget.setImage("file"..v, imagePath..string.lower(v)..".png".."?multiply="..
      hexConverter(255)..
      hexConverter(255)..
      hexConverter(255)
    )
  end
  widget.setText("title", backpackSettings.title)
  widget.setText("subtitle", "Cubo Ñamok Anaranjado")  
end

function versioning(settings, items)
  if settings then newSettings = deepCopy(settings) end
  if items then newItems = deepCopy(items) end

  -- 1.x => 2.1
  if newSettings.colourIndex and not newSettings.version then
    newSettings.colourIndex = nil
    newSettings.colour = {
      enabled = false,
      red = 255,
      green = 255,
      blue = 255
    }
  end

  -- 2.1 => 2.2
  if newSettings.pageCount == nil and not newSettings.version then
    newSettings.pageCount = 1
    newItems = {}
    newItems.page1 = {}
    for i,v in pairs(items) do
      newItems.page1[i] = v
    end
  end

  -- 2.2 => 2.3
  if not newSettings.version then
    local tempItems = {}
    for i=1, newSettings.pageCount do
      tempItems[i] = newItems["page"..i]
    end
    newItems = deepCopy(tempItems)
    newSettings.pageCount = nil
    newSettings.version = 2.3
  end

  return newSettings, newItems
end

function update(dt)
  
end

function changeTab()
  local tab = widget.getSelectedData("tabs")
  if
  tab == "bag" then
    toggleBag(true, currentPage)
    toggleSettings(false)
  elseif
  tab == "settings" then
    toggleBag(false)
    toggleSettings(true)
  end
end

function changePage(button)
  storedItems[currentPage] = getPageItems()

  if button == "pageLeft" then
    if currentPage > 1 then
      currentPage = currentPage - 1
    end
  elseif button == "pageRight" then
    if currentPage < #storedItems then
      currentPage = currentPage + 1
    end
  end

  for row = 1, 8 do
    for column = 1, 6 do
      local pos = row.."_"..column
      widget.setItemSlotItem("itemSlot_"..pos, nil)
    end
  end

  toggleBag(true, storedItems[currentPage])
end

function changeSettingsPage(button)
  local appearanceItems = {
    "editTitle",      "editTitle_image"
  }

  if settingsPage == 1 then
    widget.setText("contextLabel", "TITULO")
    for _,v in ipairs(appearanceItems) do
      widget.setVisible(v, true)
    end
  end

  widget.setText("settingsPage", "Cambiar nombre")
end

function toggleBag(visible, page)
  widget.setText("page", currentPage.." / "..(#storedItems or 1))

  if visible then
    widget.setText("context", "^#b9b5b2;"..(#storedItems * 48).." SLOTS")
    setPageItems(currentPage)
  end
  for row = 1, 8 do
    for column = 1, 6 do
      local pos = row.."_"..column
      widget.setVisible("itemSlot_"..pos, visible)
    end
  end

  for _,v in pairs({"page", "pageLeft", "pageRight"}) do
    widget.setVisible(v, visible and #storedItems > 1)
  end
end


function toggleSettings(visible)
  settingsPage = 1
  widget.setText("settingsPage", settingsPage.." / 2")

  if visible then
    widget.setText("context", "^#b9b5b2;   SETTINGS")
    widget.setText("editTitle", backpackSettings.title)
    widget.setText("subtitle", "Cubo Ñamok Anaranjado")  
  end

  widget.setVisible("contextLabel", visible)
  widget.setText("contextLabel", "TITULO")

  for _,v in pairs({"Title", "Subtitle", "Colour"}) do
    for _,v2 in pairs({"", "_label", "_image"}) do
      widget.setVisible("edit"..v..v2, visible)
    end
  end
  
end

function editTitle()
  backpackSettings.title = widget.getText("editTitle")
  widget.setText("title", backpackSettings.title)
end

function editLayout()
  local imagePath = "/interface/scripted/cubonamok2/"
  for _,v in pairs({"Header", "Body", "Footer"}) do
    widget.setImage("file"..v, imagePath..string.lower(v)..".png?multiply="..
      hexConverter(255)..
      hexConverter(255)..
      hexConverter(255)
    )
  end
  widget.setImage("iconOverlay", "/assetMissing.png?scale=1?crop=0;0;16;16"..root.assetJson("/interface/scripted/cubonamok2/backpackIcons.config").overlay..";?multiply="..
    hexConverter(255)..
    hexConverter(255)..
    hexConverter(255)
  )
end

function uninit()
  if type(storedItems[1]) ~= "number" then
    storedItems[currentPage] = getPageItems()
    price = 256
    for _,page in ipairs(storedItems) do
      for _,v in ipairs(page) do
        if type(v) == "table" and v.parameters and (v.parameters.price or root.itemConfig(v.name).config.price) then
          price = price + (v.count * (v.parameters.price or root.itemConfig(v.name).config.price))
        end
      end
    end    
  end

  --local item = root.assetJson("/items/active/cubonamok2/cubonamok2.activeitem")
  local item = root.assetJson("/recipes/wingo2/cubonamok2.recipe:output")
  sb.logInfo("Valor de item: %s", sb.printJson(item, 1))
  sb.logInfo("Tipo de item: %s", sb.printJson(type(item), 1))

  item.parameters = item.parameters or {}

  item.parameters.price = price
  item.parameters.storedItems = storedItems
  item.parameters.backpackSettings = backpackSettings
  item.parameters.shortdescription = backpackSettings.title
  item.parameters.category = backpackSettings.subtitle.."^reset;"
  item.parameters.inventoryIcon = {{
    image = "/interface/scripted/cubonamok2/cubonamok2icon.png",
    position = {0,0}
  }, {
    image = "/interface/scripted/cubonamok2/cubonamok2icon.png",
    position = {0,0}
  }}
  player.giveItem(item)
  sb.logInfo("Valor de item: %s", sb.printJson(item, 1))
  sb.logInfo("Tipo de item: %s", sb.printJson(type(item), 1))
end

function setPageItems(page)
  local pageItems = storedItems[page]
  if pageItems then
    for row = 1, 8 do
      for column = 1, 6 do
        local pos = row.."_"..column
        widget.setItemSlotItem("itemSlot_"..pos, pageItems["itemSlot_"..pos])
      end
    end
  end
end

function getPageItems()
  local pageItems = {}
  for row = 1, 8 do
    for column = 1, 6 do
      local pos = row.."_"..column
      pageItems["itemSlot_"..pos] = widget.itemSlotItem("itemSlot_"..pos)
    end
  end
  return pageItems
end

function leftClickSlot(slot)
  if player.swapSlotItem() then
    local itemName = player.swapSlotItem().name
    if itemName ~= "cubonamok2" and itemName ~= "cubonamok3" and itemName ~= "cubonamok4" then
      if widget.itemSlotItem(slot) then
        local item = player.swapSlotItem()
        local maxStack = item.parameters.maxStack or root.itemConfig(item.name).config.maxStack or root.assetJson("/items/defaultParameters.config:defaultMaxStack")
        local widgetItem = widget.itemSlotItem(slot)
        if root.itemDescriptorsMatch(item, widgetItem, true) then
          if not (item.count + widgetItem.count > maxStack) then
            widgetItem.count = widgetItem.count + item.count
            widget.setItemSlotItem(slot, widgetItem)
            player.setSwapSlotItem(nil)
          else
            if widgetItem.count == maxStack or item.count == maxStack then
              widget.setItemSlotItem(slot, item)
              player.setSwapSlotItem(widgetItem)
            else
              item.count = item.count - (maxStack - widgetItem.count)
              widgetItem.count = maxStack
              widget.setItemSlotItem(slot, widgetItem)
              player.setSwapSlotItem(item)
            end
          end
        else
          widget.setItemSlotItem(slot, player.swapSlotItem())
          player.setSwapSlotItem(widgetItem)
        end
      else
        widget.setItemSlotItem(slot, player.swapSlotItem())
        player.setSwapSlotItem(nil)
      end
    end
  elseif widget.itemSlotItem(slot) then
    player.setSwapSlotItem(widget.itemSlotItem(slot))
    widget.setItemSlotItem(slot, nil)
  end
  storedItems[currentPage] = getPageItems()
end

function rightClickSlot(slot)
  if widget.itemSlotItem(slot) then
    local item = player.swapSlotItem()
    local widgetItem = widget.itemSlotItem(slot)
    local maxStack = widgetItem.parameters.maxStack or root.itemConfig(widgetItem.name).config.maxStack or root.assetJson("/items/defaultParameters.config:defaultMaxStack")
    if item and root.itemDescriptorsMatch(item, widgetItem, true) then
      if not (item.count >= maxStack) then
        widget.setItemSlotItem(slot, { count = widgetItem.count - 1, name = widgetItem.name, parameters = widgetItem.parameters })
        item.count = item.count + 1
        player.setSwapSlotItem(item)
      end
    elseif not item then
      widget.setItemSlotItem(slot, { count = widgetItem.count - 1, name = widgetItem.name, parameters = widgetItem.parameters })
      player.setSwapSlotItem({ count = 1, name = widgetItem.name, parameters = widgetItem.parameters })
    end
    if widget.itemSlotItem(slot).count < 1 then
      widget.setItemSlotItem(slot, nil)
    end
  end
  storedItems[currentPage] = getPageItems()
end

function upgradeLeftClickSlot(slot)
  local item = player.swapSlotItem()
  if not item or item.name == widget.itemSlotItem(slot:gsub("Item", "Display")).name then
    leftClickSlot(slot)    
  end
end

function upgradeRightClickSlot(slot)
  local item = player.swapSlotItem()
  if not item or item.name == widget.itemSlotItem(slot:gsub("Item", "Display")).name then
    rightClickSlot(slot)    
  end
end

function upgrade()  
  changeSettingsPage()
end

-- Adapted from: https://coronalabs.com/blog/2014/09/02/tutorial-printing-table-contents/. Just prints out a table into the starbound.log if you want to snoop out stuff.
function tablePrint(t)
	local tablePrint_cache={}
	local function sub_tablePrint(t,indent)
		if (tablePrint_cache[tostring(t)]) then
			sb.logInfo(indent.."*"..tostring(t))
		else
			tablePrint_cache[tostring(t)]=true
			if (type(t)=="table") then
				for pos,val in pairs(t) do
					if (type(val)=="table") then
						sb.logInfo(indent.."["..pos.."] = "..tostring(t).." {")
						sub_tablePrint(val,indent..string.rep(" ",string.len(pos)+8))
						sb.logInfo(indent..string.rep(" ",string.len(pos)+6).."}")
					elseif (type(val)=="string") then
						sb.logInfo(indent.."["..pos..'] = "'..val..'"')
					else
						sb.logInfo(indent.."["..pos.."] = "..tostring(val))
					end
				end
			else
				sb.logInfo(indent..tostring(t))
			end
		end
	end
	if (type(t)=="table") then
		sb.logInfo(tostring(t).." {")
		sub_tablePrint(t,"  ")
		sb.logInfo("}")
	else
		sub_tablePrint(t,"  ")
	end
end

--https://stackoverflow.com/a/6080274
function isArray(t)
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then return false end
  end
  return true
end

--https://forums.coronalabs.com/topic/27482-copy-not-direct-reference-of-table/
function deepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

function hexConverter(input)
	local hexCharacters = '0123456789abcdef'
	local output = ''
	while input > 0 do
			local mod = math.fmod(input, 16)
			output = string.sub(hexCharacters, mod+1, mod+1) .. output
			input = math.floor(input / 16)
	end
	if output == '' then output = '0' end
  if string.len(output) == 1 then output = "0"..output end
	return output
end