--[[
脚本名字: BrainrotService
脚本文件: BrainrotService.lua
脚本类型: ModuleScript
本地路径: D:/RobloxGame/BrainrotsTemplate/BrainrotService.lua
Studio放置路径: ServerScriptService/Services/BrainrotService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

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
local BrainrotDisplayConfig = requireSharedModule("BrainrotDisplayConfig")
local FormatUtil = requireSharedModule("FormatUtil")

local BrainrotService = {}
BrainrotService._playerDataService = nil
BrainrotService._homeService = nil
BrainrotService._currencyService = nil
BrainrotService._friendBonusService = nil
BrainrotService._remoteEventService = nil
BrainrotService._brainrotStateSyncEvent = nil
BrainrotService._requestBrainrotStateSyncEvent = nil
BrainrotService._claimCashFeedbackEvent = nil
BrainrotService._promptConnectionsByUserId = {}
BrainrotService._toolConnectionsByUserId = {}
BrainrotService._claimConnectionsByUserId = {}
BrainrotService._claimTouchDebounceByUserId = {}
BrainrotService._claimEffectByUserId = {}
BrainrotService._claimBounceStateByUserId = {}
BrainrotService._platformsByUserId = {}
BrainrotService._claimsByUserId = {}
BrainrotService._runtimePlacedByUserId = {}
BrainrotService._runtimeIdleTracksByUserId = {}
BrainrotService._productionThread = nil
BrainrotService._missingDisplayPathWarned = {}
BrainrotService._didWarnMissingBaseInfoTemplate = false
BrainrotService._didWarnMissingInfoAttachmentByModelPath = {}
BrainrotService._didWarnMissingClaimEffectTemplate = false

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

local function getTemplateToolHandlePart(toolTemplate)
    if not toolTemplate or not toolTemplate:IsA("Tool") then
        return nil
    end

    local directHandle = toolTemplate:FindFirstChild("Handle")
    if directHandle and directHandle:IsA("BasePart") then
        return directHandle
    end

    local nestedHandle = toolTemplate:FindFirstChild("Handle", true)
    if nestedHandle and nestedHandle:IsA("BasePart") then
        return nestedHandle
    end

    return toolTemplate:FindFirstChildWhichIsA("BasePart", true)
end

local function getModelPivotCFrame(model)
    if not model or not model:IsA("Model") then
        return nil, nil
    end

    local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not primaryPart then
        return nil, nil
    end

    model.PrimaryPart = primaryPart
    return model:GetPivot(), primaryPart
end

local function getInstancePivotCFrame(instance)
    if not instance then
        return nil, nil
    end

    if instance:IsA("Model") then
        return getModelPivotCFrame(instance)
    end

    if instance:IsA("BasePart") then
        return instance.CFrame, instance
    end

    return nil, nil
end

local function setInstancePivotCFrame(instance, targetCFrame)
    if not instance or not targetCFrame then
        return
    end

    if instance:IsA("Model") then
        instance:PivotTo(targetCFrame)
        return
    end

    if instance:IsA("BasePart") then
        instance.CFrame = targetCFrame
    end
end

local function getToolPivotCFrame(tool, preferredModelName)
    if not tool or not tool:IsA("Tool") then
        return nil, nil
    end

    if type(preferredModelName) == "string" and preferredModelName ~= "" then
        local directPreferredModel = tool:FindFirstChild(preferredModelName)
        if directPreferredModel and directPreferredModel:IsA("Model") then
            local directPivot, directPivotPart = getModelPivotCFrame(directPreferredModel)
            if directPivot then
                return directPivot, directPivotPart
            end
        end

        local nestedPreferredModel = tool:FindFirstChild(preferredModelName, true)
        if nestedPreferredModel and nestedPreferredModel:IsA("Model") then
            local nestedPivot, nestedPivotPart = getModelPivotCFrame(nestedPreferredModel)
            if nestedPivot then
                return nestedPivot, nestedPivotPart
            end
        end
    end

    local directSameNameModel = tool:FindFirstChild(tool.Name)
    if directSameNameModel and directSameNameModel:IsA("Model") then
        local sameNamePivot, sameNamePivotPart = getModelPivotCFrame(directSameNameModel)
        if sameNamePivot then
            return sameNamePivot, sameNamePivotPart
        end
    end

    local nestedSameNameModel = tool:FindFirstChild(tool.Name, true)
    if nestedSameNameModel and nestedSameNameModel:IsA("Model") then
        local nestedSameNamePivot, nestedSameNamePivotPart = getModelPivotCFrame(nestedSameNameModel)
        if nestedSameNamePivot then
            return nestedSameNamePivot, nestedSameNamePivotPart
        end
    end

    local directHandle = tool:FindFirstChild("Handle")
    if directHandle and directHandle:IsA("BasePart") then
        return directHandle.CFrame, directHandle
    end

    local nestedHandle = tool:FindFirstChild("Handle", true)
    if nestedHandle and nestedHandle:IsA("BasePart") then
        return nestedHandle.CFrame, nestedHandle
    end

    local fallbackPart = tool:FindFirstChildWhichIsA("BasePart", true)
    if fallbackPart then
        return fallbackPart.CFrame, fallbackPart
    end

    return nil, nil
end

local function setToolVisualPart(part)
    if not part or not part:IsA("BasePart") then
        return
    end

    part.Anchored = false
    part.CanCollide = false
    part.Massless = true
end

local function findInventoryIndexByInstanceId(inventory, instanceId)
    for index, inventoryItem in ipairs(inventory) do
        if tonumber(inventoryItem.InstanceId) == instanceId then
            return index
        end
    end

    return nil
end

local function parseTrailingIndex(name, prefix)
    if type(name) ~= "string" or type(prefix) ~= "string" then
        return nil
    end

    local numberText = string.match(name, "^" .. prefix .. "(%d+)$")
    if not numberText then
        return nil
    end

    return tonumber(numberText)
end

local function isPlatformPart(part)
    if not part:IsA("BasePart") then
        return false
    end

    local lowerName = string.lower(part.Name)
    return lowerName == "platform" or lowerName == "platformpart" or string.find(lowerName, "platform", 1, true) ~= nil
end

local function getCharacterRootPart(character)
    if not character then
        return nil
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
        return humanoidRootPart
    end

    local primaryPart = character.PrimaryPart
    if primaryPart and primaryPart:IsA("BasePart") then
        return primaryPart
    end

    local fallbackPart = character:FindFirstChildWhichIsA("BasePart")
    if fallbackPart and fallbackPart:IsA("BasePart") then
        return fallbackPart
    end

    return nil
end

local function isCharacterNearPart(character, part)
    if not (character and part and part.Parent and part:IsA("BasePart")) then
        return false
    end

    local rootPart = getCharacterRootPart(character)
    if not (rootPart and rootPart.Parent) then
        return false
    end

    local localPosition = part.CFrame:PointToObjectSpace(rootPart.Position)
    local size = part.Size
    local xLimit = (size.X * 0.5) + 2
    local zLimit = (size.Z * 0.5) + 2
    local yLimit = (size.Y * 0.5) + 8

    return math.abs(localPosition.X) <= xLimit
        and math.abs(localPosition.Z) <= zLimit
        and math.abs(localPosition.Y) <= yLimit
end

local function isCharacterTouchingPart(character, part)
    if not (character and character.Parent and part and part.Parent and part:IsA("BasePart")) then
        return false
    end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Include
    overlapParams.FilterDescendantsInstances = { character }
    overlapParams.MaxParts = 1

    local success, touchedParts = pcall(function()
        return workspace:GetPartsInPart(part, overlapParams)
    end)

    return success and type(touchedParts) == "table" and #touchedParts > 0
end

local function isCharacterOccupyingPart(character, part)
    return isCharacterTouchingPart(character, part) or isCharacterNearPart(character, part)
end

local function formatCurrentGoldText(value)
    return "$" .. FormatUtil.FormatWithCommas(value)
end

local function formatOfflineGoldText(value)
    return "Offline:$" .. FormatUtil.FormatWithCommas(value)
end

local function normalizeAnimationId(animationId)
    if type(animationId) == "number" then
        animationId = tostring(math.floor(animationId))
    end

    if type(animationId) ~= "string" then
        return nil
    end

    local trimmed = string.gsub(animationId, "^%s*(.-)%s*$", "%1")
    if trimmed == "" then
        return nil
    end

    if string.match(trimmed, "^rbxassetid://") then
        return trimmed
    end

    if string.match(trimmed, "^%d+$") then
        return "rbxassetid://" .. trimmed
    end

    return nil
end

local function resolveQualityDisplayInfo(qualityId)
    local parsedId = math.floor(tonumber(qualityId) or 0)
    local displayEntry = type(BrainrotDisplayConfig.Quality) == "table" and BrainrotDisplayConfig.Quality[parsedId] or nil
    local displayName = (type(displayEntry) == "table" and tostring(displayEntry.Name or "")) or ""
    if displayName == "" then
        displayName = BrainrotConfig.QualityNames[parsedId] or "Unknown"
    end

    local gradientPath = type(displayEntry) == "table" and displayEntry.GradientPath or nil
    return displayName, gradientPath
end

local function resolveRarityDisplayInfo(rarityId)
    local parsedId = math.floor(tonumber(rarityId) or 0)
    local displayEntry = type(BrainrotDisplayConfig.Rarity) == "table" and BrainrotDisplayConfig.Rarity[parsedId] or nil
    local displayName = (type(displayEntry) == "table" and tostring(displayEntry.Name or "")) or ""
    if displayName == "" then
        displayName = BrainrotConfig.RarityNames[parsedId] or "Unknown"
    end

    local gradientPath = type(displayEntry) == "table" and displayEntry.GradientPath or nil
    return displayName, gradientPath
end

local function splitSlashPath(pathText)
    local result = {}
    if type(pathText) ~= "string" then
        return result
    end

    for segment in string.gmatch(pathText, "[^/]+") do
        if segment ~= "" then
            table.insert(result, segment)
        end
    end

    return result
end

local function findInstanceBySlashPath(pathText)
    local segments = splitSlashPath(pathText)
    if #segments <= 0 then
        return nil
    end

    local current = nil
    for index, segment in ipairs(segments) do
        if index == 1 then
            if segment == "StarterGui" then
                current = StarterGui
            elseif segment == "ReplicatedStorage" then
                current = ReplicatedStorage
            elseif segment == "Workspace" then
                current = game:GetService("Workspace")
            else
                current = game:FindFirstChild(segment)
            end
        else
            current = current and current:FindFirstChild(segment) or nil
        end

        if not current then
            return nil
        end
    end

    return current
end

local function findFirstTextLabelByName(root, nodeName)
    if not root then
        return nil
    end

    local node = root:FindFirstChild(nodeName, true)
    if node and node:IsA("TextLabel") then
        return node
    end

    return nil
end

local function markManagedDisplayNode(node)
    if not node then
        return
    end

    node:SetAttribute("BrainrotInfoGradient", true)
    for _, descendant in ipairs(node:GetDescendants()) do
        descendant:SetAttribute("BrainrotInfoGradient", true)
    end
end

local function clearManagedDisplayNodes(parentNode)
    if not parentNode then
        return
    end

    for _, child in ipairs(parentNode:GetChildren()) do
        if child:GetAttribute("BrainrotInfoGradient") == true then
            child:Destroy()
        end
    end
end
local SECRET_QUALITY_STROKE_COLOR = Color3.fromRGB(255, 255, 255)

local function applyQualityStrokeColorRule(qualityLabel, qualityId)
    if not (qualityLabel and qualityLabel:IsA("TextLabel")) then
        return
    end

    local isSecretQuality = math.floor(tonumber(qualityId) or 0) == 7
    for _, stroke in ipairs(qualityLabel:GetChildren()) do
        if stroke:IsA("UIStroke") and stroke:GetAttribute("BrainrotInfoGradient") ~= true then
            local defaultColor = stroke:GetAttribute("BrainrotDefaultStrokeColor")
            if typeof(defaultColor) ~= "Color3" then
                stroke:SetAttribute("BrainrotDefaultStrokeColor", stroke.Color)
                defaultColor = stroke.Color
            end

            if isSecretQuality then
                stroke.Color = SECRET_QUALITY_STROKE_COLOR
            elseif typeof(defaultColor) == "Color3" then
                stroke.Color = defaultColor
            end
        end
    end
end
local function modulo01(value)
    local parsed = tonumber(value) or 0
    parsed = parsed % 1
    if parsed < 0 then
        parsed = parsed + 1
    end
    return parsed
end

local function collectRotatedInteriorPositions(baseKeypoints, shift)
    local positions = {}
    for _, keypoint in ipairs(baseKeypoints) do
        local rotatedTime = modulo01((tonumber(keypoint.Time) or 0) + shift)
        if rotatedTime > 0.0001 and rotatedTime < 0.9999 then
            table.insert(positions, rotatedTime)
        end
    end

    table.sort(positions)

    local deduplicated = {}
    local lastTime = nil
    for _, timeValue in ipairs(positions) do
        if not lastTime or math.abs(timeValue - lastTime) > 0.0001 then
            table.insert(deduplicated, timeValue)
            lastTime = timeValue
        end
    end

    return deduplicated
end

local function sampleColorSequencePeriodic(baseKeypoints, timeValue)
    local count = #baseKeypoints
    if count <= 0 then
        return Color3.new(1, 1, 1)
    end

    if count == 1 then
        return baseKeypoints[1].Value
    end

    local targetTime = modulo01(timeValue)

    for index = 1, count - 1 do
        local left = baseKeypoints[index]
        local right = baseKeypoints[index + 1]
        if targetTime >= left.Time and targetTime <= right.Time then
            local span = math.max(0.000001, right.Time - left.Time)
            local alpha = math.clamp((targetTime - left.Time) / span, 0, 1)
            return left.Value:Lerp(right.Value, alpha)
        end
    end

    local last = baseKeypoints[count]
    local first = baseKeypoints[1]
    local wrappedTime = targetTime
    if wrappedTime < first.Time then
        wrappedTime = wrappedTime + 1
    end

    local span = math.max(0.000001, (first.Time + 1) - last.Time)
    local alpha = math.clamp((wrappedTime - last.Time) / span, 0, 1)
    return last.Value:Lerp(first.Value, alpha)
end

local function sampleNumberSequencePeriodic(baseKeypoints, timeValue)
    local count = #baseKeypoints
    if count <= 0 then
        return 0, 0
    end

    if count == 1 then
        return baseKeypoints[1].Value, baseKeypoints[1].Envelope
    end

    local targetTime = modulo01(timeValue)

    for index = 1, count - 1 do
        local left = baseKeypoints[index]
        local right = baseKeypoints[index + 1]
        if targetTime >= left.Time and targetTime <= right.Time then
            local span = math.max(0.000001, right.Time - left.Time)
            local alpha = math.clamp((targetTime - left.Time) / span, 0, 1)
            local value = left.Value + ((right.Value - left.Value) * alpha)
            local envelope = left.Envelope + ((right.Envelope - left.Envelope) * alpha)
            return value, envelope
        end
    end

    local last = baseKeypoints[count]
    local first = baseKeypoints[1]
    local wrappedTime = targetTime
    if wrappedTime < first.Time then
        wrappedTime = wrappedTime + 1
    end

    local span = math.max(0.000001, (first.Time + 1) - last.Time)
    local alpha = math.clamp((wrappedTime - last.Time) / span, 0, 1)
    local value = last.Value + ((first.Value - last.Value) * alpha)
    local envelope = last.Envelope + ((first.Envelope - last.Envelope) * alpha)
    return value, envelope
end

local function buildRotatedColorSequence(baseKeypoints, shift)
    local keypoints = {
        ColorSequenceKeypoint.new(0, sampleColorSequencePeriodic(baseKeypoints, -shift)),
    }

    for _, position in ipairs(collectRotatedInteriorPositions(baseKeypoints, shift)) do
        table.insert(keypoints, ColorSequenceKeypoint.new(position, sampleColorSequencePeriodic(baseKeypoints, position - shift)))
    end

    table.insert(keypoints, ColorSequenceKeypoint.new(1, sampleColorSequencePeriodic(baseKeypoints, 1 - shift)))
    return ColorSequence.new(keypoints)
end

local function buildRotatedNumberSequence(baseKeypoints, shift)
    local startValue, startEnvelope = sampleNumberSequencePeriodic(baseKeypoints, -shift)
    local keypoints = {
        NumberSequenceKeypoint.new(0, startValue, startEnvelope),
    }

    for _, position in ipairs(collectRotatedInteriorPositions(baseKeypoints, shift)) do
        local value, envelope = sampleNumberSequencePeriodic(baseKeypoints, position - shift)
        table.insert(keypoints, NumberSequenceKeypoint.new(position, value, envelope))
    end

    local endValue, endEnvelope = sampleNumberSequencePeriodic(baseKeypoints, 1 - shift)
    table.insert(keypoints, NumberSequenceKeypoint.new(1, endValue, endEnvelope))
    return NumberSequence.new(keypoints)
end

local function resolveAnimatedQualityGradientProfile(pathKey, gradientPath)
    local key = tostring(pathKey or "")
    if key == "Quality:6" then
        return "MythicQualityGradient"
    end
    if key == "Quality:7" then
        return "SecretQualityGradient"
    end
    if key == "Quality:8" then
        return "GodQualityGradient"
    end
    if key == "Quality:9" then
        return "OGQualityGradient"
    end
    if key == "Rarity:4" then
        return "LavaRarityGradient"
    end
    if key == "Rarity:6" then
        return "HackerRarityGradient"
    end
    if key == "Rarity:7" then
        return "RainbowRarityGradient"
    end

    if type(gradientPath) ~= "string" then
        return nil
    end

    local lowerPath = string.lower(gradientPath)
    if string.find(lowerPath, "startergui/gradients/animation/quality/mythic", 1, true) ~= nil then
        return "MythicQualityGradient"
    end
    if string.find(lowerPath, "startergui/gradients/animation/quality/secret", 1, true) ~= nil then
        return "SecretQualityGradient"
    end
    if string.find(lowerPath, "startergui/gradients/animation/quality/god", 1, true) ~= nil then
        return "GodQualityGradient"
    end
    if string.find(lowerPath, "startergui/gradients/animation/quality/og", 1, true) ~= nil then
        return "OGQualityGradient"
    end
    if string.find(lowerPath, "startergui/gradients/animation/rarity/lava", 1, true) ~= nil then
        return "LavaRarityGradient"
    end
    if string.find(lowerPath, "startergui/gradients/animation/rarity/hacker", 1, true) ~= nil then
        return "HackerRarityGradient"
    end
    if string.find(lowerPath, "startergui/gradients/animation/rarity/rainbow", 1, true) ~= nil then
        return "RainbowRarityGradient"
    end

    return nil
end
local function resolveAnimatedQualityGradientConfig(profileName)
    local configRoot = GameConfig.BRAINROT or {}
    local prefix = tostring(profileName or "")
    if prefix == "" then
        return nil
    end

    local enabledKey = prefix .. "AnimationEnabled"
    local offsetRangeKey = prefix .. "OffsetRange"
    local oneWayDurationKey = prefix .. "OneWayDuration"
    local updateIntervalKey = prefix .. "UpdateInterval"

    local config = {
        Enabled = configRoot[enabledKey] ~= false,
        OffsetRange = math.max(0.05, tonumber(configRoot[offsetRangeKey]) or 1),
        OneWayDuration = math.max(0.2, tonumber(configRoot[oneWayDurationKey]) or 2.4),
        UpdateInterval = math.max(1 / 120, tonumber(configRoot[updateIntervalKey]) or (1 / 30)),
    }

    return config
end
function BrainrotService:_tryStartDisplayGradientAnimation(node, gradientPath, pathKey)
    if not (node and node:IsA("UIGradient")) then
        return
    end

    local profileName = resolveAnimatedQualityGradientProfile(pathKey, gradientPath)
    if not profileName then
        return
    end

    local animationConfig = resolveAnimatedQualityGradientConfig(profileName)
    if not animationConfig or animationConfig.Enabled == false then
        return
    end

    if node:GetAttribute("BrainrotInfoGradientAnimated") == true then
        return
    end
    node:SetAttribute("BrainrotInfoGradientAnimated", true)

    local baseColorKeypoints = node.Color.Keypoints
    if type(baseColorKeypoints) ~= "table" or #baseColorKeypoints <= 0 then
        return
    end

    local baseTransparencyKeypoints = node.Transparency.Keypoints
    local cycleScale = animationConfig.OffsetRange
    local cycleDuration = animationConfig.OneWayDuration
    local updateInterval = animationConfig.UpdateInterval

    task.spawn(function()
        local elapsed = 0
        local elapsedSinceUpdate = 0

        while node and node.Parent do
            local delta = task.wait()
            elapsed = elapsed + delta
            elapsedSinceUpdate = elapsedSinceUpdate + delta

            if elapsedSinceUpdate >= updateInterval then
                elapsedSinceUpdate = 0
                local shift = modulo01((elapsed / cycleDuration) * cycleScale)

                local okColor, rotatedColor = pcall(function()
                    return buildRotatedColorSequence(baseColorKeypoints, shift)
                end)
                if okColor and rotatedColor then
                    node.Color = rotatedColor
                end

                if type(baseTransparencyKeypoints) == "table" and #baseTransparencyKeypoints > 0 then
                    local okTransparency, rotatedTransparency = pcall(function()
                        return buildRotatedNumberSequence(baseTransparencyKeypoints, shift)
                    end)
                    if okTransparency and rotatedTransparency then
                        node.Transparency = rotatedTransparency
                    end
                end
            end
        end
    end)
end

function BrainrotService:_warnMissingDisplayPath(pathKey, pathText)
    local key = tostring(pathKey or "")
    if key == "" then
        return
    end

    if self._missingDisplayPathWarned[key] then
        return
    end

    self._missingDisplayPathWarned[key] = true
    warn(string.format(
        "[BrainrotService] 渐变节点缺失或不可用: %s（路径=%s）",
        key,
        tostring(pathText)
    ))
end

function BrainrotService:_applyDisplayGradient(label, gradientPath, pathKey)
    if not (label and label:IsA("TextLabel")) then
        return
    end

    clearManagedDisplayNodes(label)

    if type(gradientPath) ~= "string" or gradientPath == "" then
        return
    end

    local sourceNode = findInstanceBySlashPath(gradientPath)
    if not sourceNode then
        self:_warnMissingDisplayPath(pathKey, gradientPath)
        return
    end

    local gradientNodes = {}
    if sourceNode:IsA("UIGradient") or sourceNode:IsA("UIStroke") then
        table.insert(gradientNodes, sourceNode)
    else
        for _, descendant in ipairs(sourceNode:GetDescendants()) do
            if descendant:IsA("UIGradient") or descendant:IsA("UIStroke") then
                table.insert(gradientNodes, descendant)
            end
        end
    end

    if #gradientNodes <= 0 then
        self:_warnMissingDisplayPath(pathKey, gradientPath)
        return
    end

    for _, gradientNode in ipairs(gradientNodes) do
        local clonedNode = gradientNode:Clone()
        markManagedDisplayNode(clonedNode)

        local ok = pcall(function()
            clonedNode.Parent = label
        end)

        if not ok then
            clonedNode:Destroy()
            self:_warnMissingDisplayPath(pathKey, gradientPath)
        else
            self:_tryStartDisplayGradientAnimation(clonedNode, gradientPath, pathKey)
        end
    end
end

function BrainrotService:_findInfoAttachment(placedInstance)
    if not placedInstance then
        return nil
    end

    local infoAttachmentName = tostring(GameConfig.BRAINROT.InfoAttachmentName or "Info")
    local infoAttachment = placedInstance:FindFirstChild(infoAttachmentName, true)
    if infoAttachment and infoAttachment:IsA("Attachment") then
        return infoAttachment
    end

    return nil
end

function BrainrotService:_attachPlacedInfoUi(placedInstance, brainrotDefinition)
    if not placedInstance or type(brainrotDefinition) ~= "table" then
        return
    end

    local infoTemplateRootName = tostring(GameConfig.BRAINROT.InfoTemplateRootName or "UI")
    local infoTemplateName = tostring(GameConfig.BRAINROT.InfoTemplateName or "BaseInfo")
    local infoTitleRootName = tostring(GameConfig.BRAINROT.InfoTitleRootName or "Title")
    local infoNameLabelName = tostring(GameConfig.BRAINROT.InfoNameLabelName or "Name")
    local infoQualityLabelName = tostring(GameConfig.BRAINROT.InfoQualityLabelName or "Quality")
    local infoRarityLabelName = tostring(GameConfig.BRAINROT.InfoRarityLabelName or "Rarity")
    local infoSpeedLabelName = tostring(GameConfig.BRAINROT.InfoSpeedLabelName or "Speed")

    local infoTemplateRoot = ReplicatedStorage:FindFirstChild(infoTemplateRootName)
    local infoTemplate = infoTemplateRoot and infoTemplateRoot:FindFirstChild(infoTemplateName) or nil
    if not (infoTemplate and infoTemplate:IsA("BillboardGui")) then
        if not self._didWarnMissingBaseInfoTemplate then
            warn(string.format(
                "[BrainrotService] 缺少脑红信息模板：ReplicatedStorage/%s/%s",
                tostring(infoTemplateRootName),
                tostring(infoTemplateName)
            ))
            self._didWarnMissingBaseInfoTemplate = true
        end
        return
    end

    local infoAttachment = self:_findInfoAttachment(placedInstance)
    if not infoAttachment then
        local modelPathKey = tostring(brainrotDefinition.ModelPath or "UnknownModelPath")
        if not self._didWarnMissingInfoAttachmentByModelPath[modelPathKey] then
            warn(string.format(
                "[BrainrotService] 脑红模型缺少 Info Attachment，无法挂载 BaseInfo（ModelPath=%s）",
                modelPathKey
            ))
            self._didWarnMissingInfoAttachmentByModelPath[modelPathKey] = true
        end
        return
    end

    local existingInfo = infoAttachment:FindFirstChild(infoTemplateName)
    if existingInfo and existingInfo:IsA("BillboardGui") then
        existingInfo:Destroy()
    end

    local infoGui = infoTemplate:Clone()
    infoGui.Name = infoTemplateName
    infoGui.Adornee = infoAttachment
    infoGui.Parent = infoAttachment

    local titleRoot = infoGui:FindFirstChild(infoTitleRootName, true)
    local searchRoot = titleRoot or infoGui

    local nameLabel = findFirstTextLabelByName(searchRoot, infoNameLabelName) or findFirstTextLabelByName(infoGui, infoNameLabelName)
    local qualityLabel = findFirstTextLabelByName(searchRoot, infoQualityLabelName) or findFirstTextLabelByName(infoGui, infoQualityLabelName)
    local rarityLabel = findFirstTextLabelByName(searchRoot, infoRarityLabelName) or findFirstTextLabelByName(infoGui, infoRarityLabelName)
    local speedLabel = findFirstTextLabelByName(searchRoot, infoSpeedLabelName) or findFirstTextLabelByName(infoGui, infoSpeedLabelName)

    local qualityId = math.floor(tonumber(brainrotDefinition.Quality) or 0)
    local rarityId = math.floor(tonumber(brainrotDefinition.Rarity) or 0)
    local qualityName, qualityGradientPath = resolveQualityDisplayInfo(qualityId)
    local rarityName, rarityGradientPath = resolveRarityDisplayInfo(rarityId)
    local coinPerSecond = math.max(0, math.floor(tonumber(brainrotDefinition.CoinPerSecond) or 0))

    if nameLabel then
        nameLabel.Text = tostring(brainrotDefinition.Name or "Unknown")
    end

    if qualityLabel then
        qualityLabel.Visible = true
        qualityLabel.Text = tostring(qualityName)
        applyQualityStrokeColorRule(qualityLabel, qualityId)
        self:_applyDisplayGradient(qualityLabel, qualityGradientPath, "Quality:" .. tostring(qualityId))
    end

    if rarityLabel then
        local hideNormalRarity = GameConfig.BRAINROT.HideNormalRarity ~= false
        local shouldShowRarity = (not hideNormalRarity) or rarityId > 1
        rarityLabel.Visible = shouldShowRarity
        rarityLabel.Text = tostring(rarityName)

        if shouldShowRarity then
            self:_applyDisplayGradient(rarityLabel, rarityGradientPath, "Rarity:" .. tostring(rarityId))
        else
            clearManagedDisplayNodes(rarityLabel)
        end
    end

    if speedLabel then
        speedLabel.Text = string.format("$%s/S", FormatUtil.FormatWithCommas(coinPerSecond))
    end
end
local function getOrCreatePulseScale(label)
    if not label or not label:IsA("TextLabel") then
        return nil
    end

    local pulseScale = label:FindFirstChild("GoldPulseScale")
    if pulseScale and pulseScale:IsA("UIScale") then
        return pulseScale
    end

    pulseScale = Instance.new("UIScale")
    pulseScale.Name = "GoldPulseScale"
    pulseScale.Scale = 1
    pulseScale.Parent = label
    return pulseScale
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

function BrainrotService:_clearClaimConnections(player)
    local userId = player.UserId
    self:_disconnectConnections(self._claimConnectionsByUserId[userId])
    self._claimConnectionsByUserId[userId] = nil
    self._claimTouchDebounceByUserId[userId] = nil

    local claimsByPositionKey = self._claimsByUserId[userId]
    if type(claimsByPositionKey) == "table" then
        for _, claimInfo in pairs(claimsByPositionKey) do
            if claimInfo and claimInfo._currentPressTween then
                claimInfo._currentPressTween:Cancel()
                claimInfo._currentPressTween = nil
            end

            if claimInfo and claimInfo._touchHighlightTween then
                claimInfo._touchHighlightTween:Cancel()
                claimInfo._touchHighlightTween = nil
            end

            if claimInfo and claimInfo._touchHighlight then
                claimInfo._touchHighlight:Destroy()
                claimInfo._touchHighlight = nil
            end

            local pressPart = claimInfo.TouchPart or claimInfo.ClaimPart
            local pressBaseCFrame = claimInfo.TouchPart and claimInfo.TouchBaseCFrame or claimInfo.ClaimBaseCFrame
            if pressPart and pressPart.Parent and pressBaseCFrame then
                pressPart.CFrame = pressBaseCFrame
            end
        end
    end

    local claimEffectByPosition = self._claimEffectByUserId[userId]
    if type(claimEffectByPosition) == "table" then
        local pendingEffectKeys = {}
        for positionKey in pairs(claimEffectByPosition) do
            table.insert(pendingEffectKeys, positionKey)
        end

        for _, positionKey in ipairs(pendingEffectKeys) do
            self:_destroyClaimTouchEffectForPosition(userId, positionKey)
        end
    end
    self._claimEffectByUserId[userId] = nil

    local claimBounceByPosition = self._claimBounceStateByUserId[userId]
    if type(claimBounceByPosition) == "table" then
        local pendingKeys = {}
        for positionKey in pairs(claimBounceByPosition) do
            table.insert(pendingKeys, positionKey)
        end

        for _, positionKey in ipairs(pendingKeys) do
            self:_clearClaimBounceState(userId, positionKey, true)
        end
    end
    self._claimBounceStateByUserId[userId] = nil

    self._claimsByUserId[userId] = nil
end

function BrainrotService:_clearToolConnections(player)
    local userId = player.UserId
    self:_disconnectConnections(self._toolConnectionsByUserId[userId])
    self._toolConnectionsByUserId[userId] = nil
end

function BrainrotService:_clearRuntimePlaced(player)
    self:_stopAllIdleTracks(player)

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

    local claimBounceByPosition = self._claimBounceStateByUserId[userId]
    if type(claimBounceByPosition) == "table" then
        local pendingKeys = {}
        for positionKey in pairs(claimBounceByPosition) do
            table.insert(pendingKeys, positionKey)
        end

        for _, positionKey in ipairs(pendingKeys) do
            self:_clearClaimBounceState(userId, positionKey, false)
        end
    end
    self._claimBounceStateByUserId[userId] = nil

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
    if template and (template:IsA("Model") or template:IsA("BasePart") or template:IsA("Tool")) then
        return template
    end

    return nil
end

function BrainrotService:_getOrCreateDataContainers(player)
    local playerData = self._playerDataService:GetPlayerData(player)
    if type(playerData) ~= "table" then
        return nil, nil, nil, nil
    end

    local homeState = ensureTable(playerData, "HomeState")
    local placedBrainrots = ensureTable(homeState, "PlacedBrainrots")
    local productionState = ensureTable(homeState, "ProductionState")

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

    return playerData, brainrotData, placedBrainrots, productionState
end

function BrainrotService:_getOrCreateProductionSlot(productionState, positionKey)
    local slot = ensureTable(productionState, positionKey)
    slot.CurrentGold = math.max(0, math.floor(tonumber(slot.CurrentGold) or 0))
    slot.OfflineGold = math.max(0, math.floor(tonumber(slot.OfflineGold) or 0))
    slot.FriendBonusRemainder = math.max(0, tonumber(slot.FriendBonusRemainder) or 0)

    if slot.FriendBonusRemainder >= 1 then
        local extraWhole = math.floor(slot.FriendBonusRemainder)
        slot.CurrentGold += extraWhole
        slot.FriendBonusRemainder -= extraWhole
    end

    return slot
end

function BrainrotService:_collectProductionBonusRates(player)
    local rates = {}

    local friendBonusPercent = 0
    if self._friendBonusService then
        friendBonusPercent = math.max(0, math.floor(tonumber(self._friendBonusService:GetBonusPercent(player)) or 0))
    end

    if friendBonusPercent > 0 then
        table.insert(rates, {
            Source = "FriendBonus",
            Rate = friendBonusPercent / 100,
        })
    end

    local extraBonusPercent = math.max(0, tonumber(player:GetAttribute("ExtraProductionBonusPercent")) or 0)
    if extraBonusPercent > 0 then
        table.insert(rates, {
            Source = "ExtraProductionBonus",
            Rate = extraBonusPercent / 100,
        })
    end

    return rates
end

function BrainrotService:_resolveProductionMultiplier(player)
    local totalBonusRate = 0
    for _, bonusInfo in ipairs(self:_collectProductionBonusRates(player)) do
        totalBonusRate += math.max(0, tonumber(bonusInfo.Rate) or 0)
    end

    return 1 + totalBonusRate, totalBonusRate
end

function BrainrotService:_computePlacedBaseProductionSpeed(placedBrainrots)
    local baseSpeed = 0
    if type(placedBrainrots) ~= "table" then
        return 0
    end

    for _, placedData in pairs(placedBrainrots) do
        local brainrotId = tonumber(placedData.BrainrotId)
        local brainrotDefinition = brainrotId and BrainrotConfig.ById[brainrotId] or nil
        if brainrotDefinition then
            baseSpeed += math.max(0, math.floor(tonumber(brainrotDefinition.CoinPerSecond) or 0))
        end
    end

    return baseSpeed
end

function BrainrotService:_updatePlayerTotalProductionSpeed(player, placedBrainrots)
    if not player then
        return 0, 1, 0
    end

    local resolvedPlacedBrainrots = placedBrainrots
    if type(resolvedPlacedBrainrots) ~= "table" then
        local _playerData, _brainrotData
        _playerData, _brainrotData, resolvedPlacedBrainrots = self:_getOrCreateDataContainers(player)
    end

    local baseSpeed = self:_computePlacedBaseProductionSpeed(resolvedPlacedBrainrots)
    local multiplier, totalBonusRate = self:_resolveProductionMultiplier(player)
    local finalSpeed = baseSpeed * multiplier

    player:SetAttribute("TotalProductionSpeedBase", baseSpeed)
    player:SetAttribute("TotalProductionBonusRate", totalBonusRate)
    player:SetAttribute("TotalProductionMultiplier", multiplier)
    player:SetAttribute("TotalProductionSpeed", finalSpeed)

    return baseSpeed, multiplier, finalSpeed
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

function BrainrotService:_createToolHandle(_brainrotDefinition)
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1, 1, 1)
    handle.Transparency = 1
    handle.Anchored = false
    handle.CanCollide = false
    handle.CanTouch = false
    handle.CanQuery = false
    handle.Massless = true
    return handle
end

function BrainrotService:_findToolVisualSource(template, preferredModelName)
    if not template then
        return nil
    end

    if template:IsA("Tool") then
        if type(preferredModelName) == "string" and preferredModelName ~= "" then
            local directPreferred = template:FindFirstChild(preferredModelName)
            if directPreferred and (directPreferred:IsA("Model") or directPreferred:IsA("BasePart")) then
                return directPreferred
            end

            local nestedPreferred = template:FindFirstChild(preferredModelName, true)
            if nestedPreferred and (nestedPreferred:IsA("Model") or nestedPreferred:IsA("BasePart")) then
                return nestedPreferred
            end
        end

        local directSameName = template:FindFirstChild(template.Name)
        if directSameName and (directSameName:IsA("Model") or directSameName:IsA("BasePart")) then
            return directSameName
        end

        local nestedSameName = template:FindFirstChild(template.Name, true)
        if nestedSameName and (nestedSameName:IsA("Model") or nestedSameName:IsA("BasePart")) then
            return nestedSameName
        end

        for _, child in ipairs(template:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                if not (child:IsA("BasePart") and child.Name == "Handle") then
                    return child
                end
            end
        end
    elseif template:IsA("Model") then
        return template
    elseif template:IsA("BasePart") then
        return nil
    end

    return nil
end

function BrainrotService:_attachToolVisual(tool, brainrotDefinition, handle)
    if not tool or not handle then
        return
    end

    local template = self:_getBrainrotModelTemplate(brainrotDefinition.ModelPath)
    if not template then
        return
    end

    local _qualityFolderName, preferredModelName = parseModelPath(brainrotDefinition.ModelPath)
    local visualSource = self:_findToolVisualSource(template, preferredModelName)
    if not visualSource then
        return
    end

    local targetVisualPivotCFrame = handle.CFrame
    if template:IsA("Tool") then
        local templateHandle = getTemplateToolHandlePart(template)
        local sourcePivotCFrame = getInstancePivotCFrame(visualSource)
        if templateHandle and sourcePivotCFrame then
            local relativeOffset = templateHandle.CFrame:ToObjectSpace(sourcePivotCFrame)
            targetVisualPivotCFrame = handle.CFrame * relativeOffset
        end
    end

    local visualClone = visualSource:Clone()
    visualClone.Name = "VisualModel"
    visualClone.Parent = tool

    if visualClone:IsA("Model") then
        local modelPrimary = visualClone.PrimaryPart or visualClone:FindFirstChildWhichIsA("BasePart", true)
        if modelPrimary then
            visualClone.PrimaryPart = modelPrimary
            visualClone:PivotTo(targetVisualPivotCFrame)
        end
    elseif visualClone:IsA("BasePart") then
        visualClone.CFrame = targetVisualPivotCFrame
    end

    local visualParts = {}

    if visualClone:IsA("BasePart") then
        table.insert(visualParts, visualClone)
    end

    for _, descendant in ipairs(visualClone:GetDescendants()) do
        if descendant:IsA("BasePart") then
            table.insert(visualParts, descendant)
        elseif descendant:IsA("ProximityPrompt") then
            descendant.Enabled = false
        elseif descendant:IsA("JointInstance") or descendant:IsA("Constraint") then
            descendant:Destroy()
        elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
            descendant.Disabled = true
        end
    end

    for _, visualPart in ipairs(visualParts) do
        setToolVisualPart(visualPart)
        if visualPart ~= handle then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = handle
            weld.Part1 = visualPart
            weld.Parent = visualPart
        end
    end
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
    self:_attachToolVisual(tool, brainrotDefinition, handle)

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
                self:_playIdleAnimationForPlaced(player, positionKey, placedModel, brainrotDefinition)
            end
        end
    end
end

function BrainrotService:_applyOfflineProduction(playerData, placedBrainrots, productionState)
    local meta = type(playerData.Meta) == "table" and playerData.Meta or nil
    if not meta then
        return
    end

    local lastLogoutAt = math.floor(tonumber(meta.LastLogoutAt) or 0)
    if lastLogoutAt <= 0 then
        return
    end

    local now = os.time()
    local elapsed = now - lastLogoutAt
    if elapsed <= 0 then
        meta.LastLogoutAt = 0
        return
    end

    local capSeconds = math.max(0, math.floor(tonumber(GameConfig.BRAINROT.OfflineProductionCapSeconds) or 3600))
    local effectiveSeconds = math.min(elapsed, capSeconds)
    if effectiveSeconds <= 0 then
        meta.LastLogoutAt = 0
        return
    end

    for positionKey, placedData in pairs(placedBrainrots) do
        local brainrotId = tonumber(placedData.BrainrotId)
        local brainrotDefinition = brainrotId and BrainrotConfig.ById[brainrotId] or nil
        if brainrotDefinition then
            local coinPerSecond = math.max(0, math.floor(tonumber(brainrotDefinition.CoinPerSecond) or 0))
            if coinPerSecond > 0 then
                local slot = self:_getOrCreateProductionSlot(productionState, positionKey)
                slot.OfflineGold += coinPerSecond * effectiveSeconds
            end
        end
    end

    meta.LastLogoutAt = 0
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
                qualityName = select(1, resolveQualityDisplayInfo(brainrotDefinition.Quality)),
                rarity = brainrotDefinition.Rarity,
                rarityName = select(1, resolveRarityDisplayInfo(brainrotDefinition.Rarity)),
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

    local totalBaseSpeed, totalMultiplier, totalFinalSpeed = self:_updatePlayerTotalProductionSpeed(player, placedBrainrots)

    self._brainrotStateSyncEvent:FireClient(player, {
        inventory = inventoryPayload,
        placed = placedPayload,
        equippedInstanceId = tonumber(brainrotData.EquippedInstanceId) or 0,
        totalProductionBaseSpeed = totalBaseSpeed,
        totalProductionMultiplier = totalMultiplier,
        totalProductionSpeed = totalFinalSpeed,
    })
end

function BrainrotService:_tickProduction()
    for _, player in ipairs(Players:GetPlayers()) do
        local playerData, _brainrotData, placedBrainrots, productionState = self:_getOrCreateDataContainers(player)
        if playerData and type(placedBrainrots) == "table" and type(productionState) == "table" then
            local changedPositions = {}
            local bonusMultiplier = select(1, self:_resolveProductionMultiplier(player))

            for positionKey, placedData in pairs(placedBrainrots) do
                local brainrotId = tonumber(placedData.BrainrotId)
                local brainrotDefinition = brainrotId and BrainrotConfig.ById[brainrotId] or nil
                if brainrotDefinition then
                    local coinPerSecond = math.max(0, math.floor(tonumber(brainrotDefinition.CoinPerSecond) or 0))
                    if coinPerSecond > 0 then
                        local slot = self:_getOrCreateProductionSlot(productionState, positionKey)
                        local producedExact = (coinPerSecond * bonusMultiplier) + slot.FriendBonusRemainder
                        local producedWhole = math.floor(producedExact)
                        slot.FriendBonusRemainder = producedExact - producedWhole
                        if producedWhole > 0 then
                            slot.CurrentGold += producedWhole
                            changedPositions[positionKey] = true
                        end
                    end
                end
            end

            for positionKey in pairs(changedPositions) do
                self:_refreshClaimUiForPosition(player, positionKey, placedBrainrots, productionState)
            end

            self:_updatePlayerTotalProductionSpeed(player, placedBrainrots)
        end
    end
end

function BrainrotService:OnPlayerReady(player, assignedHome)
    local playerData, brainrotData, placedBrainrots, productionState = self:_getOrCreateDataContainers(player)
    if not playerData or not brainrotData or not placedBrainrots or not productionState then
        return
    end

    self:_ensureStarterInventory(playerData, brainrotData, placedBrainrots)

    local targetHome = assignedHome or self._homeService:GetAssignedHome(player)
    if targetHome then
        self:_bindHomePrompts(player, targetHome)
        self:_bindHomeClaims(player, targetHome)
    else
        self:_clearPromptConnections(player)
        self:_clearClaimConnections(player)
    end

    self:_restorePlacedFromData(player)
    self:_applyOfflineProduction(playerData, placedBrainrots, productionState)
    self:_refreshBrainrotTools(player)
    self:PushBrainrotState(player)
    self:_refreshAllClaimUi(player, placedBrainrots, productionState)
    self:_refreshAllPlatformPrompts(player, placedBrainrots)
    self:_updatePlayerTotalProductionSpeed(player, placedBrainrots)
end

function BrainrotService:OnPlayerRemoving(player)
    self:_clearPromptConnections(player)
    self:_clearClaimConnections(player)
    self:_clearToolConnections(player)
    self:_clearRuntimePlaced(player)

    player:SetAttribute("TotalProductionSpeedBase", nil)
    player:SetAttribute("TotalProductionBonusRate", nil)
    player:SetAttribute("TotalProductionMultiplier", nil)
    player:SetAttribute("TotalProductionSpeed", nil)
end

function BrainrotService:Init(dependencies)
    self._playerDataService = dependencies.PlayerDataService
    self._homeService = dependencies.HomeService
    self._currencyService = dependencies.CurrencyService
    self._friendBonusService = dependencies.FriendBonusService
    self._remoteEventService = dependencies.RemoteEventService

    self._brainrotStateSyncEvent = self._remoteEventService:GetEvent("BrainrotStateSync")
    self._requestBrainrotStateSyncEvent = self._remoteEventService:GetEvent("RequestBrainrotStateSync")
    self._claimCashFeedbackEvent = self._remoteEventService:GetEvent("ClaimCashFeedback")

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

local function shouldUseSingleAnchorForAnimation(instance)
    if not instance then
        return false
    end

    -- 只要存在可动画骨架（Motor6D/Bone），就允许单锚点。
    -- 这样 Humanoid 与 AnimationController 两种动画路径都能正常驱动。
    local hasAnyBasePart = instance:FindFirstChildWhichIsA("BasePart", true) ~= nil
    if not hasAnyBasePart then
        return false
    end

    local hasMotor6D = false
    local hasBone = false
    for _, descendant in ipairs(instance:GetDescendants()) do
        if not hasMotor6D and descendant:IsA("Motor6D") then
            hasMotor6D = true
        end
        if not hasBone and descendant:IsA("Bone") then
            hasBone = true
        end

        if hasMotor6D and hasBone then
            break
        end
    end

    return hasMotor6D or hasBone
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

    if placedInstance:IsA("Tool") then
        local _qualityFolderName, preferredModelName = parseModelPath(brainrotDefinition.ModelPath)
        local pivotCFrame, pivotPart = getToolPivotCFrame(placedInstance, preferredModelName)
        if not pivotCFrame then
            placedInstance:Destroy()
            warn(string.format("[BrainrotService] Tool 模型缺少有效轴点（子Model/Handle/BasePart）: %s", tostring(brainrotDefinition.ModelPath)))
            return nil
        end

        local baseParts = {}
        for _, descendant in ipairs(placedInstance:GetDescendants()) do
            if descendant:IsA("BasePart") then
                table.insert(baseParts, descendant)
            elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
                descendant.Disabled = true
            end
        end

        if #baseParts == 0 then
            placedInstance:Destroy()
            warn(string.format("[BrainrotService] Tool 模型内无可放置 BasePart: %s", tostring(brainrotDefinition.ModelPath)))
            return nil
        end

        local deltaCFrame = targetCFrame * pivotCFrame:Inverse()
        for _, basePart in ipairs(baseParts) do
            basePart.CFrame = deltaCFrame * basePart.CFrame
        end

        local anchorPart = nil
        if pivotPart and pivotPart:IsA("BasePart") then
            anchorPart = pivotPart
        end
        if not anchorPart then
            local humanoidRootPart = placedInstance:FindFirstChild("HumanoidRootPart", true)
            if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
                anchorPart = humanoidRootPart
            end
        end
        if not anchorPart then
            local rootPart = placedInstance:FindFirstChild("RootPart", true)
            if rootPart and rootPart:IsA("BasePart") then
                anchorPart = rootPart
            end
        end
        if not anchorPart then
            local handle = placedInstance:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                anchorPart = handle
            end
        end
        if not anchorPart then
            anchorPart = baseParts[1]
        end

        local useSingleAnchor = shouldUseSingleAnchorForAnimation(placedInstance)
        for _, basePart in ipairs(baseParts) do
            basePart.CanCollide = false
            basePart.Anchored = not useSingleAnchor or (basePart == anchorPart)
        end
    elseif placedInstance:IsA("Model") then
        local primaryPart = placedInstance.PrimaryPart or placedInstance:FindFirstChildWhichIsA("BasePart", true)
        if not primaryPart then
            placedInstance:Destroy()
            warn(string.format("[BrainrotService] 脑红模型缺少 BasePart: %s", tostring(brainrotDefinition.ModelPath)))
            return nil
        end

        -- 优先使用 HumanoidRootPart/RootPart 作为锚点，避免锚在头部等节点导致模型跑偏看不见。
        local humanoidRootPart = placedInstance:FindFirstChild("HumanoidRootPart", true)
        if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
            primaryPart = humanoidRootPart
        else
            local rootPart = placedInstance:FindFirstChild("RootPart", true)
            if rootPart and rootPart:IsA("BasePart") then
                primaryPart = rootPart
            end
        end
        placedInstance.PrimaryPart = primaryPart

        local useSingleAnchor = shouldUseSingleAnchorForAnimation(placedInstance)
        for _, descendant in ipairs(placedInstance:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.CanCollide = false
                descendant.Anchored = not useSingleAnchor or (descendant == primaryPart)
            elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
                descendant.Disabled = true
            end
        end

        placedInstance:PivotTo(targetCFrame)
    elseif placedInstance:IsA("BasePart") then
        placedInstance.Anchored = true
        placedInstance.CanCollide = false
        placedInstance.CFrame = targetCFrame
        for _, descendant in ipairs(placedInstance:GetDescendants()) do
            if descendant:IsA("Script") or descendant:IsA("LocalScript") then
                descendant.Disabled = true
            end
        end
    else
        placedInstance:Destroy()
        warn(string.format("[BrainrotService] 不支持放置的脑红实例类型: %s", placedInstance.ClassName))
        return nil
    end

    placedInstance.Name = string.format("PlacedBrainrot_%d", brainrotDefinition.Id)
    placedInstance.Parent = runtimeFolder

    self:_attachPlacedInfoUi(placedInstance, brainrotDefinition)

    return placedInstance
end

function BrainrotService:_placeEquippedBrainrot(player, platformInfo)
    local playerData, brainrotData, placedBrainrots, productionState = self:_getOrCreateDataContainers(player)
    if not playerData or not brainrotData or not placedBrainrots or not productionState then
        return
    end

    local positionKey = platformInfo.PositionKey
    local existingPlaced = placedBrainrots[positionKey]
    if existingPlaced then
        local runtimePlaced = self._runtimePlacedByUserId[player.UserId]
        local runtimeInstance = runtimePlaced and runtimePlaced[positionKey] or nil
        if runtimeInstance and runtimeInstance.Parent then
            self:_refreshPlatformPromptState(player, positionKey, placedBrainrots)
            return
        end

        local existingBrainrotId = tonumber(existingPlaced.BrainrotId)
        local existingDefinition = existingBrainrotId and BrainrotConfig.ById[existingBrainrotId] or nil
        if existingDefinition then
            local recoveredModel = self:_createPlacedModel(platformInfo.Attachment, existingDefinition)
            if recoveredModel then
                runtimePlaced = ensureTable(self._runtimePlacedByUserId, player.UserId)
                runtimePlaced[positionKey] = recoveredModel
                self:_playIdleAnimationForPlaced(player, positionKey, recoveredModel, existingDefinition)
                self:_refreshClaimUiForPosition(player, positionKey, placedBrainrots, productionState)
                self:_refreshPlatformPromptState(player, positionKey, placedBrainrots)
                return
            end
        end

        -- 兜底：旧脏数据阻塞放置时，自动清理占位，避免永远无法放置
        placedBrainrots[positionKey] = nil
        local staleSlot = self:_getOrCreateProductionSlot(productionState, positionKey)
        staleSlot.CurrentGold = 0
        staleSlot.OfflineGold = 0
        staleSlot.FriendBonusRemainder = 0
        self:_refreshPlatformPromptState(player, positionKey, placedBrainrots)
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

    local slot = self:_getOrCreateProductionSlot(productionState, positionKey)
    slot.CurrentGold = 0
    slot.OfflineGold = 0
    slot.FriendBonusRemainder = 0

    local runtimePlaced = ensureTable(self._runtimePlacedByUserId, player.UserId)
    runtimePlaced[positionKey] = placedModel
    self:_playIdleAnimationForPlaced(player, positionKey, placedModel, brainrotDefinition)

    equippedTool:Destroy()
    self:PushBrainrotState(player)
    self:_refreshClaimUiForPosition(player, positionKey, placedBrainrots, productionState)
    self:_refreshPlatformPromptState(player, positionKey, placedBrainrots)
    self:_updatePlayerTotalProductionSpeed(player, placedBrainrots)
end

function BrainrotService:_clearClaimBounceState(userId, positionKey, restoreToBase)
    local claimBounceByPosition = self._claimBounceStateByUserId[userId]
    if type(claimBounceByPosition) ~= "table" then
        return
    end

    local state = claimBounceByPosition[positionKey]
    if type(state) ~= "table" then
        return
    end

    claimBounceByPosition[positionKey] = nil

    if state.CurrentTween then
        state.CurrentTween:Cancel()
        state.CurrentTween = nil
    end

    if state.Connection then
        state.Connection:Disconnect()
        state.Connection = nil
    end

    if restoreToBase and state.Target and state.Target.Parent and state.BasePivot then
        setInstancePivotCFrame(state.Target, state.BasePivot)
    end

    if state.PivotValue then
        state.PivotValue:Destroy()
        state.PivotValue = nil
    end
end

function BrainrotService:_getClaimTouchEffectTemplate()
    local rootName = tostring(GameConfig.BRAINROT.ClaimTouchEffectRootName or "Effect")
    local claimFolderName = tostring(GameConfig.BRAINROT.ClaimTouchEffectFolderName or "Claim")

    local effectRoot = ReplicatedStorage:FindFirstChild(rootName)
    local claimFolder = effectRoot and effectRoot:FindFirstChild(claimFolderName) or nil
    if claimFolder then
        return claimFolder
    end

    if not self._didWarnMissingClaimEffectTemplate then
        warn(string.format("[BrainrotService] 找不到领取特效模板目录: ReplicatedStorage/%s/%s", rootName, claimFolderName))
        self._didWarnMissingClaimEffectTemplate = true
    end

    return nil
end

function BrainrotService:_destroyClaimTouchEffectForPosition(userId, positionKey)
    local claimEffectByPosition = self._claimEffectByUserId[userId]
    if type(claimEffectByPosition) ~= "table" then
        return
    end

    local runtimeNodes = claimEffectByPosition[positionKey]
    if type(runtimeNodes) == "table" then
        for _, node in pairs(runtimeNodes) do
            if node and node.Parent then
                node:Destroy()
            end
        end
    elseif runtimeNodes and runtimeNodes.Parent then
        runtimeNodes:Destroy()
    end

    claimEffectByPosition[positionKey] = nil
end

function BrainrotService:_playClaimPressAnimation(claimInfo)
    local pressPart = claimInfo and (claimInfo.TouchPart or claimInfo.ClaimPart)
    if not (pressPart and pressPart.Parent and pressPart:IsA("BasePart")) then
        return
    end

    local isTouchPart = claimInfo and claimInfo.TouchPart == pressPart
    local baseCFrame = nil
    if isTouchPart then
        baseCFrame = claimInfo.TouchBaseCFrame or pressPart.CFrame
        claimInfo.TouchBaseCFrame = baseCFrame
    else
        baseCFrame = claimInfo.ClaimBaseCFrame or pressPart.CFrame
        claimInfo.ClaimBaseCFrame = baseCFrame
    end

    claimInfo._pressAnimationToken = (tonumber(claimInfo._pressAnimationToken) or 0) + 1
    local currentToken = claimInfo._pressAnimationToken

    if claimInfo._currentPressTween then
        claimInfo._currentPressTween:Cancel()
        claimInfo._currentPressTween = nil
    end

    if claimInfo._touchHighlightTween then
        claimInfo._touchHighlightTween:Cancel()
        claimInfo._touchHighlightTween = nil
    end

    if claimInfo._touchHighlight then
        claimInfo._touchHighlight:Destroy()
        claimInfo._touchHighlight = nil
    end

    local highlight = nil
    if isTouchPart and GameConfig.BRAINROT.ClaimTouchHighlightEnabled ~= false then
        highlight = Instance.new("Highlight")
        highlight.Name = "ClaimTouchHighlight"
        highlight.Adornee = pressPart
        highlight.DepthMode = GameConfig.BRAINROT.ClaimTouchHighlightAlwaysOnTop == true
            and Enum.HighlightDepthMode.AlwaysOnTop
            or Enum.HighlightDepthMode.Occluded
        highlight.FillColor = GameConfig.BRAINROT.ClaimTouchHighlightFillColor or Color3.fromRGB(255, 235, 130)
        highlight.FillTransparency = math.clamp(tonumber(GameConfig.BRAINROT.ClaimTouchHighlightFillTransparency) or 0.55, 0, 1)
        highlight.OutlineColor = GameConfig.BRAINROT.ClaimTouchHighlightOutlineColor or Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = math.clamp(tonumber(GameConfig.BRAINROT.ClaimTouchHighlightOutlineTransparency) or 0.08, 0, 1)
        highlight.Parent = pressPart
        claimInfo._touchHighlight = highlight
    end

    pressPart.CFrame = baseCFrame

    local pressOffset = math.max(0.05, tonumber(GameConfig.BRAINROT.ClaimPressOffsetY) or 0.2)
    local downDuration = math.max(0.03, tonumber(GameConfig.BRAINROT.ClaimPressDownDuration) or 0.08)
    local upDuration = math.max(0.03, tonumber(GameConfig.BRAINROT.ClaimPressUpDuration) or 0.14)

    local downTween = TweenService:Create(pressPart, TweenInfo.new(downDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = baseCFrame * CFrame.new(0, -pressOffset, 0),
    })
    claimInfo._currentPressTween = downTween
    downTween:Play()

    task.spawn(function()
        downTween.Completed:Wait()
        if claimInfo._pressAnimationToken ~= currentToken then
            return
        end

        local upTween = TweenService:Create(pressPart, TweenInfo.new(upDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            CFrame = baseCFrame,
        })
        claimInfo._currentPressTween = upTween
        upTween:Play()
        upTween.Completed:Wait()

        if claimInfo._pressAnimationToken ~= currentToken then
            return
        end

        claimInfo._currentPressTween = nil
        if pressPart.Parent then
            pressPart.CFrame = baseCFrame
        end

        local activeHighlight = claimInfo._touchHighlight
        if activeHighlight and activeHighlight.Parent then
            local fadeOutDuration = math.max(0.03, tonumber(GameConfig.BRAINROT.ClaimTouchHighlightFadeOutDuration) or 0.12)
            local fadeTween = TweenService:Create(activeHighlight, TweenInfo.new(fadeOutDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                FillTransparency = 1,
                OutlineTransparency = 1,
            })
            claimInfo._touchHighlightTween = fadeTween
            fadeTween:Play()
            fadeTween.Completed:Wait()

            if claimInfo._touchHighlightTween == fadeTween then
                claimInfo._touchHighlightTween = nil
            end
        end

        if claimInfo._touchHighlight == activeHighlight then
            claimInfo._touchHighlight = nil
        end
        if activeHighlight and activeHighlight.Parent then
            activeHighlight:Destroy()
        end
    end)
end

function BrainrotService:_playClaimBounceAnimation(player, positionKey)
    local userId = player.UserId
    local runtimePlaced = self._runtimePlacedByUserId[userId]
    if type(runtimePlaced) ~= "table" then
        return
    end

    local target = runtimePlaced[positionKey]
    if not target then
        return
    end

    self:_clearClaimBounceState(userId, positionKey, true)

    local basePivot = select(1, getInstancePivotCFrame(target))
    if not basePivot then
        return
    end

    local claimBounceByPosition = ensureTable(self._claimBounceStateByUserId, userId)
    local state = {
        Target = target,
        BasePivot = basePivot,
        CurrentTween = nil,
        Connection = nil,
        PivotValue = nil,
    }
    claimBounceByPosition[positionKey] = state

    local pivotValue = Instance.new("CFrameValue")
    pivotValue.Value = basePivot
    state.PivotValue = pivotValue
    state.Connection = pivotValue:GetPropertyChangedSignal("Value"):Connect(function()
        if state.Target and state.Target.Parent then
            setInstancePivotCFrame(state.Target, pivotValue.Value)
        end
    end)

    local bounceOffset = math.max(0.05, tonumber(GameConfig.BRAINROT.ClaimBrainrotBounceOffsetY) or 0.75)
    local upDuration = math.max(0.03, tonumber(GameConfig.BRAINROT.ClaimBrainrotBounceUpDuration) or 0.1)
    local downDuration = math.max(0.03, tonumber(GameConfig.BRAINROT.ClaimBrainrotBounceDownDuration) or 0.18)

    local upTween = TweenService:Create(pivotValue, TweenInfo.new(upDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Value = basePivot * CFrame.new(0, bounceOffset, 0),
    })
    state.CurrentTween = upTween
    upTween:Play()

    task.spawn(function()
        upTween.Completed:Wait()
        local activeByPosition = self._claimBounceStateByUserId[userId]
        if not (activeByPosition and activeByPosition[positionKey] == state) then
            return
        end

        local downTween = TweenService:Create(pivotValue, TweenInfo.new(downDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Value = basePivot,
        })
        state.CurrentTween = downTween
        downTween:Play()
        downTween.Completed:Wait()

        local latestByPosition = self._claimBounceStateByUserId[userId]
        if latestByPosition and latestByPosition[positionKey] == state then
            self:_clearClaimBounceState(userId, positionKey, true)
        end
    end)
end

function BrainrotService:_playClaimTouchEffect(player, claimInfo)
    local effectAnchorPart = claimInfo and claimInfo.TouchPart
    if not (effectAnchorPart and effectAnchorPart.Parent and effectAnchorPart:IsA("BasePart") and claimInfo and claimInfo.PositionKey) then
        return
    end

    local userId = player.UserId
    local positionKey = tostring(claimInfo.PositionKey)
    self:_destroyClaimTouchEffectForPosition(userId, positionKey)

    local templateFolder = self:_getClaimTouchEffectTemplate()
    if not templateFolder then
        return
    end

    local claimEffectByPosition = ensureTable(self._claimEffectByUserId, userId)
    local runtimeNodes = {}
    claimEffectByPosition[positionKey] = runtimeNodes

    local function trackRuntimeNode(node)
        if node then
            table.insert(runtimeNodes, node)
        end
        return node
    end

    local function findTemplateEmitter(emitterName)
        local direct = templateFolder:FindFirstChild(emitterName)
        if direct and direct:IsA("ParticleEmitter") then
            return direct
        end

        local nested = templateFolder:FindFirstChild(emitterName, true)
        if nested and nested:IsA("ParticleEmitter") then
            return nested
        end

        return nil
    end

    local function cloneEmitterToTouch(emitterName)
        local templateEmitter = findTemplateEmitter(emitterName)
        if not templateEmitter then
            return nil
        end

        local emitter = templateEmitter:Clone()
        emitter.Enabled = false
        emitter.Parent = effectAnchorPart
        return trackRuntimeNode(emitter)
    end

    local function destroyIfCurrent(emitter)
        local latestByPosition = self._claimEffectByUserId[userId]
        if not (latestByPosition and latestByPosition[positionKey] == runtimeNodes) then
            return
        end

        if emitter and emitter.Parent then
            emitter:Destroy()
        end
    end

    local function emitOnceAndDestroyByLifetime(emitter)
        if not (emitter and emitter:IsA("ParticleEmitter")) then
            return
        end

        emitter:Emit(1)
        emitter.Enabled = false

        local maxLifetime = 0.05
        if emitter.Lifetime then
            maxLifetime = math.max(maxLifetime, tonumber(emitter.Lifetime.Max) or 0)
        end

        task.delay(maxLifetime + 0.03, function()
            destroyIfCurrent(emitter)
        end)
    end

    local function playTimedEmitter(emitter, duration)
        if not (emitter and emitter:IsA("ParticleEmitter")) then
            return
        end

        local lifetime = math.max(0.05, tonumber(duration) or 1.5)
        emitter.Enabled = true

        task.delay(lifetime, function()
            if emitter and emitter.Parent then
                emitter.Enabled = false
            end
            destroyIfCurrent(emitter)
        end)
    end

    local glowName = tostring(GameConfig.BRAINROT.ClaimTouchEffectGlowName or "Glow")
    local smokeName = tostring(GameConfig.BRAINROT.ClaimTouchEffectSmokeName or "Smoke")
    local moneyName = tostring(GameConfig.BRAINROT.ClaimTouchEffectMoneyName or "Money")
    local starsName = tostring(GameConfig.BRAINROT.ClaimTouchEffectStarsName or "Stars")
    local moneyStarsLifetime = math.max(0.1, tonumber(GameConfig.BRAINROT.ClaimTouchEffectMoneyStarsLifetime) or 1.5)

    emitOnceAndDestroyByLifetime(cloneEmitterToTouch(glowName))
    emitOnceAndDestroyByLifetime(cloneEmitterToTouch(smokeName))
    playTimedEmitter(cloneEmitterToTouch(moneyName), moneyStarsLifetime)
    playTimedEmitter(cloneEmitterToTouch(starsName), moneyStarsLifetime)

    task.delay(moneyStarsLifetime + 0.2, function()
        local latestByPosition = self._claimEffectByUserId[userId]
        if latestByPosition and latestByPosition[positionKey] == runtimeNodes then
            latestByPosition[positionKey] = nil
        end
    end)
end
function BrainrotService:_pushClaimCashFeedback(player, claimInfo)
    if not self._claimCashFeedbackEvent then
        return
    end

    local touchPart = claimInfo and claimInfo.TouchPart
    local touchPosition = (touchPart and touchPart.Parent and touchPart:IsA("BasePart")) and touchPart.Position or nil
    local touchUpVector = (touchPart and touchPart.Parent and touchPart:IsA("BasePart")) and touchPart.CFrame.UpVector or Vector3.new(0, 1, 0)
    local touchSize = (touchPart and touchPart.Parent and touchPart:IsA("BasePart")) and touchPart.Size or nil

    self._claimCashFeedbackEvent:FireClient(player, {
        positionKey = claimInfo and claimInfo.PositionKey or nil,
        claimKey = claimInfo and claimInfo.ClaimKey or nil,
        touchPosition = touchPosition,
        touchUpVector = touchUpVector,
        touchSize = touchSize,
        timestamp = os.clock(),
    })
end

function BrainrotService:_playClaimFeedback(player, claimInfo)
    self:_playClaimPressAnimation(claimInfo)
    self:_playClaimBounceAnimation(player, claimInfo.PositionKey)
    self:_playClaimTouchEffect(player, claimInfo)
    self:_pushClaimCashFeedback(player, claimInfo)
end

function BrainrotService:_shouldTriggerClaimByTouch(claimState, character, hitPart)
    if type(claimState.TouchingParts) ~= "table" then
        claimState.TouchingParts = {}
    end

    if not hitPart then
        return false
    end

    claimState.Character = character or claimState.Character

    if (tonumber(claimState.TouchingCount) or 0) > 0 then
        local triggerPart = claimState.TriggerPart
        local trackedCharacter = claimState.Character
        if triggerPart and trackedCharacter and not isCharacterOccupyingPart(trackedCharacter, triggerPart) then
            claimState.TouchingParts = {}
            claimState.TouchingCount = 0
            claimState.IsTriggeredWhileOccupied = false
        end
    end

    if claimState.TouchingParts[hitPart] then
        return false
    end

    claimState.TouchingParts[hitPart] = true
    claimState.TouchingCount = (tonumber(claimState.TouchingCount) or 0) + 1
    claimState.ReleaseMonitorToken = (tonumber(claimState.ReleaseMonitorToken) or 0) + 1

    -- 同一轮占用期间只允许触发一次，避免 Touch 按压动画导致的断触重触二次触发
    if claimState.IsTriggeredWhileOccupied == true then
        return false
    end

    local nowClock = os.clock()
    local lastClock = tonumber(claimState.LastTriggerClock) or 0
    local touchDebounce = math.max(0.05, tonumber(GameConfig.BRAINROT.ClaimTouchDebounceSeconds) or 0.35)
    if nowClock - lastClock < touchDebounce then
        return false
    end

    claimState.LastTriggerClock = nowClock
    claimState.IsTriggeredWhileOccupied = true
    return true
end

function BrainrotService:_handleClaimTouchEnded(claimState, hitPart)
    if type(claimState.TouchingParts) ~= "table" then
        claimState.TouchingParts = {}
    end

    if hitPart and claimState.TouchingParts[hitPart] then
        claimState.TouchingParts[hitPart] = nil
        claimState.TouchingCount = math.max(0, (tonumber(claimState.TouchingCount) or 0) - 1)
    end

    if (tonumber(claimState.TouchingCount) or 0) > 0 then
        return
    end

    claimState.TouchingParts = {}
    claimState.TouchingCount = 0

    local function unlockTrigger()
        claimState.IsTriggeredWhileOccupied = false
        claimState.LastTriggerClock = 0
    end

    local triggerPart = claimState.TriggerPart
    local character = claimState.Character
    if not (triggerPart and triggerPart.Parent and character and character.Parent) then
        unlockTrigger()
        return
    end

    local monitorToken = (tonumber(claimState.ReleaseMonitorToken) or 0) + 1
    claimState.ReleaseMonitorToken = monitorToken

    -- Touch 按压会短暂改变碰撞状态，这里增加“连续离开判定”，
    -- 避免站着不动时因瞬态抖动被误判离开并解锁二次触发。
    task.spawn(function()
        local missingOccupancyTicks = 0
        local requiredMissingTicks = 2

        while claimState.ReleaseMonitorToken == monitorToken do
            if (tonumber(claimState.TouchingCount) or 0) > 0 then
                return
            end

            local currentTriggerPart = claimState.TriggerPart
            local currentCharacter = claimState.Character
            if not (currentTriggerPart and currentTriggerPart.Parent and currentCharacter and currentCharacter.Parent) then
                unlockTrigger()
                return
            end

            if isCharacterOccupyingPart(currentCharacter, currentTriggerPart) then
                missingOccupancyTicks = 0
            else
                missingOccupancyTicks = missingOccupancyTicks + 1
                if missingOccupancyTicks >= requiredMissingTicks then
                    unlockTrigger()
                    return
                end
            end

            task.wait(0.05)
        end
    end)
end

function BrainrotService:_claimPositionGold(player, positionKey)
    local playerData, _brainrotData, placedBrainrots, productionState = self:_getOrCreateDataContainers(player)
    if not playerData or not placedBrainrots or not productionState then
        return false, 0
    end

    if not placedBrainrots[positionKey] then
        self:_refreshClaimUiForPosition(player, positionKey, placedBrainrots, productionState)
        return false, 0
    end

    local slot = self:_getOrCreateProductionSlot(productionState, positionKey)
    local currentGold = slot.CurrentGold
    local offlineGold = slot.OfflineGold
    local claimAmount = currentGold + offlineGold
    if claimAmount <= 0 then
        return false, 0
    end

    slot.CurrentGold = 0
    slot.OfflineGold = 0

    local success = self._currencyService and self._currencyService:AddCoins(player, claimAmount, "BrainrotClaim")
    if not success then
        slot.CurrentGold = currentGold
        slot.OfflineGold = offlineGold
        return false, 0
    end

    self:_refreshClaimUiForPosition(player, positionKey, placedBrainrots, productionState)
    return true, claimAmount
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

function BrainrotService:_bindHomeClaims(player, homeModel)
    self:_clearClaimConnections(player)
    local userId = player.UserId

    local claimsByPositionKey = self:_scanHomeClaims(homeModel)
    self._claimsByUserId[userId] = claimsByPositionKey

    local connectionList = {}
    self._claimConnectionsByUserId[userId] = connectionList

    local claimStateByClaimKey = ensureTable(self._claimTouchDebounceByUserId, userId)

    for _, claimInfo in pairs(claimsByPositionKey) do
        local triggerPart = claimInfo.TouchPart
        if not (triggerPart and triggerPart:IsA("BasePart")) then
            warn(string.format("[BrainrotService] Claim 触碰节点缺失，已跳过: %s（需要 Touch/BasePart）", tostring(claimInfo and claimInfo.ClaimKey or "Unknown")))
            continue
        end

        local claimKey = tostring(claimInfo.ClaimKey)
        local claimState = ensureTable(claimStateByClaimKey, claimKey)
        if type(claimState.TouchingParts) ~= "table" then
            claimState.TouchingParts = {}
        end
        claimState.TouchingCount = tonumber(claimState.TouchingCount) or 0
        claimState.LastTriggerClock = tonumber(claimState.LastTriggerClock) or 0
        claimState.IsTriggeredWhileOccupied = claimState.IsTriggeredWhileOccupied == true
        claimState.ReleaseMonitorToken = tonumber(claimState.ReleaseMonitorToken) or 0
        claimState.TriggerPart = triggerPart
        claimState.Character = player.Character

        table.insert(connectionList, triggerPart.Touched:Connect(function(hitPart)
            local character = hitPart and hitPart.Parent
            if not character then
                return
            end

            local touchedPlayer = Players:GetPlayerFromCharacter(character)
            if touchedPlayer ~= player then
                return
            end

            if not self:_shouldTriggerClaimByTouch(claimState, character, hitPart) then
                return
            end

            self:_playClaimFeedback(player, claimInfo)
            self:_claimPositionGold(player, claimInfo.PositionKey)
        end))

        table.insert(connectionList, triggerPart.TouchEnded:Connect(function(hitPart)
            local character = hitPart and hitPart.Parent
            if not character then
                return
            end

            local touchedPlayer = Players:GetPlayerFromCharacter(character)
            if touchedPlayer ~= player then
                return
            end

            self:_handleClaimTouchEnded(claimState, hitPart)
        end))
    end
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

    local attachmentName = tostring(GameConfig.BRAINROT.PlatformAttachmentName or "BrainrotAttachment")
    local triggerName = tostring(GameConfig.BRAINROT.PlatformTriggerName or "Trigger")

    for _, descendant in ipairs(homeBase:GetDescendants()) do
        if isPlatformPart(descendant) then
            local positionRoot = descendant.Parent

            local attachment = descendant:FindFirstChild(attachmentName)
            if attachment and not attachment:IsA("Attachment") then
                attachment = nil
            end
            if not attachment then
                attachment = descendant:FindFirstChild(attachmentName, true)
                if attachment and not attachment:IsA("Attachment") then
                    attachment = nil
                end
                if not attachment then
                    attachment = positionRoot and positionRoot:FindFirstChild(attachmentName, true) or nil
                end
                if attachment and not attachment:IsA("Attachment") then
                    attachment = nil
                end

                if not attachment then
                    local fallbackAttachment = descendant:FindFirstChild("Attachment", true)
                    if fallbackAttachment and fallbackAttachment:IsA("Attachment") then
                        attachment = fallbackAttachment
                    end
                end

                if not attachment and positionRoot then
                    local fallbackAttachment = positionRoot:FindFirstChild("Attachment", true)
                    if fallbackAttachment and fallbackAttachment:IsA("Attachment") then
                        attachment = fallbackAttachment
                    end
                end
            end

            local triggerNode = descendant:FindFirstChild(triggerName)
            local proximityPrompt = nil
            if triggerNode then
                local triggerPrompt = triggerNode:FindFirstChild("ProximityPrompt", true)
                if triggerPrompt and triggerPrompt:IsA("ProximityPrompt") then
                    proximityPrompt = triggerPrompt
                else
                    local directTriggerPrompt = triggerNode:FindFirstChildOfClass("ProximityPrompt")
                    if directTriggerPrompt then
                        proximityPrompt = directTriggerPrompt
                    end
                end
            end

            if not proximityPrompt then
                local platformPrompt = descendant:FindFirstChild("ProximityPrompt", true)
                if platformPrompt and platformPrompt:IsA("ProximityPrompt") then
                    proximityPrompt = platformPrompt
                else
                    local directPlatformPrompt = descendant:FindFirstChildOfClass("ProximityPrompt")
                    if directPlatformPrompt then
                        proximityPrompt = directPlatformPrompt
                    end
                end
            end

            if not proximityPrompt and positionRoot then
                local positionPrompt = positionRoot:FindFirstChild("ProximityPrompt", true)
                if positionPrompt and positionPrompt:IsA("ProximityPrompt") then
                    proximityPrompt = positionPrompt
                else
                    local directPositionPrompt = positionRoot:FindFirstChildOfClass("ProximityPrompt")
                    if directPositionPrompt then
                        proximityPrompt = directPositionPrompt
                    end
                end
            end

            if attachment and proximityPrompt then
                local positionKey = self:_buildPositionKey(descendant)
                platforms[positionKey] = {
                    PositionKey = positionKey,
                    Platform = descendant,
                    Attachment = attachment,
                    Prompt = proximityPrompt,
                }
            else
                warn(string.format(
                    "[BrainrotService] Platform missing nodes, skipped: %s (Attachment=%s, Trigger=%s, Prompt=%s)",
                    descendant:GetFullName(),
                    tostring(attachment ~= nil),
                    tostring(triggerNode ~= nil),
                    tostring(proximityPrompt ~= nil)
                ))
            end
        end
    end

    if next(platforms) == nil then
        warn(string.format(
            "[BrainrotService] No valid platforms scanned under: %s",
            homeBase:GetFullName()
        ))
    end

    return platforms
end
function BrainrotService:_scanHomeClaims(homeModel)
    local claimsByPositionKey = {}
    local homeBase = homeModel and homeModel:FindFirstChild(GameConfig.HOME.HomeBaseName)
    if not homeBase then
        return claimsByPositionKey
    end

    local claimPrefix = tostring(GameConfig.BRAINROT.ClaimPrefix or "Claim")
    local positionPrefix = tostring(GameConfig.BRAINROT.PositionPrefix or "Position")
    local goldInfoGuiName = tostring(GameConfig.BRAINROT.GoldInfoGuiName or "GoldInfo")
    local currentGoldLabelName = tostring(GameConfig.BRAINROT.CurrentGoldLabelName or "CurrentGold")
    local offlineGoldLabelName = tostring(GameConfig.BRAINROT.OfflineGoldLabelName or "OfflineGold")

    for _, descendant in ipairs(homeBase:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local claimIndex = parseTrailingIndex(descendant.Name, claimPrefix)
            if claimIndex then
                local positionKey = string.format("%s%d", positionPrefix, claimIndex)

                local goldInfoGui = descendant:FindFirstChild(goldInfoGuiName)
                if not (goldInfoGui and goldInfoGui:IsA("BillboardGui")) then
                    goldInfoGui = nil
                end

                local currentGoldLabel = nil
                local offlineGoldLabel = nil
                if goldInfoGui then
                    local currentCandidate = goldInfoGui:FindFirstChild(currentGoldLabelName, true)
                    if currentCandidate and currentCandidate:IsA("TextLabel") then
                        currentGoldLabel = currentCandidate
                    end

                    local offlineCandidate = goldInfoGui:FindFirstChild(offlineGoldLabelName, true)
                    if offlineCandidate and offlineCandidate:IsA("TextLabel") then
                        offlineGoldLabel = offlineCandidate
                    end
                end

                local touchPart = descendant:FindFirstChild("Touch")
                if touchPart and not touchPart:IsA("BasePart") then
                    touchPart = nil
                end
                if not touchPart then
                    local touchCandidate = descendant:FindFirstChild("Touch", true)
                    if touchCandidate and touchCandidate:IsA("BasePart") then
                        touchPart = touchCandidate
                    end
                end

                claimsByPositionKey[positionKey] = {
                    PositionKey = positionKey,
                    ClaimPart = descendant,
                    TouchPart = touchPart,
                    ClaimKey = descendant.Name,
                    ClaimBaseCFrame = descendant.CFrame,
                    TouchBaseCFrame = touchPart and touchPart.CFrame or nil,
                    GoldInfoGui = goldInfoGui,
                    CurrentGoldLabel = currentGoldLabel,
                    OfflineGoldLabel = offlineGoldLabel,
                }
            end
        end
    end

    return claimsByPositionKey
end

function BrainrotService:_pulseLabel(label)
    local pulseScale = getOrCreatePulseScale(label)
    if not pulseScale then
        return
    end

    if pulseScale:GetAttribute("IsPulsing") then
        return
    end

    pulseScale:SetAttribute("IsPulsing", true)
    task.spawn(function()
        for _ = 1, 2 do
            local growTween = TweenService:Create(pulseScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Scale = 1.08,
            })
            local shrinkTween = TweenService:Create(pulseScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Scale = 1,
            })

            growTween:Play()
            growTween.Completed:Wait()
            shrinkTween:Play()
            shrinkTween.Completed:Wait()
        end

        pulseScale.Scale = 1
        pulseScale:SetAttribute("IsPulsing", false)
    end)
end

function BrainrotService:_applyClaimUi(claimInfo, enabled, currentGold, offlineGold)
    local previousCurrentGold = tonumber(claimInfo._lastCurrentGold) or 0
    local previousOfflineGold = tonumber(claimInfo._lastOfflineGold) or 0

    if claimInfo.GoldInfoGui then
        claimInfo.GoldInfoGui.Enabled = enabled
    end

    if claimInfo.CurrentGoldLabel then
        claimInfo.CurrentGoldLabel.Text = formatCurrentGoldText(currentGold)
        if enabled and currentGold ~= previousCurrentGold then
            self:_pulseLabel(claimInfo.CurrentGoldLabel)
        end
    end

    if claimInfo.OfflineGoldLabel then
        claimInfo.OfflineGoldLabel.Text = formatOfflineGoldText(offlineGold)
        claimInfo.OfflineGoldLabel.Visible = enabled and offlineGold > 0
        if enabled and offlineGold > 0 and offlineGold ~= previousOfflineGold then
            self:_pulseLabel(claimInfo.OfflineGoldLabel)
        end
    end

    claimInfo._lastCurrentGold = currentGold
    claimInfo._lastOfflineGold = offlineGold
end

function BrainrotService:_refreshClaimUiForPosition(player, positionKey, placedBrainrots, productionState)
    local claimsByPositionKey = self._claimsByUserId[player.UserId]
    local claimInfo = claimsByPositionKey and claimsByPositionKey[positionKey] or nil
    if not claimInfo then
        return
    end

    local resolvedPlaced = placedBrainrots
    local resolvedProduction = productionState
    if type(resolvedPlaced) ~= "table" or type(resolvedProduction) ~= "table" then
        local _playerData, _brainrotData
        _playerData, _brainrotData, resolvedPlaced, resolvedProduction = self:_getOrCreateDataContainers(player)
    end

    local hasPlaced = resolvedPlaced and resolvedPlaced[positionKey] ~= nil
    if not hasPlaced then
        self:_applyClaimUi(claimInfo, false, 0, 0)
        return
    end

    local slot = self:_getOrCreateProductionSlot(resolvedProduction, positionKey)
    self:_applyClaimUi(claimInfo, true, slot.CurrentGold, slot.OfflineGold)
end

function BrainrotService:_refreshAllClaimUi(player, placedBrainrots, productionState)
    local claimsByPositionKey = self._claimsByUserId[player.UserId]
    if type(claimsByPositionKey) ~= "table" then
        return
    end

    for positionKey in pairs(claimsByPositionKey) do
        self:_refreshClaimUiForPosition(player, positionKey, placedBrainrots, productionState)
    end
end

function BrainrotService:_refreshPlatformPromptState(player, positionKey, placedBrainrots)
    local platformsByPositionKey = self._platformsByUserId[player.UserId]
    if type(platformsByPositionKey) ~= "table" then
        return
    end

    local platformInfo = platformsByPositionKey[positionKey]
    if not platformInfo or not platformInfo.Prompt then
        return
    end

    local resolvedPlacedBrainrots = placedBrainrots
    if type(resolvedPlacedBrainrots) ~= "table" then
        local _playerData, _brainrotData
        _playerData, _brainrotData, resolvedPlacedBrainrots = self:_getOrCreateDataContainers(player)
    end

    local occupied = resolvedPlacedBrainrots and resolvedPlacedBrainrots[positionKey] ~= nil
    platformInfo.Prompt.Enabled = not occupied
end

function BrainrotService:_refreshAllPlatformPrompts(player, placedBrainrots)
    local platformsByPositionKey = self._platformsByUserId[player.UserId]
    if type(platformsByPositionKey) ~= "table" then
        return
    end

    for positionKey in pairs(platformsByPositionKey) do
        self:_refreshPlatformPromptState(player, positionKey, placedBrainrots)
    end
end

function BrainrotService:_stopIdleTrack(player, positionKey)
    local tracksByPosition = self._runtimeIdleTracksByUserId[player.UserId]
    if type(tracksByPosition) ~= "table" then
        return
    end

    local track = tracksByPosition[positionKey]
    if not track then
        return
    end

    pcall(function()
        track:Stop(0)
    end)
    pcall(function()
        track:Destroy()
    end)
    tracksByPosition[positionKey] = nil
end

function BrainrotService:_stopAllIdleTracks(player)
    local tracksByPosition = self._runtimeIdleTracksByUserId[player.UserId]
    if type(tracksByPosition) ~= "table" then
        return
    end

    for positionKey, track in pairs(tracksByPosition) do
        pcall(function()
            track:Stop(0)
        end)
        pcall(function()
            track:Destroy()
        end)
        tracksByPosition[positionKey] = nil
    end

    self._runtimeIdleTracksByUserId[player.UserId] = nil
end

function BrainrotService:_resolveIdleAnimationRoot(placedInstance, brainrotDefinition)
    if not placedInstance then
        return nil
    end

    if placedInstance:IsA("Tool") then
        local _folderName, preferredModelName = parseModelPath(brainrotDefinition.ModelPath)
        if preferredModelName and preferredModelName ~= "" then
            local preferredModel = placedInstance:FindFirstChild(preferredModelName, true)
            if preferredModel and preferredModel:IsA("Model") then
                return preferredModel
            end
        end

        local sameNameModel = placedInstance:FindFirstChild(placedInstance.Name, true)
        if sameNameModel and sameNameModel:IsA("Model") then
            return sameNameModel
        end

        local allModels = {}
        for _, descendant in ipairs(placedInstance:GetDescendants()) do
            if descendant:IsA("Model") then
                table.insert(allModels, descendant)
            end
        end

        local bestModel = nil
        local bestScore = -1

        for _, model in ipairs(allModels) do
            local score = 0
            if model:FindFirstChildWhichIsA("Humanoid", true) then
                score += 8
            end
            if model:FindFirstChildWhichIsA("AnimationController", true) then
                score += 6
            end
            if model:FindFirstChildWhichIsA("Motor6D", true) then
                score += 4
            end
            if model:FindFirstChildWhichIsA("Bone", true) then
                score += 2
            end
            if model:FindFirstChildWhichIsA("BasePart", true) then
                score += 1
            end

            if score > bestScore then
                bestScore = score
                bestModel = model
            end
        end

        return bestModel
    end

    if placedInstance:IsA("Model") then
        return placedInstance
    end

    return nil
end

function BrainrotService:_playIdleAnimationForPlaced(player, positionKey, placedInstance, brainrotDefinition)
    self:_stopIdleTrack(player, positionKey)

    if type(brainrotDefinition) ~= "table" then
        return
    end

    local animationId = normalizeAnimationId(brainrotDefinition.IdleAnimationId)
    if not animationId then
        return
    end

    local animationRoot = self:_resolveIdleAnimationRoot(placedInstance, brainrotDefinition)
    if not animationRoot then
        warn(string.format(
            "[BrainrotService] 待机动画播放失败：未找到动画根节点（BrainrotId=%s, ModelPath=%s）",
            tostring(brainrotDefinition.Id),
            tostring(brainrotDefinition.ModelPath)
        ))
        return
    end

    local animator = nil
    local humanoid = animationRoot:FindFirstChildWhichIsA("Humanoid", true)
    if humanoid then
        pcall(function()
            humanoid.PlatformStand = false
            if humanoid:GetState() == Enum.HumanoidStateType.Physics then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)

        animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
    else
        local animationController = animationRoot:FindFirstChildWhichIsA("AnimationController", true)
        if not animationController then
            animationController = Instance.new("AnimationController")
            animationController.Name = "BrainrotAnimationController"
            animationController.Parent = animationRoot
        end

        animator = animationController:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = animationController
        end
    end

    if not animator then
        warn(string.format(
            "[BrainrotService] 待机动画播放失败：未找到/创建 Animator（BrainrotId=%s）",
            tostring(brainrotDefinition.Id)
        ))
        return
    end

    local animation = Instance.new("Animation")
    animation.AnimationId = animationId

    local ok, trackOrError = pcall(function()
        return animator:LoadAnimation(animation)
    end)

    animation:Destroy()

    if ok and trackOrError then
        local track = trackOrError
        track.Looped = true
        pcall(function()
            track.Priority = Enum.AnimationPriority.Idle
        end)
        track:Play(0)
        local tracksByPosition = ensureTable(self._runtimeIdleTracksByUserId, player.UserId)
        tracksByPosition[positionKey] = track
    elseif not ok then
        warn(string.format(
            "[BrainrotService] 待机动画 LoadAnimation 失败（BrainrotId=%s, AnimationId=%s）: %s",
            tostring(brainrotDefinition.Id),
            tostring(animationId),
            tostring(trackOrError)
        ))
    else
        warn(string.format(
            "[BrainrotService] 待机动画播放失败：LoadAnimation 返回空 Track（BrainrotId=%s, AnimationId=%s）",
            tostring(brainrotDefinition.Id),
            tostring(animationId)
        ))
    end
end
return BrainrotService



















