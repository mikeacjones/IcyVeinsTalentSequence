local _, ts = ...

local strlen = strlen
local strsub = strsub
local strfind = strfind
local strlower = strlower
local tinsert = tinsert
local UnitClass = UnitClass
local GetTalentInfo = GetTalentInfo

local characterIndices = "abcdefghijklmnopqrstuvwxyz"

ts.WowheadTalents = {}

local function findLast(haystack, needle)
    local i=haystack:match(".*"..needle.."()")
    if i==nil then return nil else return i-1 end
end

function ts.WowheadTalents.GetTalents(talentString)
    local startPosition = findLast(talentString, "/")
    if (startPosition) then
        talentString = strsub(talentString,startPosition+1)
    end

    local currentTab = 0
    local talentStringLength = strlen(talentString)
    local level = 9
    local talents = {}
    local talentCounter = {}
    for i = 1, talentStringLength, 1 do
        local encodedId = strsub(talentString, i, i)
        if (strbyte(encodedId) <= 50) then
            currentTab = encodedId
        else
            local talentIndex = strfind(characterIndices,strlower(encodedId))
            --wow head says to max out the talent if its in caps
            if (strbyte(encodedId) < 97) then
                local name, icon, _, _, currentRank, maxRank = GetTalentInfo(currentTab + 1, talentIndex)
                for j = 1, maxRank, 1 do
                    level = level + 1
                    tinsert(talents,
                    {
                        tab = currentTab + 1,
                        id = encodedId,
                        level = level,
                        index = talentIndex,
                        rank = j
                    })
                end
            else
                level = level + 1
                if (talentCounter[encodedId] == nil) then
                    talentCounter[encodedId] = 1
                else
                    talentCounter[encodedId] = talentCounter[encodedId] + 1
                end
                tinsert(talents,
                {
                    tab = currentTab + 1,
                    id = encodedId,
                    level = level,
                    index = talentIndex,
                    rank = talentCounter[encodedId]
                })
            end
        end
    end
    return talents
end