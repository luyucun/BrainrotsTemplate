--[[
=====================================================
游戏整体架构设计文档（V1.2.1）
=====================================================

项目名称: BrainrotsTemplate
当前版本: V1.2.1
文档更新时间: 2026-03-06

一、核心分层
1. Shared 配置层（ReplicatedStorage/Shared）
- GameConfig: 全局配置（含 GM、DataStore、Brainrot 平台节点命名）
- BrainrotConfig: 脑红静态表（含 IdleAnimationId）
- RemoteNames / FormatUtil: 事件名与格式化工具

2. 服务层（ServerScriptService/Services）
- PlayerDataService: 读写玩家数据、自动保存、离线结算基础时间戳
- HomeService: 家园分配/回收/传送
- CurrencyService: 金币增减与同步
- BrainrotService: 脑红背包、放置、产金、领取、状态同步
- GMCommandService: GM 命令（/addcoins /addbrainrot /clear）
- RemoteEventService: 统一创建和获取 RemoteEvent

3. 客户端层（StarterPlayerScripts）
- MainClient + CoinDisplayController: 金币数字滚动、抖动、CoinAdd 动效

=====================================================
二、V1.2.1 变更点
=====================================================

1. 放置模型待机动画（新增）
- 配置: BrainrotConfig.Entries[*].IdleAnimationId
- 行为: 脑红放置到 Platform 后，服务端自动播放循环待机动画。
- 恢复: 玩家重进后从存档恢复放置模型时，会重新启动待机动画。
- 清理: 模型销毁/玩家离开时，会停止并清理对应 AnimationTrack。

2. Prompt 交互限制（新增）
- 手持脑红时: Tool 内可视模型中的 ProximityPrompt 会被禁用，不可交互、不显示。
- 平台已占用时: 对应 Platform 的 ProximityPrompt 会被禁用；空位时自动恢复。

3. Tool 持有与放置对齐（持续生效）
- 手持逻辑: 使用不可见 Handle 挂手，视觉模型焊接到 Handle。
- 偏移逻辑: 保留“模板中视觉模型相对 Handle 的偏移”。
- 放置逻辑: 支持模板为 Tool；优先按配置模型/同名子 Model 的轴点对齐 Attachment。

4. 数据清档保护（新增）
- 问题根因: GetAsync 连续失败时若直接写默认数据，可能覆盖旧档导致“像被清档”。
- 修复策略:
  - 本次会话读取连续失败 -> 禁止自动写回 DataStore（autosave/离开保存均跳过）。
  - GM `/clear` -> 使用强制写回通道，允许明确清档。
- 目标: 非 `/clear` 场景不应再出现“偶发自动清空背包/金币”。

5. GM 权限策略
- Studio: 允许所有人使用 GM（AllowAllUsers=true）。
- 线上: 禁止 GM（EnabledOnlyInStudio=true）。

=====================================================
三、关键数据结构
=====================================================

PlayerData
- Currency.Coins
- HomeState.PlacedBrainrots[positionKey]
  - InstanceId
  - BrainrotId
  - PlacedAt
- HomeState.ProductionState[positionKey]
  - CurrentGold
  - OfflineGold
- BrainrotData
  - Inventory[{ InstanceId, BrainrotId }]
  - EquippedInstanceId
  - NextInstanceId
  - StarterGranted
- Meta
  - CreatedAt
  - LastLoginAt
  - LastLogoutAt
  - LastSaveAt

服务端运行态（不入档）
- BrainrotService._runtimePlacedByUserId
- BrainrotService._runtimeIdleTracksByUserId
- PlayerDataService._allowDataStoreSaveByUserId

=====================================================
四、初始化顺序（MainServer）
=====================================================
1. RemoteEventService:Init()
2. PlayerDataService:Init()
3. HomeService:Init()
4. CurrencyService:Init(...)
5. GMCommandService:Init(...)
6. BrainrotService:Init(...)
7. PlayerAdded: 家园分配 -> 读档 -> 脑红恢复 -> 金币同步
8. PlayerRemoving: 解绑 -> 脑红运行态清理 -> 回收家园 -> 保存

=====================================================
五、维护约束
=====================================================
1. 新增/变更网络事件时，必须同步更新:
- RemoteEvent当前列表.lua
- RemoteNames.lua
- RemoteEventService.lua

2. 客户端请求必须服务端校验。
3. 与金币产出相关状态统一在 HomeState.ProductionState 维护。
4. V1.2.1 无新增 RemoteEvent，仅服务端行为增强。

=====================================================
文档结束
=====================================================
]]
