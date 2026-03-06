--[[
脚本名字: BrainrotConfig
脚本文件: BrainrotConfig.lua
脚本类型: ModuleScript
本地路径: D:/RobloxGame/BrainrotsTemplate/BrainrotConfig.lua
Studio放置路径: ReplicatedStorage/Shared/BrainrotConfig
]]

local BrainrotConfig = {}

BrainrotConfig.QualityNames = {
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Mythic",
    [7] = "Secret",
    [8] = "God",
    [9] = "OG",
}

BrainrotConfig.RarityNames = {
    [1] = "Normal",
    [2] = "Gold",
    [3] = "Diamond",
    [4] = "Lava",
    [5] = "Galaxy",
    [6] = "Hacker",
    [7] = "Rainbow",
}

BrainrotConfig.Entries = {
    {
        Id = 10001,
        Name = "测试脑红01",
        Quality = 1,
        Rarity = 1,
        ModelPath = "Common/67",
        CoinPerSecond = 5,
        Icon = "rbxassetid://92295649647469",
    },
    {
        Id = 10002,
        Name = "测试脑红02",
        Quality = 2,
        Rarity = 1,
        ModelPath = "Common/67",
        CoinPerSecond = 5,
        Icon = "rbxassetid://92295649647469",
    },
    {
        Id = 10003,
        Name = "测试脑红03",
        Quality = 3,
        Rarity = 1,
        ModelPath = "Common/67",
        CoinPerSecond = 5,
        Icon = "rbxassetid://92295649647469",
    },
    {
        Id = 10004,
        Name = "测试脑红04",
        Quality = 4,
        Rarity = 1,
        ModelPath = "Common/67",
        CoinPerSecond = 5,
        Icon = "rbxassetid://92295649647469",
    },
}

BrainrotConfig.StarterBrainrotIds = { 10001, 10002, 10003, 10004 }

BrainrotConfig.ById = {}
for _, config in ipairs(BrainrotConfig.Entries) do
    BrainrotConfig.ById[config.Id] = config
end

return BrainrotConfig
