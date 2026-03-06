--[[
脚本名字: GameConfig
脚本文件: GameConfig.lua
脚本类型: ModuleScript
本地路径: D:/RobloxGame/BrainrotsTemplate/GameConfig.lua
Studio放置路径: ReplicatedStorage/Shared/GameConfig
]]

local RunService = game:GetService("RunService")

local GameConfig = {}

GameConfig.VERSION = "V1.2.1"
GameConfig.MAX_SERVER_PLAYERS = 5

GameConfig.HOME = {
    ContainerName = "PlayerHome",
    Prefix = "Home",
    Count = 5,
    HomeBaseName = "HomeBase",
    SpawnLocationName = "SpawnLocation",
}

GameConfig.DATASTORE = {
    StudioName = "Brainrots_PlayerData_STUDIO_V1",
    LiveName = "Brainrots_PlayerData_LIVE_V1",
    EnableInStudio = true,
    AutoSaveInterval = 60,
    MaxRetries = 3,
    RetryDelay = 1.5,
}
GameConfig.DATASTORE.ActiveName = RunService:IsStudio()
    and GameConfig.DATASTORE.StudioName
    or GameConfig.DATASTORE.LiveName

GameConfig.GM = {
    EnabledOnlyInStudio = true,
    AllowAllUsers = true,
    DeveloperUserIds = {
        -- [123456789] = true,
    },
    GroupAdminRankThreshold = 254,
}

GameConfig.BRAINROT = {
    ModelRootFolderName = "Model",
    RuntimeFolderName = "PlacedBrainrots",
    PromptHoldDuration = 1,
    ModelPlacementOffsetY = 0,
    PlatformAttachmentName = "BrainrotAttachment",
    PlatformTriggerName = "Trigger",
    PositionPrefix = "Position",
    ClaimPrefix = "Claim",
    GoldInfoGuiName = "GoldInfo",
    CurrentGoldLabelName = "CurrentGold",
    OfflineGoldLabelName = "OfflineGold",
    OfflineProductionCapSeconds = 3600,
    ClaimTouchDebounceSeconds = 0.35,
}

GameConfig.DEFAULT_PLAYER_DATA = {
    Version = 1,
    Currency = {
        Coins = 0,
    },
    Growth = {
        PowerLevel = 1,
        RebirthLevel = 0,
    },
    HomeState = {
        HomeId = "",
        PlacedBrainrots = {},
        ProductionState = {},
    },
    BrainrotData = {
        NextInstanceId = 1,
        EquippedInstanceId = 0,
        StarterGranted = false,
        Inventory = {},
    },
    Meta = {
        CreatedAt = 0,
        LastLoginAt = 0,
        LastLogoutAt = 0,
        LastSaveAt = 0,
    },
}

return GameConfig
