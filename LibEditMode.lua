-- Copyright 2022 plusmouse. Licensed under terms found in LICENSE file.

local lib = LibStub:NewLibrary("LibEditMode-1-0", 1)

local frame = CreateFrame("Frame")

local FRAME_ERROR = "This frame isn't used by edit mode"
local LOAD_ERROR = "You need to call LibEditMode:LoadLayouts first"
local EDIT_ERROR = "Active layout is not editable"

local layoutInfo

local function GetSystemByID(systemID, systemIndex)
  -- Get the system by checking each one for the right system id
  for _, system in pairs(layoutInfo.layouts[layoutInfo.activeLayout].systems) do
    if system.system == systemID and system.systemIndex == systemIndex then
      return system
    end
  end
end

local function GetSystemByFrame(frame)
  assert(frame and type(frame) == "table" and frame.IsObjectType and frame:IsObjectType("Frame"), "Frame required")

  local systemID = frame.system
  local systemIndex = frame.systemIndex

  return GetSystemByID(systemID, systemIndex)
end

local function GetLayoutIndex(layoutName)
  for index, layout in ipairs(layoutInfo.layouts) do
    if layout.layoutName == layoutName then
      return index
    end
  end
end

local function GetHighestIndex()
  local highestLayoutIndexByType = {};
  for index, layoutInfo in ipairs(layoutInfo.layouts) do
    if not highestLayoutIndexByType[layoutInfo.layoutType] or highestLayoutIndexByType[layoutInfo.layoutType] < index then
      highestLayoutIndexByType[layoutInfo.layoutType] = index;
    end
  end
  return highestLayoutIndexByType
end

function lib:SetGlobalSetting(setting, value)
  C_EditMode.SetAccountSetting(setting, value)
end

function lib:HasEditModeSettings(frame)
  return GetSystemByFrame(frame) ~= nil
end

-- Set an option found in the Enum.EditMode enumerations
function lib:SetFrameSetting(frame, setting, value)
  assert(lib:CanEditActiveLayout(), EDIT_ERROR)
  local system = GetSystemByFrame(frame)

  assert(system, FRAME_ERROR)

  for _, item in pairs(system.settings) do
    if item.setting == setting then
      item.value = value
      return true
    end
  end
  return false
end

function lib:ReanchorFrame(frame, ...)
  assert(lib:CanEditActiveLayout(), EDIT_ERROR)
  local system = GetSystemByFrame(frame)

  assert(system, FRAME_ERROR)

  system.isInDefaultPosition = false

  frame:ClearAllPoints()
  frame:SetPoint(...)
  local anchorInfo = system.anchorInfo

  anchorInfo.point, anchorInfo.relativeTo, anchorInfo.relativePoint, anchorInfo.offsetX, anchorInfo.offsetY = frame:GetPoint(1)
  anchorInfo.relativeTo = anchorInfo.relativeTo:GetName()
end

function lib:AreLayoutsLoaded()
  return layoutInfo ~= nil
end

function lib:LoadLayouts()
  layoutInfo = C_EditMode.GetLayouts()
  local tmp = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
  tAppendAll(tmp, layoutInfo.layouts);
  layoutInfo.layouts = tmp
end

function lib:SaveOnly()
  assert(layoutInfo, LOAD_ERROR)
  C_EditMode.SaveLayouts(layoutInfo)
end

function lib:ApplyChanges()
  assert(not InCombatLockdown(), "Cannot move frames in combat")
  lib:SaveOnly()

  ShowUIPanel(EditModeManagerFrame)
  HideUIPanel(EditModeManagerFrame)
end

function lib:DoesLayoutExist(layoutName)
  assert(layoutInfo, LOAD_ERROR)
  return GetLayoutIndex(layoutName) ~= nil
end

function lib:AddLayout(layoutType, layoutName)
  assert(layoutInfo, LOAD_ERROR)
  assert(layoutName and layoutName ~= "", "Non-empty string required")
  assert(not lib:DoesLayoutExist(layoutName), "Layout should not already exist")

  local newLayout = CopyTable(layoutInfo.layouts[1]) -- Modern layout

  newLayout.layoutType = layoutType
  newLayout.layoutName = layoutName

  local highestLayoutIndexByType = GetHighestIndex()

  local newLayoutIndex;
  if highestLayoutIndexByType[layoutType] then
    newLayoutIndex = highestLayoutIndexByType[layoutType] + 1;
  elseif (layoutType == Enum.EditModeLayoutType.Character) and highestLayoutIndexByType[Enum.EditModeLayoutType.Account] then
    newLayoutIndex = highestLayoutIndexByType[Enum.EditModeLayoutType.Account] + 1;
  else
    newLayoutIndex = Enum.EditModePresetLayoutsMeta.NumValues + 1;
  end

  table.insert(layoutInfo.layouts, newLayoutIndex, newLayout)
  C_EditMode.OnLayoutAdded(newLayoutIndex)
  C_EditMode.SetActiveLayout(newLayoutIndex)
end

function lib:DeleteLayout(layoutName)
  assert(layoutInfo, LOAD_ERROR)
  local index = GetLayoutIndex(layoutName)
  assert(index ~= nil, "Can't delete layout as it doesn't exist")

  assert(layoutInfo.layouts[index].layoutType ~= Enum.EditModeLayoutType.Preset, "Cannot delete preset layouts")

  table.remove(layoutInfo.layouts, index)
  C_EditMode.OnLayoutDeleted(index)
end

function lib:GetEditableLayoutNames()
  assert(layoutInfo, LOAD_ERROR)
  local names = {}
  for _, layout in ipairs(layoutInfo.layouts) do
    if layout.layoutType ~= Enum.EditModeLayoutType.Preset then
      table.insert(names, layout.layoutName)
    end
  end

  return names
end

function lib:GetPresetLayoutNames()
  assert(layoutInfo, LOAD_ERROR)
  local names = {}
  for _, layout in ipairs(layoutInfo.layouts) do
    if layout.layoutType == Enum.EditModeLayoutType.Preset then
      table.insert(names, layout.layoutName)
    end
  end

  return names
end

function lib:CanEditActiveLayout()
  assert(layoutInfo, LOAD_ERROR)
  return layoutInfo.layouts[layoutInfo.activeLayout].layoutType ~= Enum.EditModeLayoutType.Preset
end

function lib:SetActiveLayout(layoutName)
  assert(layoutInfo, LOAD_ERROR)
  assert(lib:DoesLayoutExist(layoutName), "Layout must exist")

  local index = GetLayoutIndex(layoutName)

  layoutInfo.activeLayout = index
  C_EditMode.SetActiveLayout(index)
end

function lib:GetActiveLayout()
  assert(layoutInfo, LOAD_ERROR)
  return layoutInfo.layouts[layoutInfo.activeLayout].layoutName
end
