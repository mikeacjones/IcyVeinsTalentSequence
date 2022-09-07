local _, ts = ...

local strlen = strlen
local strsub = strsub
local strfind = strfind
local strlower = strlower
local tinsert = tinsert
local UnitClass = UnitClass
local GetTalentInfo = GetTalentInfo

local talentIndices = "abcdefghjkmnpqrstvwzxyilou468-~"
local maxTalentIndices = "ABCDEFGHJKMNPQRSTVWZXYILOU579_"

ts.WowheadTalents = {}

local function findLast(haystack, needle)
    local i=haystack:match(".*"..needle.."()")
    if i==nil then return nil else return i-1 end
end

function ts.WowheadTalents.GetTalents(talentString, talentDict)
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
        if (encodedId == "0" or encodedId == "1" or encodedId == "2") then
            currentTab = encodedId
        else
            local talentIndex = strfind(talentIndices,encodedId)
            local maxTalentIndex = strfind(maxTalentIndices,encodedId)
            if talentIndex == nil then
                local talent = talentDict[currentTab+1][maxTalentIndex]
                for j = 1, talent.maxRank, 1 do
                    level = level + 1
                    tinsert(talents,
                    {
                        tab = talent.tab,
                        id = encodedId,
                        level = level,
                        index = talent.index,
                        rank = j
                    })
                end
            else
                local talent = talentDict[currentTab+1][talentIndex]
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
                    index = talent.index,
                    rank = talentCounter[encodedId]
                })
            end
        end
    end
    return talents
end