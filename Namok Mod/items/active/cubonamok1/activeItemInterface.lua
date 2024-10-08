--[[
  Item Interfaces script for Active Items.
  This script will check if the active item has the parameter "itemInterface".
  If so, the callbacks of this script are used rather than the default script.
  The item will then open the interface from the path of the "itemInterface" parameter when activated.

  Note that this file should be required in the init function of a vanilla active item script to prevent issues on servers.
  The first lines in function init():
  require "/items/active/fossil/activeItemInterface.lua"
  if itemInterface then return end
]]

local version = "1.3.2"
local logError = function(msg, ...)
  sb.logError("ItemInterfaces %s: " .. msg, version, ...)
end

-- Defaults
local default = {
  type = "ScriptPane",
  holding = true
}

-- Read root / table parameters
local interfaceConfig = config.getParameter("itemInterface")
local interfacePath, interfaceType, interfaceHolding, interfaceRequiresShift, interfacePrimary, interfaceAlt

if type(interfaceConfig) == "string" then
  interfacePath = interfaceConfig
  interfaceType = config.getParameter("itemInterfaceType")
  interfaceHolding = config.getParameter("itemInterfaceHolding")
  interfaceRequiresShift = config.getParameter("itemInterfaceShiftHeld")
  interfacePrimary = config.getParameter("itemInterfacePrimary")
  interfaceAlt = config.getParameter("itemInterfaceAlt")
elseif type(interfaceConfig) == "table" then
  interfacePath = interfaceConfig.path
  interfaceType = interfaceConfig.type
  interfaceHolding = interfaceConfig.holding
  interfaceRequiresShift = interfaceConfig.shift
  interfacePrimary = interfaceConfig.primary
  interfaceAlt = interfaceConfig.alt

  if not interfacePath then
    logError("Could not load an item interface as no 'path' is defined. This item will behave as a regular fossil brush.")
  end
end

-- Defaults
if type(interfaceType) ~= "string" then interfaceType = default.type end
if type(interfaceHolding) ~= "boolean" then interfaceHolding = default.holding end

-- Show or hide item.
if type(interfaceHolding) == "boolean" then
  activeItem.setHoldingItem(interfaceHolding)
end

-- Determine primary / alt fire requirement.
if interfacePrimary == nil and interfaceAlt == nil then -- None -> Both
  interfacePrimary, interfaceAlt = true, true
elseif interfaceAlt == nil then -- Primary false -> Alt true. Primary true -> Alt false.
  interfaceAlt = not interfacePrimary
elseif interfacePrimary == nil then -- Alt false -> Primary true. Alt true -> Primary false.
  interfacePrimary = not interfaceAlt
elseif not interfacePrimary and not interfaceAlt then -- Both false -> Error.
  logError("Primary and Alt are both set to false. This item interface can not be opened.")
end

--[[
  Check if this item is a valid Item Interfaces active item.
]]
if not interfacePath then
  -- Not valid; prevent this script from initializing (before itemInterface is defined).
  return
else
  -- Check if the file exists.
  if not pcall(function() root.assetJson(interfacePath) end) then
    logError("Could not load the interface '%s'. This item will behave as a regular fossil brush.", interfacePath)
    return
  end
end

--[[
  Item Interface table. Callbacks are stored here.
  You can use this table to store variables and functions, but feel free to define your own tables and variables.
]]
itemInterface = { }

--[[
  Activation callback. Called when activating the item, regardless of the button used.
  This item descriptor is added to the configuration's gui, which allows both
  scripts for ScriptPanes and ScriptConsoles to fetch the data.
  @param fireMode - "primary" or "alt, indicating which mouse button is held down.
]]
function itemInterface.activate(fireMode, shiftHeld)
  -- Does shiftHeld match 'itemInterfaceShiftHeld'? Only matters if the parameter is defined on the item.
  if interfaceRequiresShift ~= nil and interfaceRequiresShift ~= shiftHeld then return end

  if fireMode == "primary" and not interfacePrimary then return end
  if fireMode == "alt" and not interfaceAlt then return end

  local interfaceConfig = root.assetJson(interfacePath)

  -- Add the item descriptor to the GUI configuration, so that it can be accessed from the interface.
  if not interfaceConfig.gui then interfaceConfig.gui = {} end
  interfaceConfig.gui.activatedItem = {
    type = "label",
    visible = false,
    data = item.descriptor()
  }

  -- Open the interface.
  activeItem.interact(interfaceType, interfaceConfig)
  sb.logInfo("ItemInterfaces v%s opened an interface.", version)
end

-- Code that makes the active item use the callbacks from this script rather than the original fossil brush callbacks.
activate = itemInterface.activate
init = function() end
update = function(args) end
uninit = function() end

-- Because Starbound doesn't support return values when requiring scripts, the existance of the "itemInterface" table should be checked.
-- The table is not defined if the item is not a valid ItemInterfaces item.
