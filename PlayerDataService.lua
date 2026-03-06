--[[
脚本名字: PlayerDataService
脚本文件: PlayerDataService.lua
脚本类型: ModuleScript
本地路径: D:/RobloxGame/BrainrotsTemplate/PlayerDataService.lua
Studio放置路径: ServerScriptService/Services/PlayerDataService
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
        "[PlayerDataService] 缺少共享模块 %s（应放在 ReplicatedStorage/Shared 或 ReplicatedStorage 根目录）",
        moduleName
    ))
end

local GameConfig = requireSharedModule("GameConfig")

local PlayerDataService = {}
PlayerDataService._sessionDataByUserId = {}
PlayerDataService._allowDataStoreSaveByUserId = {}
PlayerDataService._autosaveThread = nil
PlayerDataService._dataStore = nil
PlayerDataService._didWarnStudioMemoryMode = false
PlayerDataService._didWarnStudioApiDenied = false

local function isStudioApiDeniedError(err)
    return string.find(string.lower(tostring(err)), "studio access to apis is not allowed", 1, true) ~= nil
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = deepCopy(nestedValue)
    end

    return copy
end

local function mergeDefaults(target, defaults)
    for key, defaultValue in pairs(defaults) do
        if target[key] == nil then
            target[key] = deepCopy(defaultValue)
        elseif type(defaultValue) == "table" and type(target[key]) == "table" then
            mergeDefaults(target[key], defaultValue)
        end
    end
end

local function waitForRetry(attempt)
    task.wait(GameConfig.DATASTORE.RetryDelay * attempt)
end

function PlayerDataService:Init()
    if self._autosaveThread then
        return
    end

    if RunService:IsStudio() and not GameConfig.DATASTORE.EnableInStudio then
        if not self._didWarnStudioMemoryMode then
            warn("[PlayerDataService] Studio 已使用内存数据模式（GameConfig.DATASTORE.EnableInStudio=false）。")
            self._didWarnStudioMemoryMode = true
        end
        self._dataStore = nil
    else
        self._dataStore = DataStoreService:GetDataStore(GameConfig.DATASTORE.ActiveName)
    end

    self._autosaveThread = task.spawn(function()
        while true do
            task.wait(GameConfig.DATASTORE.AutoSaveInterval)
            for _, player in ipairs(Players:GetPlayers()) do
                self:SavePlayerData(player)
            end
        end
    end)
end

function PlayerDataService:LoadPlayerData(player)
    local userId = player.UserId
    local loadedData
    local success = self._dataStore == nil
    local readFailed = false
    local allowDataStoreSave = self._dataStore ~= nil

    if self._dataStore then
        for attempt = 1, GameConfig.DATASTORE.MaxRetries do
            success, loadedData = pcall(function()
                return self._dataStore:GetAsync(tostring(userId))
            end)

            if success then
                break
            end

             readFailed = true

            if isStudioApiDeniedError(loadedData) then
                if not self._didWarnStudioApiDenied then
                    warn("[PlayerDataService] Studio 未开启 API Services，已自动切换为内存数据模式。")
                    self._didWarnStudioApiDenied = true
                end
                self._dataStore = nil
                allowDataStoreSave = false
                break
            end

            warn(string.format(
                "[PlayerDataService] 读取失败 userId=%d attempt=%d err=%s",
                userId,
                attempt,
                tostring(loadedData)
            ))

            if attempt < GameConfig.DATASTORE.MaxRetries then
                waitForRetry(attempt)
            end
        end
    end

    if self._dataStore and readFailed and not success then
        allowDataStoreSave = false
        warn(string.format(
            "[PlayerDataService] userId=%d 读取连续失败，本次会话将禁止写回 DataStore，避免覆盖旧档。",
            userId
        ))
    end

    local now = os.time()
    if not success or type(loadedData) ~= "table" then
        loadedData = deepCopy(GameConfig.DEFAULT_PLAYER_DATA)
        loadedData.Meta.CreatedAt = now
    end

    mergeDefaults(loadedData, GameConfig.DEFAULT_PLAYER_DATA)
    loadedData.Meta.LastLoginAt = now
    self._sessionDataByUserId[userId] = loadedData
    self._allowDataStoreSaveByUserId[userId] = allowDataStoreSave

    return loadedData
end

function PlayerDataService:GetPlayerData(player)
    return self._sessionDataByUserId[player.UserId]
end

function PlayerDataService:GetCoins(player)
    local data = self:GetPlayerData(player)
    if not data then
        return 0
    end

    return math.floor(tonumber(data.Currency.Coins) or 0)
end

function PlayerDataService:SetCoins(player, amount)
    local data = self:GetPlayerData(player)
    if not data then
        return nil, nil
    end

    local previous = math.floor(tonumber(data.Currency.Coins) or 0)
    local nextValue = math.max(0, math.floor(tonumber(amount) or 0))
    data.Currency.Coins = nextValue

    return previous, nextValue
end

function PlayerDataService:ChangeCoins(player, delta)
    local current = self:GetCoins(player)
    return self:SetCoins(player, current + delta)
end

function PlayerDataService:SetHomeId(player, homeId)
    local data = self:GetPlayerData(player)
    if not data then
        return
    end

    data.HomeState.HomeId = tostring(homeId or "")
end

function PlayerDataService:ResetPlayerData(player)
    local userId = player.UserId
    local now = os.time()

    local resetData = deepCopy(GameConfig.DEFAULT_PLAYER_DATA)
    resetData.Meta.CreatedAt = now
    resetData.Meta.LastLoginAt = now
    resetData.Meta.LastLogoutAt = 0
    resetData.Meta.LastSaveAt = 0

    self._sessionDataByUserId[userId] = resetData
    return resetData
end

function PlayerDataService:SavePlayerData(player, options)
    local userId = player.UserId
    local data = self._sessionDataByUserId[userId]
    if not data then
        return false
    end

    data.Meta.LastSaveAt = os.time()

    if not self._dataStore then
        return true
    end

    local forceDataStoreWrite = type(options) == "table" and options.ForceDataStoreWrite == true
    if self._allowDataStoreSaveByUserId[userId] == false and not forceDataStoreWrite then
        warn(string.format(
            "[PlayerDataService] 跳过保存 userId=%d：本次会话读取失败，已禁止写回避免清档。",
            userId
        ))
        return false
    end

    local success = false
    local errMsg = nil
    for attempt = 1, GameConfig.DATASTORE.MaxRetries do
        success, errMsg = pcall(function()
            self._dataStore:SetAsync(tostring(userId), data)
        end)

        if success then
            return true
        end

        if isStudioApiDeniedError(errMsg) then
            if not self._didWarnStudioApiDenied then
                warn("[PlayerDataService] Studio 未开启 API Services，保存已切换为内存模式。")
                self._didWarnStudioApiDenied = true
            end
            self._dataStore = nil
            return true
        end

        warn(string.format(
            "[PlayerDataService] 保存失败 userId=%d attempt=%d err=%s",
            userId,
            attempt,
            tostring(errMsg)
        ))

        if attempt < GameConfig.DATASTORE.MaxRetries then
            waitForRetry(attempt)
        end
    end

    return false
end

function PlayerDataService:SaveAllPlayers()
    local allSuccess = true
    local now = os.time()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = self._sessionDataByUserId[player.UserId]
        if type(data) == "table" and type(data.Meta) == "table" then
            data.Meta.LastLogoutAt = now
        end

        local success = self:SavePlayerData(player)
        if not success then
            allSuccess = false
        end
    end

    return allSuccess
end

function PlayerDataService:OnPlayerRemoving(player)
    local data = self._sessionDataByUserId[player.UserId]
    if type(data) == "table" and type(data.Meta) == "table" then
        data.Meta.LastLogoutAt = os.time()
    end

    self:SavePlayerData(player)
    self._sessionDataByUserId[player.UserId] = nil
    self._allowDataStoreSaveByUserId[player.UserId] = nil
end

return PlayerDataService
