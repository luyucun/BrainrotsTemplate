--[[
脚本名字: CurrencyService
脚本文件: CurrencyService.lua
脚本类型: ModuleScript
本地路径: D:/RobloxGame/BrainrotsTemplate/CurrencyService.lua
Studio放置路径: ServerScriptService/Services/CurrencyService
]]

local CurrencyService = {}
CurrencyService._playerDataService = nil
CurrencyService._coinChangedEvent = nil
CurrencyService._requestCoinSyncEvent = nil

function CurrencyService:Init(dependencies)
    self._playerDataService = dependencies.PlayerDataService

    local remoteEventService = dependencies.RemoteEventService
    self._coinChangedEvent = remoteEventService:GetEvent("CoinChanged")
    self._requestCoinSyncEvent = remoteEventService:GetEvent("RequestCoinSync")

    self._requestCoinSyncEvent.OnServerEvent:Connect(function(player)
        self:PushCoinState(player, 0, "ClientSync")
    end)
end

function CurrencyService:PushCoinState(player, delta, reason)
    local totalCoins = self._playerDataService:GetCoins(player)
    self._coinChangedEvent:FireClient(player, {
        total = totalCoins,
        delta = math.floor(tonumber(delta) or 0),
        reason = tostring(reason or "Unknown"),
        timestamp = os.clock(),
    })
end

function CurrencyService:OnPlayerReady(player)
    self:PushCoinState(player, 0, "InitialSync")
end

function CurrencyService:AddCoins(player, amount, reason)
    local numericAmount = math.floor(tonumber(amount) or 0)
    if numericAmount == 0 then
        return false, self._playerDataService:GetCoins(player)
    end

    local previous, nextValue = self._playerDataService:ChangeCoins(player, numericAmount)
    if previous == nil then
        return false, 0
    end

    local delta = nextValue - previous
    if delta ~= 0 then
        self:PushCoinState(player, delta, reason or "AddCoins")
    end

    return true, nextValue
end

function CurrencyService:SetCoins(player, amount, reason)
    local previous, nextValue = self._playerDataService:SetCoins(player, amount)
    if previous == nil then
        return false, 0
    end

    local delta = nextValue - previous
    self:PushCoinState(player, delta, reason or "SetCoins")
    return true, nextValue
end

return CurrencyService
