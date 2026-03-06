--[[
脚本名字: BrainrotService
脚本文件: BrainrotService.lua
脚本类型: ModuleScript
本地路径: D:/RobloxGame/BrainrotsTemplate/BrainrotService.lua
Studio放置路径: ServerScriptService/Services/BrainrotService
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
        "[BrainrotService] 缺少共享模块 %s（应放在 ReplicatedStorage/Shared 或 ReplicatedStorage 根目录）",
        moduleName
    ))
end

local GameConfig = requireSharedModule("GameConfig")
local BrainrotConfig = requireSharedModule("BrainrotConfig")

local BrainrotService = {}
BrainrotService._playerDataService = nil
BrainrotService._homeService = nil
BrainrotService._currencyService = nil
BrainrotService._remoteEventService = nil
BrainrotService._brainrotStateSyncEvent = nil
BrainrotService._requestBrainrotStateSyncEvent = nil
BrainrotService._promptConnectionsByUserId = {}
BrainrotService._toolConnectionsByUserId = {}
BrainrotService._platformsByUserId = {}
BrainrotService._runtimePlacedByUserId = {}
BrainrotService._productionThread = nil

local function ensureTable(parentTable, key)
    if type(parentTable[key]) ~= "table" then
        parentTable[key] = {}
    end

    return parentTable[key]
end

local function parseModelPath(modelPath)
    if type(modelPath) ~= "string" then
        return nil, nil
    end

    return string.match(modelPath, "^([^/]+)/(.+)$")
end

local function getFirstBasePart(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function findInventoryIndexByInstanceId(inventory, instanceId)
    for index, inventoryItem in ipairs(inventory) do
        if tonumber(inventoryItem.InstanceId) == instanceId then
            return index
        end
    end

    return nil
end

function BrainrotService:_disconnectConnections(connectionList)
    if type(connectionList) ~= "table" then
        return
    end

    for _, connection in ipairs(connectionList) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
end

function BrainrotService:_clearPromptConnections(player)
    local userId = player.UserId
    self:_disconnectConnections(self._promptConnectionsByUserId[userId])
    self._promptConnectionsByUserId[userId] = nil
    self._platformsByUserId[userId] = nil
end

function BrainrotService:_clearToolConnections(player)
    local userId = player.UserId
    self:_disconnectConnections(self._toolConnectionsByUserId[userId])
    self._toolConnectionsByUserId[userId] = nil
end

function BrainrotService:_clearRuntimePlaced(player)
    local userId = player.UserId
    local runtimePlaced = self._runtimePlacedByUserId[userId]
    if type(runtimePlaced) ~= "table" then
        return
    end

    for _, modelOrPart in pairs(runtimePlaced) do
        if modelOrPart and modelOrPart.Parent then
            modelOrPart:Destroy()
        end
    end

    self._runtimePlacedByUserId[userId] = nil
end

function BrainrotService:_getBrainrotModelTemplate(modelPath)
    local qualityFolderName, modelName = parseModelPath(modelPath)
    if not qualityFolderName or not modelName then
        return nil
    end

    local modelRoot = ReplicatedStorage:FindFirstChild(GameConfig.BRAINROT.ModelRootFolderName)
    if not modelRoot then
        return nil
    end

    local qualityFolder = modelRoot:FindFirstChild(qualityFolderName)
    if not qualityFolder then
        return nil
    end

    local template = qualityFolder:FindFirstChild(modelName)
    if template and (template:IsA("Model") or template:IsA("BasePart")) then
        return template
    end

    return nil
end

function BrainrotService:_getOrCreateDataContainers(player)
    local playerData = self._playerDataService:GetPlayerData(player)
    if type(playerData) ~= "table" then
        return nil, nil, nil
    end

    local homeState = ensureTable(playerData, "HomeState")
    local placedBrainrots = ensureTable(homeState, "PlacedBrainrots")

    local brainrotData = ensureTable(playerData, "BrainrotData")
    if type(brainrotData.Inventory) ~= "table" then
        brainrotData.Inventory = {}
    end
    if type(brainrotData.NextInstanceId) ~= "number" then
        brainrotData.NextInstanceId = 1
    end
    if type(brainrotData.EquippedInstanceId) ~= "number" then
        brainrotData.EquippedInstanceId = 0
    end
    if type(brainrotData.StarterGranted) ~= "boolean" then
        brainrotData.StarterGranted = false
    end

    return playerData, brainrotData, placedBrainrots
end

function BrainrotService:_ensureStarterInventory(playerData, brainrotData, placedBrainrots)
    if brainrotData.StarterGranted then
        return
    end

    local hasPlaced = next(placedBrainrots) ~= nil
    if #brainrotData.Inventory > 0 or hasPlaced then
        brainrotData.StarterGranted = true
        return
    end

    for _, brainrotId in ipairs(BrainrotConfig.StarterBrainrotIds) do
        if BrainrotConfig.ById[brainrotId] then
            local instanceId = brainrotData.NextInstanceId
            brainrotData.NextInstanceId += 1

            table.insert(brainrotData.Inventory, {
                InstanceId = instanceId,
                BrainrotId = brainrotId,
            })
        end
    end

    brainrotData.StarterGranted = true
end

function BrainrotService:_createToolHandle(brainrotDefinition)
    local template = self:_getBrainrotModelTemplate(brainrotDefinition.ModelPath)
    local templatePart = getFirstBasePart(template)

    if templatePart then
        local handle = templatePart:Clone()
        handle.Name = "Handle"
        handle.Anchored = false
        handle.CanCollide = false
        handle.Massless = true
        return handle
    end

    local fallbackHandle = Instance.new("Part")
    fallbackHandle.Name = "Handle"
    fallbackHandle.Size = Vector3.new(1, 1, 1)
    fallbackHandle.Color = Color3.fromRGB(255, 170, 0)
    fallbackHandle.Material = Enum.Material.Neon
    fallbackHandle.Anchored = false
    fallbackHandle.CanCollide = false
    fallbackHandle.Massless = true
    return fallbackHandle
end

function BrainrotService:_onToolEquipped(player, tool)
    local _playerData, brainrotData = self:_getOrCreateDataContainers(player)
    if not brainrotData then
        return
    end

    brainrotData.EquippedInstanceId = tonumber(tool:GetAttribute("BrainrotInstanceId")) or 0
    self:PushBrainrotState(player)
end

function BrainrotService:_onToolUnequipped(player, tool)
    local _playerData, brainrotData = self:_getOrCreateDataContainers(player)
    if not brainrotData then
        return
    end

    local unequippedInstanceId = tonumber(tool:GetAttribute("BrainrotInstanceId")) or 0
    if brainrotData.EquippedInstanceId == unequippedInstanceId then
        brainrotData.EquippedInstanceId = 0
        self:PushBrainrotState(player)
    end
end

function BrainrotService:_onToolActivated(player)
    local character = player.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:UnequipTools()
    end
end

function BrainrotService:_createBrainrotTool(player, inventoryItem)
    local brainrotId = tonumber(inventoryItem.BrainrotId)
    local instanceId = tonumber(inventoryItem.InstanceId)
    local brainrotDefinition = brainrotId and BrainrotConfig.ById[brainrotId] or nil
    if not brainrotDefinition or not instanceId then
        return nil
    end

    local tool = Instance.new("Tool")
    tool.Name = brainrotDefinition.Name
    tool.CanBeDropped = false
    tool.TextureId = brainrotDefinition.Icon or ""
    tool.RequiresHandle = true
    tool:SetAttribute("BrainrotTool", true)
    tool:SetAttribute("BrainrotId", brainrotId)
    tool:SetAttribute("BrainrotInstanceId", instanceId)
    tool:SetAttribute("BrainrotModelPath", brainrotDefinition.ModelPath)

    local handle = self:_createToolHandle(brainrotDefinition)
    handle.Parent = tool

    local userId = player.UserId
    local connectionList = ensureTable(self._toolConnectionsByUserId, userId)
    table.insert(connectionList, tool.Equipped:Connect(function()
        self:_onToolEquipped(player, tool)
    end))
    table.insert(connectionList, tool.Unequipped:Connect(function()
        self:_onToolUnequipped(player, tool)
    end))
    table.insert(connectionList, tool.Activated:Connect(function()
        self:_onToolActivated(player)
    end))

    return tool
end

function BrainrotService:_removeBrainrotTools(player)
    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character

    local containers = { backpack, character }
    for _, container in ipairs(containers) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") and child:GetAttribute("BrainrotTool") then
                    child:Destroy()
                end
            end
        end
    end
end

function BrainrotService:_refreshBrainrotTools(player)
    self:_clearToolConnections(player)
    self:_removeBrainrotTools(player)

    local _playerData, brainrotData = self:_getOrCreateDataContainers(player)
    if not brainrotData then
        return
    end

    brainrotData.EquippedInstanceId = 0
    local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack")

    table.sort(brainrotData.Inventory, function(a, b)
        return (tonumber(a.InstanceId) or 0) < (tonumber(b.InstanceId) or 0)
    end)

    for _, inventoryItem in ipairs(brainrotData.Inventory) do
        local tool = self:_createBrainrotTool(player, inventoryItem)
        if tool then
            tool.Parent = backpack
        end
    end
end

function BrainrotService:GrantBrainrot(player, brainrotId, quantity, reason)
    local parsedBrainrotId = math.floor(tonumber(brainrotId) or 0)
    local parsedQuantity = math.floor(tonumber(quantity) or 0)
    if parsedBrainrotId <= 0 or parsedQuantity <= 0 then
        return false, "InvalidParams", 0
    end

    local brainrotDefinition = BrainrotConfig.ById[parsedBrainrotId]
    if not brainrotDefinition then
        return false, "BrainrotNotFound", 0
    end

    local _playerData, brainrotData = self:_getOrCreateDataContainers(player)
    if not brainrotData then
        return false, "PlayerDataNotReady", 0
    end

    brainrotData.StarterGranted = true

    local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 2)
    local grantedCount = 0

    for _ = 1, parsedQuantity do
        local instanceId = brainrotData.NextInstanceId
        brainrotData.NextInstanceId += 1

        local inventoryItem = {
            InstanceId = instanceId,
            BrainrotId = parsedBrainrotId,
        }
        table.insert(brainrotData.Inventory, inventoryItem)
        grantedCount += 1

        if backpack then
            local tool = self:_createBrainrotTool(player, inventoryItem)
            if tool then
                tool.Parent = backpack
            end
        end
    end

    if grantedCount > 0 then
        self:PushBrainrotState(player)
        return true, tostring(reason or "Unknown"), grantedCount
    end

    return false, "GrantFailed", 0
end

function BrainrotService:_getEquippedBrainrotTool(player)
    local character = player.Character
    if not character then
        return nil
    end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") and child:GetAttribute("BrainrotTool") then
            return child
        end
    end

    return nil
end

function BrainrotService:_buildPositionKey(platformPart)
    local parentPart = platformPart.Parent
    if parentPart and parentPart.Name then
        return parentPart.Name
    end

    return platformPart.Name
end

function BrainrotService:_scanHomePlatforms(homeModel)
    local platforms = {}
    local homeBase = homeModel and homeModel:FindFirstChild(GameConfig.HOME.HomeBaseName)
    if not homeBase then
        return platforms
    end

    for _, descendant in ipairs(homeBase:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.Name == "Platform" then
            local attachment = descendant:FindFirstChildOfClass("Attachment")
            local proximityPrompt = descendant:FindFirstChildOfClass("ProximityPrompt")

            if attachment and proximityPrompt then
                local positionKey = self:_buildPositionKey(descendant)
                platforms[positionKey] = {
                    PositionKey = positionKey,
                    Platform = descendant,
                    Attachment = attachment,
                    Prompt = proximityPrompt,
                }
            end
        end
    end

    return platforms
end

function BrainrotService:_createPlacedModel(attachment, brainrotDefinition)
    local template = self:_getBrainrotModelTemplate(brainrotDefinition.ModelPath)
    if not template then
        warn(string.format("[BrainrotService] 找不到脑红模型: %s", tostring(brainrotDefinition.ModelPath)))
        return nil
    end

    local runtimeFolder = attachment.Parent:FindFirstChild(GameConfig.BRAINROT.RuntimeFolderName)
    if not runtimeFolder then
        runtimeFolder = Instance.new("Folder")
        runtimeFolder.Name = GameConfig.BRAINROT.RuntimeFolderName
        runtimeFolder.Parent = attachment.Parent
    end

    local placedInstance = template:Clone()
    local offsetY = tonumber(GameConfig.BRAINROT.ModelPlacementOffsetY) or 0
    local targetCFrame = attachment.WorldCFrame * CFrame.new(0, offsetY, 0)

    if placedInstance:IsA("Model") then
        local primaryPart = placedInstance.PrimaryPart or placedInstance:FindFirstChildWhichIsA("BasePart", true)
        if not primaryPart then
            placedInstance:Destroy()
            warn(string.format("[BrainrotService] 脑红模型缺少 BasePart: %s", tostring(brainrotDefinition.ModelPath)))
            return nil
        end

        placedInstance.PrimaryPart = primaryPart
        for _, descendant in ipairs(placedInstance:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
            end
        end

        placedInstance:PivotTo(targetCFrame)
    elseif placedInstance:IsA("BasePart") then
        placedInstance.Anchored = true
        placedInstance.CanCollide = false
        placedInstance.CFrame = targetCFrame
    else
        placedInstance:Destroy()
        warn(string.format("[BrainrotService] 不支持放置的脑红实例类型: %s", placedInstance.ClassName))
        return nil
    end

    placedInstance.Name = string.format("PlacedBrainrot_%d", brainrotDefinition.Id)
    placedInstance.Parent = runtimeFolder
    return placedInstance
end

function BrainrotService:_placeEquippedBrainrot(player, platformInfo)
    local playerData, brainrotData, placedBrainrots = self:_getOrCreateDataContainers(player)
    if not playerData or not brainrotData or not placedBrainrots then
        return
    end

    local positionKey = platformInfo.PositionKey
    if placedBrainrots[positionKey] then
        return
    end

    local equippedTool = self:_getEquippedBrainrotTool(player)
    if not equippedTool then
        return
    end

    local instanceId = tonumber(equippedTool:GetAttribute("BrainrotInstanceId"))
    local brainrotId = tonumber(equippedTool:GetAttribute("BrainrotId"))
    if not instanceId or not brainrotId then
        return
    end

    local inventoryIndex = findInventoryIndexByInstanceId(brainrotData.Inventory, instanceId)
    if not inventoryIndex then
        return
    end

    local inventoryItem = brainrotData.Inventory[inventoryIndex]
    if tonumber(inventoryItem.BrainrotId) ~= brainrotId then
        return
    end

    local brainrotDefinition = BrainrotConfig.ById[brainrotId]
    if not brainrotDefinition then
        return
    end

    local placedModel = self:_createPlacedModel(platformInfo.Attachment, brainrotDefinition)
    if not placedModel then
        return
    end

    table.remove(brainrotData.Inventory, inventoryIndex)
    brainrotData.EquippedInstanceId = 0

    placedBrainrots[positionKey] = {
        InstanceId = instanceId,
        BrainrotId = brainrotId,
        PlacedAt = os.time(),
    }

    local runtimePlaced = ensureTable(self._runtimePlacedByUserId, player.UserId)
    runtimePlaced[positionKey] = placedModel

    equippedTool:Destroy()
    self:PushBrainrotState(player)
end

function BrainrotService:_bindHomePrompts(player, homeModel)
    self:_clearPromptConnections(player)
    local userId = player.UserId

    local platformsByPositionKey = self:_scanHomePlatforms(homeModel)
    self._platformsByUserId[userId] = platformsByPositionKey
    local connectionList = {}
    self._promptConnectionsByUserId[userId] = connectionList

    for _, platformInfo in pairs(platformsByPositionKey) do
        local prompt = platformInfo.Prompt
        prompt.HoldDuration = tonumber(GameConfig.BRAINROT.PromptHoldDuration) or 1
        prompt.ActionText = "放置脑红"
        prompt.ObjectText = "脑红平台"

        table.insert(connectionList, prompt.Triggered:Connect(function(triggerPlayer)
            if triggerPlayer ~= player then
                return
            end

            self:_placeEquippedBrainrot(player, platformInfo)
        end))
    end
end

function BrainrotService:_restorePlacedFromData(player)
    self:_clearRuntimePlaced(player)

    local playerData, _brainrotData, placedBrainrots = self:_getOrCreateDataContainers(player)
    if not playerData or not placedBrainrots then
        return
    end

    local platformsByPositionKey = self._platformsByUserId[player.UserId] or {}
    local runtimePlaced = ensureTable(self._runtimePlacedByUserId, player.UserId)

    for positionKey, placedData in pairs(placedBrainrots) do
        local platformInfo = platformsByPositionKey[positionKey]
        local brainrotId = tonumber(placedData.BrainrotId)
        local brainrotDefinition = brainrotId and BrainrotConfig.ById[brainrotId] or nil

        if platformInfo and brainrotDefinition then
            local placedModel = self:_createPlacedModel(platformInfo.Attachment, brainrotDefinition)
            if placedModel then
                runtimePlaced[positionKey] = placedModel
            end
        end
    end
end

function BrainrotService:PushBrainrotState(player)
    if not self._brainrotStateSyncEvent then
        return
    end

    local playerData, brainrotData, placedBrainrots = self:_getOrCreateDataContainers(player)
    if not playerData or not brainrotData or not placedBrainrots then
        return
    end

    local inventoryPayload = {}
    for _, inventoryItem in ipairs(brainrotData.Inventory) do
        local brainrotId = tonumber(inventoryItem.BrainrotId)
        local instanceId = tonumber(inventoryItem.InstanceId)
        local brainrotDefinition = brainrotId and BrainrotConfig.ById[brainrotId] or nil
        if brainrotDefinition and instanceId then
            table.insert(inventoryPayload, {
                instanceId = instanceId,
                brainrotId = brainrotDefinition.Id,
                name = brainrotDefinition.Name,
                icon = brainrotDefinition.Icon,
                quality = brainrotDefinition.Quality,
                qualityName = BrainrotConfig.QualityNames[brainrotDefinition.Quality] or "Unknown",
                rarity = brainrotDefinition.Rarity,
                rarityName = BrainrotConfig.RarityNames[brainrotDefinition.Rarity] or "Unknown",
                coinPerSecond = brainrotDefinition.CoinPerSecond,
                modelPath = brainrotDefinition.ModelPath,
            })
        end
    end

    table.sort(inventoryPayload, function(a, b)
        return a.instanceId < b.instanceId
    end)

    local placedPayload = {}
    for positionKey, placedData in pairs(placedBrainrots) do
        local brainrotId = tonumber(placedData.BrainrotId)
        local brainrotDefinition = brainrotId and BrainrotConfig.ById[brainrotId] or nil
        if brainrotDefinition then
            table.insert(placedPayload, {
                positionKey = positionKey,
                instanceId = tonumber(placedData.InstanceId) or 0,
                brainrotId = brainrotDefinition.Id,
                name = brainrotDefinition.Name,
                coinPerSecond = brainrotDefinition.CoinPerSecond,
                quality = brainrotDefinition.Quality,
                rarity = brainrotDefinition.Rarity,
            })
        end
    end

    table.sort(placedPayload, function(a, b)
        return a.positionKey < b.positionKey
    end)

    self._brainrotStateSyncEvent:FireClient(player, {
        inventory = inventoryPayload,
        placed = placedPayload,
        equippedInstanceId = tonumber(brainrotData.EquippedInstanceId) or 0,
    })
end

function BrainrotService:_tickProduction()
    for _, player in ipairs(Players:GetPlayers()) do
        local playerData = self._playerDataService:GetPlayerData(player)
        local placedBrainrots = playerData and playerData.HomeState and playerData.HomeState.PlacedBrainrots or nil
        if type(placedBrainrots) == "table" then
            local totalCoinsPerSecond = 0
            for _, placedData in pairs(placedBrainrots) do
                local brainrotId = tonumber(placedData.BrainrotId)
                local brainrotDefinition = brainrotId and BrainrotConfig.ById[brainrotId] or nil
                if brainrotDefinition then
                    totalCoinsPerSecond += math.max(0, math.floor(tonumber(brainrotDefinition.CoinPerSecond) or 0))
                end
            end

            if totalCoinsPerSecond > 0 then
                self._currencyService:AddCoins(player, totalCoinsPerSecond, "BrainrotProduction")
            end
        end
    end
end

function BrainrotService:OnPlayerReady(player, assignedHome)
    local playerData, brainrotData, placedBrainrots = self:_getOrCreateDataContainers(player)
    if not playerData or not brainrotData or not placedBrainrots then
        return
    end

    self:_ensureStarterInventory(playerData, brainrotData, placedBrainrots)

    local targetHome = assignedHome or self._homeService:GetAssignedHome(player)
    if targetHome then
        self:_bindHomePrompts(player, targetHome)
    end

    self:_restorePlacedFromData(player)
    self:_refreshBrainrotTools(player)
    self:PushBrainrotState(player)
end

function BrainrotService:OnPlayerRemoving(player)
    self:_clearPromptConnections(player)
    self:_clearToolConnections(player)
    self:_clearRuntimePlaced(player)
end

function BrainrotService:Init(dependencies)
    self._playerDataService = dependencies.PlayerDataService
    self._homeService = dependencies.HomeService
    self._currencyService = dependencies.CurrencyService
    self._remoteEventService = dependencies.RemoteEventService

    self._brainrotStateSyncEvent = self._remoteEventService:GetEvent("BrainrotStateSync")
    self._requestBrainrotStateSyncEvent = self._remoteEventService:GetEvent("RequestBrainrotStateSync")

    if self._requestBrainrotStateSyncEvent then
        self._requestBrainrotStateSyncEvent.OnServerEvent:Connect(function(player)
            self:PushBrainrotState(player)
        end)
    end

    if not self._productionThread then
        self._productionThread = task.spawn(function()
            while true do
                task.wait(1)
                self:_tickProduction()
            end
        end)
    end
end

return BrainrotService
