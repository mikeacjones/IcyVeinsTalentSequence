local _, ts = ...

local strlen = strlen
local strsub = strsub
local strfind = strfind
local strlower = strlower
local tinsert = tinsert
local UnitClass = UnitClass

local talentIndices =
    "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-._~[]()%EF%BD%A6%EF%BD%A7%EF%BD%A8%EF%BD%A9%EF%BD%AA%EF%BD%AB%EF%BD%AC%EF%BD%AD%EF%BD%AE%EF%BD%AF%EF%BD%B0%EF%BD%B1%EF%BD%B2%EF%BD%B3%EF%BD%B4%EF%BD%B5"

ts.IcyVeinsTalents = {}

local function findLast(haystack, needle)
    local i = haystack:match(".*" .. needle .. "()")
    if i == nil then
        return nil
    else
        return i - 1
    end
end

local hex_to_char = function(x)
    return string.char(tonumber(x, 16))
end

local unescape = function(url)
    return url:gsub("%%(%x%x)", hex_to_char)
end

local splitTalentString = function(str)
  parts = {}
  local i = 1
  while i <= strlen(str) do
    local char = strsub(str, i, i)
    if (char == "%") then
      char = strsub(str, i, i+8)
      i = i + 9
    else
      i = i + 1
    end
    table.insert(parts, char)
  end
  return parts
end

function ts.IcyVeinsTalents.GetTalents(talentString, talentDict)
    talentMapParts = splitTalentString(talentIndices)
    talentMap = {}
    for i = 1, #talentMapParts, 1 do
      talentMap[talentMapParts[i]] = i
    end


    local flatTalentDict = {}
    for i, v in ipairs(talentDict) do
        for j, t in ipairs(talentDict[i]) do
            table.insert(flatTalentDict, t)
        end
    end

    local startPosition = findLast(talentString, "#tc-")
    if (startPosition) then
        talentString = strsub(talentString, startPosition + 3)
    end
    startPosition = findLast(talentString, "|")
    if (startPosition) then
      talentString = strsub(talentString, 1, startPosition - 2)
    end

    talentStringKeys = splitTalentString(talentString)

    local level = 9
    local talents = {}
    local talentCounter = {}
    local i = 1
    for i = 1, #talentStringKeys, 1 do
        local talentKey = talentStringKeys[i]
        local talentIndex = talentMap[talentKey]
        if talentIndex then
            local talent = flatTalentDict[talentIndex]
            level = level + 1
            if (level > 10 and level % 2 == 0 and level < 81) then
                level = level + 1
            end
            if (talentCounter[talentKey] == nil) then
                talentCounter[talentKey] = 1
            else
                talentCounter[talentKey] = talentCounter[talentKey] + 1
            end
            tinsert(talents, {
                tab = talent.tab,
                id = v,
                level = level,
                index = talent.index,
                rank = talentCounter[talentKey]
            })
        end
    end
    return talents
end