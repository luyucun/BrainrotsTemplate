--[[
脚本名字: MainServer
脚本文件: MainServer.server.lua
脚本类型: Script
本地路径: D:/RobloxGame/BrainrotsTemplate/MainServer.server.lua
Studio放置路径: ServerScriptService/MainServer
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function requireSharedModule(moduleName)
    local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
    if sharedFolder then
        local moduleInShared = sharedFolder:FindFirstChild(moduleName)
        if moduleInShared and moduleInShared:IsA("ModuleScript") then
            return require(moduleInShared)
        end
    end

    local moduleInRoot = ReplicatedStorage:FindFirstChild(moduleName)
    if moduleInRoot and moduleInRoot:IsA("ModuleScript") then
        return require(moduleInRoot)
    end

    error(string.format(
        "[MainServer] 缺少共享模块 %s（应放在 ReplicatedStorage/Shared 或 ReplicatedStorage 根目录）",
        moduleName
    ))
end

local function requireServerModule(moduleName)
    local servicesFolder = script.Parent:FindFirstChild("Services")
    if servicesFolder then
        local moduleInServices = servicesFolder:FindFirstChild(moduleName)
        if moduleInServices and moduleInServices:IsA("ModuleScript") then
            return require(moduleInServices)
        end
    end

    local moduleInRoot = script.Parent:FindFirstChild(moduleName)
    if moduleInRoot and moduleInRoot:IsA("ModuleScript") then
        return require(moduleInRoot)
    end

    error(string.format(
        "[MainServer] 缺少服务模块 %s（应放在 ServerScriptService/Services 或 ServerScriptService 根目录）",
        moduleName
    ))
end

local GameConfig = requireSharedModule("GameConfig")
local RemoteEventService = requireServerModule("RemoteEventService")
local PlayerDataService = requireServerModule("PlayerDataService")
local HomeService = requireServerModule("HomeService")
local CurrencyService = requireServerModule("CurrencyService")
local GMCommandService = requireServerModule("GMCommandService")
local BrainrotService = requireServerModule("BrainrotService")

RemoteEventService:Init()
PlayerDataService:Init()
HomeService:Init()
CurrencyService:Init({
    PlayerDataService = PlayerDataService,
    RemoteEventService = RemoteEventService,
})
GMCommandService:Init({
    CurrencyService = CurrencyService,
    BrainrotService = BrainrotService,
    PlayerDataService = PlayerDataService,
    HomeService = HomeService,
})
BrainrotService:Init({
    PlayerDataService = PlayerDataService,
    HomeService = HomeService,
    CurrencyService = CurrencyService,
    RemoteEventService = RemoteEventService,
})

local function onPlayerAdded(player)
    local assignedHome = HomeService:AssignHome(player)
    if not assignedHome then
        player:Kick("当前服务器家园已满（最多 5 人）")
        return
    end

    PlayerDataService:LoadPlayerData(player)
    PlayerDataService:SetHomeId(player, assignedHome.Name)
    GMCommandService:BindPlayer(player)
    BrainrotService:OnPlayerReady(player, assignedHome)

    local homeAssignedEvent = RemoteEventService:GetEvent("HomeAssigned")
    if homeAssignedEvent then
        homeAssignedEvent:FireClient(player, {
            homeId = assignedHome.Name,
        })
    end

    if player.Character then
        HomeService:TeleportPlayerToHomeSpawn(player)
    end

    CurrencyService:OnPlayerReady(player)

    if #Players:GetPlayers() > GameConfig.MAX_SERVER_PLAYERS then
        warn("[MainServer] 在线人数超过配置上限，请检查游戏服务器最大人数设置")
    end
end

local function onPlayerRemoving(player)
    GMCommandService:UnbindPlayer(player)
    BrainrotService:OnPlayerRemoving(player)
    HomeService:ReleaseHome(player)
    PlayerDataService:OnPlayerRemoving(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
    PlayerDataService:SaveAllPlayers()
end)
