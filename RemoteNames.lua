--[[
脚本名字: RemoteNames
脚本文件: RemoteNames.lua
脚本类型: ModuleScript
本地路径: D:/RobloxGame/BrainrotsTemplate/RemoteNames.lua
Studio放置路径: ReplicatedStorage/Shared/RemoteNames
]]

local RemoteNames = {
    RootFolder = "Events",
    CurrencyEventsFolder = "CurrencyEvents",
    SystemEventsFolder = "SystemEvents",
    BrainrotEventsFolder = "BrainrotEvents",
    Currency = {
        CoinChanged = "CoinChanged",
        RequestCoinSync = "RequestCoinSync",
    },
    System = {
        HomeAssigned = "HomeAssigned",
        LikeTip = "LikeTip",
        SocialStateSync = "SocialStateSync",
        RequestSocialStateSync = "RequestSocialStateSync",
        FriendBonusSync = "FriendBonusSync",
        RequestFriendBonusSync = "RequestFriendBonusSync",
        RequestQuickTeleport = "RequestQuickTeleport",
        ClaimCashFeedback = "ClaimCashFeedback",
    },
    Brainrot = {
        BrainrotStateSync = "BrainrotStateSync",
        RequestBrainrotStateSync = "RequestBrainrotStateSync",
    },
}

return RemoteNames
