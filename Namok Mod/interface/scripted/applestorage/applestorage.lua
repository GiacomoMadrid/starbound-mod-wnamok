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

  if not backpackSettings.locked then
    backpackSettings, storedItems = versioning(backpackSettings, storedItems)
    toggleBag(true, 1)
  else
    unlockScreen()
  end

  local imagePath = "/interface/scripted/applestorage/"
  for _,v in pairs({"Header", "Body", "Footer"}) do
    widget.setImage("file"..v, imagePath..string.lower(v)..".png".."?multiply="..
      hexConverter(backpackSettings.colour.red)..
      hexConverter(backpackSettings.colour.green)..
      hexConverter(backpackSettings.colour.blue)
    )
  end
  widget.setImage("iconBase", "/assetMissing.png?scale=1?crop=0;0;16;16"..root.assetJson("/interface/scripted/applestorage/backpackIcons.config").base)
  widget.setImage("iconOverlay", "/assetMissing.png?scale=1?crop=0;0;16;16"..root.assetJson("/interface/scripted/applestorage/backpackIcons.config").overlay..";?multiply="..
    hexConverter(backpackSettings.colour.red)..
    hexConverter(backpackSettings.colour.green)..
    hexConverter(backpackSettings.colour.blue)
  )
  widget.setText("title", backpackSettings.title)
  widget.setText("subtitle", backpackSettings.subtitle)
  widget.setButtonEnabled("upgradeButton", false)
  updateUpgradeCounters()
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
  updateUpgradeCounters()
end

function unlockScreen()
  toggleBag(false)
  widget.setText("context", "PASSWORD REQUIRED")
  widget.setVisible("tabs", false)
  widget.setVisible("tabHide", true)
  widget.setVisible("passwordInput", true)
  widget.setVisible("passwordInput_label", true)
  widget.setVisible("passwordInput_image", true)
  widget.setVisible("unlock", true)
end

function unlock()
  if widget.getText("passwordInput") ~= "" then
    local password = bin.stohex(sha3.hash256(widget.getText("passwordInput")))
    local decryptedStoredItems = norx.aead_decrypt(password, password, string.char(table.unpack(storedItems)))
    if decryptedStoredItems then
      storedItems = json.decode(decryptedStoredItems)

      backpackSettings, storedItems = versioning(backpackSettings, storedItems)

      widget.setVisible("tabs", true)
      widget.setVisible("tabHide", false)
      widget.setVisible("passwordInput", false)
      widget.setVisible("passwordInput_label", false)
      widget.setVisible("passwordInput_image", false)
      widget.setVisible("unlock", false)

      widget.setText("editPassword", widget.getText("passwordInput"))

      toggleBag(true, 1)
    end
  end
end

function changeTab()
  local tab = widget.getSelectedData("tabs")
  if
  tab == "bag" then
    toggleBag(true, currentPage)
    toggleLock(false)
    toggleSettings(false)
  elseif
  tab == "lock" then
    toggleBag(false)
    toggleLock(true)
    toggleSettings(false)
  elseif
  tab == "settings" then
    toggleBag(false)
    toggleLock(false)
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

  for row = 1, 5 do
    for column = 1, 5 do
      local pos = row.."_"..column
      widget.setItemSlotItem("itemSlot_"..pos, nil)
    end
  end

  toggleBag(true, storedItems[currentPage])
end

function changeSettingsPage(button)
  local appearanceItems = {
    "editTitle",      "editTitle_image",
    "editSubtitle",   "editSubtitle_image",
    "editRedText",    "editRedText_image",
    "editGreenText",  "editGreenText_image",
    "editBlueText",   "editBlueText_image",
    "editRed",        "editRed_image",      "editRed_image_end",
    "editGreen",      "editGreen_image",    "editGreen_image_end",
    "editBlue",       "editBlue_image",     "editBlue_image_end"
  }

  local upgradeItems = {
    "upgradeItemSlot_1",
    "upgradeItemSlot_2",
    "upgradeItemSlot_3",
    "upgradeDisplaySlot_1",
    "upgradeDisplaySlot_2",
    "upgradeDisplaySlot_3",
    "upgradeText_1",
    "upgradeText_2",
    "upgradeText_3",
    "upgradeButton"
  }

  if button == "settingsPageLeft" then
    if settingsPage > 1 then
      settingsPage = settingsPage - 1
    end
  elseif button == "settingsPageRight" then
    if settingsPage < 2 then
      settingsPage = settingsPage + 1
    end
  end

  if settingsPage == 1 then
    widget.setText("contextLabel", "APPEARANCE")
    for _,v in ipairs(appearanceItems) do
      widget.setVisible(v, true)
    end
    for _,v in ipairs(upgradeItems) do
      widget.setVisible(v, false)
    end
  elseif settingsPage == 2 then
    widget.setText("contextLabel", "ADD SLOTS"..(#storedItems > 2 and "\n^#b9b5b2;(FULLY UPGRADED)" or ""))
    for _,v in ipairs(appearanceItems) do
      widget.setVisible(v, false)
    end
    for _,v in ipairs(upgradeItems) do
      widget.setVisible(v, true)
    end
    for _,v in ipairs({1,2,3}) do
      local upgradeItems = {{"cottonwool", "leather", "titaniumbar"}, {"silk", "canvas", "durasteelbar"}}
      if #storedItems < 3 then
        widget.setItemSlotItem("upgradeDisplaySlot_"..v, {name = upgradeItems[#storedItems][v], count = 1, parameters = {}})
      else
        widget.setButtonEnabled("upgradeButton", false)
        widget.setVisible("upgradeDisplaySlot_"..v, false)
        widget.setVisible("upgradeText_"..v, false)
      end
    end
  end

  widget.setText("settingsPage", settingsPage.." / 2")
end

function toggleBag(visible, page)
  widget.setText("page", currentPage.." / "..(#storedItems or 1))

  if visible then
    widget.setText("context", "^#b9b5b2;"..(#storedItems * 25).." SLOTS")
    setPageItems(currentPage)
  end
  for row = 1, 5 do
    for column = 1, 5 do
      local pos = row.."_"..column
      widget.setVisible("itemSlot_"..pos, visible)
    end
  end

  for _,v in pairs({"page", "pageLeft", "pageRight"}) do
    widget.setVisible(v, visible and #storedItems > 1)
  end
end

function toggleLock(visible)
  if visible then
    widget.setText("context", "^#b9b5b2;BAG LOCK")
  end
  for _,v in pairs({"", "_label", "_image"}) do
    widget.setVisible("editPassword"..v, visible)
  end
  widget.setVisible("passwordHint", visible)
  widget.setVisible("passwordWarningTitle", visible)
  widget.setVisible("passwordWarningText", visible)
end

function toggleSettings(visible)
  settingsPage = 1
  widget.setText("settingsPage", settingsPage.." / 2")

  if visible then
    widget.setText("context", "^#b9b5b2;SETTINGS")
    widget.setText("editTitle", backpackSettings.title)
    widget.setText("editSubtitle", backpackSettings.subtitle)
  else
    for _,v in pairs({"ItemSlot_1", "ItemSlot_2", "ItemSlot_3", "DisplaySlot_1", "DisplaySlot_2", "DisplaySlot_3", "Text_1", "Text_2", "Text_3", "Button"}) do
      widget.setVisible("upgrade"..v, visible)
    end
  end

  for _,v in pairs({"Page", "PageLeft", "PageRight"}) do
    widget.setVisible("settings"..v, visible)
  end

  widget.setVisible("contextLabel", visible)
  widget.setText("contextLabel", "APPEARANCE")

  for _,v in pairs({"Title", "Subtitle", "Colour"}) do
    for _,v2 in pairs({"", "_label", "_image"}) do
      widget.setVisible("edit"..v..v2, visible)
    end
  end

  for _,v in pairs({"Red", "Green", "Blue"}) do
    widget.setVisible("edit"..v, visible)
    widget.setVisible("edit"..v.."_image", visible)
    widget.setVisible("edit"..v.."_image_end", visible)
    widget.setSliderEnabled("edit"..v, visible)
    widget.setSliderRange("edit"..v, 0, 255, 1)
    widget.setSliderValue("edit"..v, backpackSettings.colour[string.lower(v)])

    widget.setVisible("edit"..v.."Text", visible)
    widget.setVisible("edit"..v.."Text_image", visible)
    widget.setText("edit"..v.."Text", backpackSettings.colour[string.lower(v)])
  end
end

function editTitle()
  backpackSettings.title = widget.getText("editTitle")
  widget.setText("title", backpackSettings.title)
end

function editSubtitle()
  backpackSettings.subtitle = widget.getText("editSubtitle")
  widget.setText("subtitle", backpackSettings.subtitle)
end

function editRed()
  local value = widget.getSliderValue("editRed")
  backpackSettings.colour.red = value
  if not (value == 0 and widget.getText("editRedText") == "") then
    widget.setText("editRedText", value)
  end
  editLayout()
end

function editRedText()
  local value = widget.getText("editRedText")
  value = tonumber(value)
  if value == nil then value = 0 end
  if value > 255 then value = 255 widget.setText("editRedText", value) end
  backpackSettings.colour.red = value
  widget.setSliderValue("editRed", value)
  editLayout()
end

function editGreen()
  local value = widget.getSliderValue("editGreen")
  backpackSettings.colour.green = value
  if not (value == 0 and widget.getText("editGreenText") == "") then
    widget.setText("editGreenText", value)
  end
  editLayout()
end

function editGreenText()
  local value = widget.getText("editGreenText")
  value = tonumber(value)
  if value == nil then value = 0 end
  if value > 255 then value = 255 widget.setText("editGreenText", value) end
  backpackSettings.colour.green = value
  widget.setSliderValue("editGreen", value)
  editLayout()
end

function editBlue()
  local value = widget.getSliderValue("editBlue")
  backpackSettings.colour.blue = value
  if not (value == 0 and widget.getText("editBlueText") == "") then
    widget.setText("editBlueText", value)
  end
  editLayout()
end

function editBlueText()
  local value = widget.getText("editBlueText")
  value = tonumber(value)
  if value == nil then value = 255 end
  if value > 255 then value = 255 widget.setText("editBlueText", value) end
  backpackSettings.colour.blue = value
  widget.setSliderValue("editBlue", value)
  editLayout()
end

function editLayout()
  local imagePath = "/interface/scripted/applestorage/"
  for _,v in pairs({"Header", "Body", "Footer"}) do
    widget.setImage("file"..v, imagePath..string.lower(v)..".png?multiply="..
      hexConverter(backpackSettings.colour.red)..
      hexConverter(backpackSettings.colour.green)..
      hexConverter(backpackSettings.colour.blue)
    )
  end
  widget.setImage("iconOverlay", "/assetMissing.png?scale=1?crop=0;0;16;16"..root.assetJson("/interface/scripted/applestorage/backpackIcons.config").overlay..";?multiply="..
    hexConverter(backpackSettings.colour.red)..
    hexConverter(backpackSettings.colour.green)..
    hexConverter(backpackSettings.colour.blue)
  )
end

function editPassword()
  if widget.getText("editPassword") == "" then
    backpackSettings.locked = false
  else
    backpackSettings.locked = true
  end
end

function uninit()
  if type(storedItems[1]) ~= "number" then
    storedItems[currentPage] = getPageItems()
    price = 150
    for _,page in ipairs(storedItems) do
      for _,v in ipairs(page) do
        if type(v) == "table" and v.parameters and (v.parameters.price or root.itemConfig(v.name).config.price) then
          price = price + (v.count * (v.parameters.price or root.itemConfig(v.name).config.price))
        end
      end
    end

    if backpackSettings.locked then
      local password = bin.stohex(sha3.hash256(widget.getText("editPassword")))
      local str = norx.aead_encrypt(password, password, sb.printJson(storedItems))
      storedItems = {}
      str:gsub(".",function(c) table.insert(storedItems,string.byte(c)) end)
      tablePrint(storedItems)
    end
  end

  local item = root.assetJson("/recipes/applestorage/applestorage.recipe:output")
  item.parameters.price = price
  item.parameters.storedItems = storedItems
  item.parameters.backpackSettings = backpackSettings
  item.parameters.shortdescription = backpackSettings.title
  item.parameters.category = backpackSettings.subtitle.."^reset;"
  item.parameters.tooltipFields.lockLabel = (backpackSettings.locked and "^red;LOCKED^reset;" or "^green;UNLOCKED^reset;")
  item.parameters.tooltipFields.lockImage = (backpackSettings.locked and "/interface/lockicon.png?replace;1e1e1e=000000;686868=777777;595959=5b5b5b;7f6e27=806613;907c2d=be9e1d;2c2c2a=171717;262626=171717ff" or "")
  item.parameters.inventoryIcon = {{
    image = "/assetMissing.png?scale=1?crop=0;0;16;16"..root.assetJson("/interface/scripted/applestorage/backpackIcons.config:base"),
    position = {0,0}
  }, {
    image = "/assetMissing.png?scale=1?crop=0;0;16;16"..root.assetJson("/interface/scripted/applestorage/backpackIcons.config:overlay")..";?multiply="..
      hexConverter(backpackSettings.colour.red)..
      hexConverter(backpackSettings.colour.green)..
      hexConverter(backpackSettings.colour.blue),
    position = {0,0}
  }}
  player.giveItem(item)

  for _,v in ipairs({1,2,3}) do
    player.giveItem(widget.itemSlotItem("upgradeItemSlot_"..v))
  end
end

function setPageItems(page)
  local pageItems = storedItems[page]
  if pageItems then
    for row = 1, 5 do
      for column = 1, 5 do
        local pos = row.."_"..column
        widget.setItemSlotItem("itemSlot_"..pos, pageItems["itemSlot_"..pos])
      end
    end
  end
end

function getPageItems()
  local pageItems = {}
  for row = 1, 5 do
    for column = 1, 5 do
      local pos = row.."_"..column
      pageItems["itemSlot_"..pos] = widget.itemSlotItem("itemSlot_"..pos)
    end
  end
  return pageItems
end

function leftClickSlot(slot)
  if player.swapSlotItem() then
    if not player.swapSlotItem().parameters.backpackSettings then
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
    updateUpgradeCounters()
  end
end

function upgradeRightClickSlot(slot)
  local item = player.swapSlotItem()
  if not item or item.name == widget.itemSlotItem(slot:gsub("Item", "Display")).name then
    rightClickSlot(slot)
    updateUpgradeCounters()
  end
end

function updateUpgradeCounters()
  local upgradeAmount = {5, 10, 15}
  local upgradeItems = {{"cottonwool", "leather", "titaniumbar"}, {"silk", "canvas", "durasteelbar"}}
  local upgradeAvailable = true
  if #storedItems < 3 then
    for _,v in ipairs({1,2,3}) do
      local widgetItem = widget.itemSlotItem("upgradeItemSlot_"..v)
      if widgetItem and widgetItem.name ~= upgradeItems[#storedItems][v] then
        player.giveItem(widgetItem)
        widget.setItemSlotItem("upgradeItemSlot_"..v, nil)
        widgetItem = nil
      end
      if widgetItem then
        if widgetItem.count < upgradeAmount[v] then
          upgradeAvailable = false
        end
        widget.setText("upgradeText_"..v, widgetItem.count < upgradeAmount[v] and "^red;"..upgradeAmount[v] or "^green;"..upgradeAmount[v])
      else
        widget.setText("upgradeText_"..v, "^red;"..upgradeAmount[v])
        upgradeAvailable = false
      end
      if player.isAdmin() then upgradeAvailable = true end
    end
  else
    upgradeAvailable = false
  end
  widget.setButtonEnabled("upgradeButton", upgradeAvailable)
end

function upgrade()
  local upgradeAmount = {5, 10, 15}
  local upgradeAvailable = true
  for _,v in ipairs({1,2,3}) do
    local widgetItem = widget.itemSlotItem("upgradeItemSlot_"..v)
    if (not widgetItem or widgetItem.count < upgradeAmount[v]) and not player.isAdmin() then
      upgradeAvailable = false
      break
    end
  end
  if upgradeAvailable then
    for _,v in ipairs({1,2,3}) do
      if not player.isAdmin() then
        local widgetItem = widget.itemSlotItem("upgradeItemSlot_"..v)
        widgetItem.count = widgetItem.count - upgradeAmount[v]
        player.giveItem(widgetItem)
      end
      widget.setItemSlotItem("upgradeItemSlot_"..v, nil)
    end
    widget.playSound("/sfx/tech/tech_walljump.ogg")
    table.insert(storedItems, {})
  end
  updateUpgradeCounters()
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
