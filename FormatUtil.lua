--[[
脚本名字: FormatUtil
脚本文件: FormatUtil.lua
脚本类型: ModuleScript
本地路径: D:/RobloxGame/BrainrotsTemplate/FormatUtil.lua
Studio放置路径: ReplicatedStorage/Shared/FormatUtil
]]

local FormatUtil = {}

function FormatUtil.FormatWithCommas(value)
    local numericValue = tonumber(value) or 0
    local sign = numericValue < 0 and "-" or ""
    local absoluteValue = math.floor(math.abs(numericValue))

    local raw = tostring(absoluteValue)
    local formatted = raw:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if formatted:sub(1, 1) == "," then
        formatted = formatted:sub(2)
    end

    return sign .. formatted
end

return FormatUtil
