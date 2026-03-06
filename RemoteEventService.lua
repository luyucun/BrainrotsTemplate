--[[
脚本名字: RemoteEventService
脚本文件: RemoteEventService.lua
脚本类型: ModuleScript
本地路径: D:/RobloxGame/BrainrotsTemplate/RemoteEventService.lua
Studio放置路径: ServerScriptService/Services/RemoteEventService
]]

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
        "[RemoteEventService] 缺少共享模块 %s（应放在 ReplicatedStorage/Shared 或 ReplicatedStorage 根目录）",
        moduleName
    ))
end

local RemoteNames = requireSharedModule("RemoteNames")

local RemoteEventService = {}
RemoteEventService._events = {}

local function findOrCreateFolder(parent, folderName)
    local folder = parent:FindFirstChild(folderName)
    if folder and folder:IsA("Folder") then
        return folder
    end

    folder = Instance.new("Folder")
    folder.Name = folderName
    folder.Parent = parent
    return folder
end

local function findOrCreateRemoteEvent(parent, eventName)
    local event = parent:FindFirstChild(eventName)
    if event and event:IsA("RemoteEvent") then
        return event
    end

    event = Instance.new("RemoteEvent")
    event.Name = eventName
    event.Parent = parent
    return event
end

function RemoteEventService:Init()
    local rootFolder = findOrCreateFolder(ReplicatedStorage, RemoteNames.RootFolder)
    local currencyEvents = findOrCreateFolder(rootFolder, RemoteNames.CurrencyEventsFolder)
    local systemEvents = findOrCreateFolder(rootFolder, RemoteNames.SystemEventsFolder)
    local brainrotEvents = findOrCreateFolder(rootFolder, RemoteNames.BrainrotEventsFolder)

    self._events.CoinChanged = findOrCreateRemoteEvent(currencyEvents, RemoteNames.Currency.CoinChanged)
    self._events.RequestCoinSync = findOrCreateRemoteEvent(currencyEvents, RemoteNames.Currency.RequestCoinSync)
    self._events.HomeAssigned = findOrCreateRemoteEvent(systemEvents, RemoteNames.System.HomeAssigned)
    self._events.BrainrotStateSync = findOrCreateRemoteEvent(brainrotEvents, RemoteNames.Brainrot.BrainrotStateSync)
    self._events.RequestBrainrotStateSync = findOrCreateRemoteEvent(brainrotEvents, RemoteNames.Brainrot.RequestBrainrotStateSync)
end

function RemoteEventService:GetEvent(eventKey)
    return self._events[eventKey]
end

return RemoteEventService
