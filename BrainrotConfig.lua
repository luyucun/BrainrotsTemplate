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
        ModelPath = "Common/Brainrot01",
        CoinPerSecond = 5,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10002,
        Name = "测试脑红02",
        Quality = 2,
        Rarity = 2,
        ModelPath = "Common/Brainrot02",
        CoinPerSecond = 5,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10003,
        Name = "测试脑红03",
        Quality = 3,
        Rarity = 3,
        ModelPath = "Common/Brainrot03",
        CoinPerSecond = 5,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10004,
        Name = "测试脑红04",
        Quality = 4,
        Rarity = 4,
        ModelPath = "Common/Brainrot01",
        CoinPerSecond = 5,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10005,
        Name = "测试脑红05",
        Quality = 5,
        Rarity = 5,
        ModelPath = "Common/Brainrot02",
        CoinPerSecond = 10,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10006,
        Name = "测试脑红06",
        Quality = 6,
        Rarity = 1,
        ModelPath = "Common/Brainrot03",
        CoinPerSecond = 15,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10007,
        Name = "测试脑红07",
        Quality = 7,
        Rarity = 2,
        ModelPath = "Common/Brainrot01",
        CoinPerSecond = 20,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10008,
        Name = "测试脑红08",
        Quality = 8,
        Rarity = 3,
        ModelPath = "Common/Brainrot02",
        CoinPerSecond = 100,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10009,
        Name = "测试脑红09",
        Quality = 9,
        Rarity = 4,
        ModelPath = "Common/Brainrot03",
        CoinPerSecond = 300,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10010,
        Name = "测试脑红10",
        Quality = 9,
        Rarity = 5,
        ModelPath = "Common/Brainrot01",
        CoinPerSecond = 1000,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10011,
        Name = "测试脑红11",
        Quality = 9,
        Rarity = 6,
        ModelPath = "Common/Brainrot02",
        CoinPerSecond = 15000,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
    {
        Id = 10012,
        Name = "测试脑红12",
        Quality = 9,
        Rarity = 7,
        ModelPath = "Common/Brainrot03",
        CoinPerSecond = 600000,
        Icon = "rbxassetid://92295649647469",
        IdleAnimationId = "123010310858935",
    },
}

BrainrotConfig.StarterBrainrotIds = { 10001, 10002, 10003, 10004 }

BrainrotConfig.ById = {}
for _, config in ipairs(BrainrotConfig.Entries) do
    BrainrotConfig.ById[config.Id] = config
end

return BrainrotConfig
