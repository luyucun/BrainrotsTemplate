--[[
脚本名字: FormatUtil
脚本文件: FormatUtil.lua
脚本类型: ModuleScript
本地路径: D:/RobloxGame/BrainrotsTemplate/FormatUtil.lua
Studio放置路径: ReplicatedStorage/Shared/FormatUtil
]]

local FormatUtil = {}

local COMPACT_NUMBER_UNITS = {
    { Value = 1e30, Suffix = "No" },
    { Value = 1e27, Suffix = "Oc" },
    { Value = 1e24, Suffix = "Sp" },
    { Value = 1e21, Suffix = "Sx" },
    { Value = 1e18, Suffix = "Qi" },
    { Value = 1e15, Suffix = "Qa" },
    { Value = 1e12, Suffix = "T" },
    { Value = 1e9, Suffix = "B" },
    { Value = 1e6, Suffix = "M" },
    { Value = 1e3, Suffix = "K" },
}

local function trimTrailingZeros(numberText)
    local trimmed = string.gsub(numberText, "(%..-)0+$", "%1")
    trimmed = string.gsub(trimmed, "%.$", "")
    return trimmed
end

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

function FormatUtil.FormatCompactNumber(value)
    local numericValue = math.max(0, tonumber(value) or 0)
    if numericValue < 1000 then
        if math.abs(numericValue - math.floor(numericValue)) < 0.001 then
            return tostring(math.floor(numericValue))
        end

        local formatString = numericValue >= 100 and "%.0f" or (numericValue >= 10 and "%.1f" or "%.2f")
        return trimTrailingZeros(string.format(formatString, numericValue))
    end

    for _, unit in ipairs(COMPACT_NUMBER_UNITS) do
        if numericValue >= unit.Value then
            local scaled = numericValue / unit.Value
            local decimals = 2
            if scaled >= 100 then
                decimals = 0
            elseif scaled >= 10 then
                decimals = 1
            end

            local formatString = string.format("%%.%df", decimals)
            return trimTrailingZeros(string.format(formatString, scaled)) .. unit.Suffix
        end
    end

    return tostring(math.floor(numericValue))
end

function FormatUtil.FormatCompactCurrency(value)
    return "$" .. FormatUtil.FormatCompactNumber(value)
end

function FormatUtil.FormatCompactCurrencyPerSecond(value)
    return FormatUtil.FormatCompactCurrency(value) .. "/S"
end

function FormatUtil.FormatDurationDaysHoursMinutes(totalSeconds)
    local clampedSeconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
    local totalMinutes = math.floor(clampedSeconds / 60)
    local days = math.floor(totalMinutes / (24 * 60))
    local hours = math.floor((totalMinutes % (24 * 60)) / 60)
    local minutes = totalMinutes % 60
    return string.format("%02d:%02d:%02d", days, hours, minutes)
end

return FormatUtil
