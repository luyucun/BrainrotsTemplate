--[[
=====================================================
游戏整体架构设计文档（V1.5）
=====================================================

项目名称: BrainrotsTemplate
当前版本: V1.5
文档更新时间: 2026-03-09

一、核心分层
1. Shared 配置层（ReplicatedStorage/Shared）
- GameConfig: 全局配置（家园、DataStore、脑红、社交、好友产速加成、快捷传送）
- BrainrotConfig: 脑红静态表（含 IdleAnimationId）
- RemoteNames / FormatUtil: 事件名与格式化工具

2. 服务层（ServerScriptService/Services）
- PlayerDataService: 读写玩家数据、自动保存、离线结算基础时间戳
- HomeService: 家园分配/回收/传送
- CurrencyService: 金币增减与同步
- BrainrotService: 脑红背包、放置、产金、领取、状态同步
- FriendBonusService: 同服好友关系计算与加成同步
- QuickTeleportService: V1.5 新增，处理 Main/Top/Home/Shop/Sell 快捷传送请求
- GMCommandService: GM 命令（/addcoins /addbrainrot /clear）
- RemoteEventService: 统一创建和获取 RemoteEvent
- SocialService: 家园信息板展示、点赞交互与点赞状态同步

3. 客户端层（StarterPlayerScripts）
- MainClient + CoinDisplayController: 金币数字滚动、抖动、CoinAdd 动效
- SocialController: LikeTips 弹窗动画、点赞状态同步、Information Prompt 本地可见性过滤
- FriendBonusController: Friend Bonus 文本实时更新
- QuickTeleportController: V1.5 新增，绑定 Main/Top/Home/Shop/Sell 按钮并发起传送请求

=====================================================
二、V1.5 变更点
=====================================================

1. 快速回家（新增）
- UI: StarterGui/Main/Top/Home
- 行为: 点击后立即请求服务端，把玩家传送到自己家园 SpawnLocation 附近。

2. 快速到达商店（新增）
- UI: StarterGui/Main/Top/Shop 与 StarterGui/Main/Top/Sell
- 目标:
  - Shop -> Workspace/Shop01/PrisonerTouch
  - Sell -> Workspace/Shop02/PrisonerTouch
- 传送规则: 服务端读取 PrisonerTouch 的 Position，Y 轴加偏移后传送（默认 +5，可在 GameConfig.QUICK_TELEPORT 调整）。

3. 服务端校验与防滥用（新增）
- 客户端只提交目标类型（Home/Shop/Sell），不提交坐标。
- 服务端按白名单目标解析，非法参数直接忽略。
- RequestQuickTeleport 增加短间隔防抖（GameConfig.QUICK_TELEPORT.RequestDebounceSeconds）。

4. 网络事件新增（V1.5）
- RequestQuickTeleport (C->S)

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
  - FriendBonusRemainder
- BrainrotData
  - Inventory[{ InstanceId, BrainrotId }]
  - EquippedInstanceId
  - NextInstanceId
  - StarterGranted
- SocialState
  - LikesReceived: number
  - LikedPlayerUserIds: map<string, boolean>
- Meta
  - CreatedAt
  - LastLoginAt
  - LastLogoutAt
  - LastSaveAt

服务端运行态（不入档）
- BrainrotService._runtimePlacedByUserId
- BrainrotService._runtimeIdleTracksByUserId
- FriendBonusService._stateByUserId
- SocialService._homeInfoByName
- PlayerDataService._allowDataStoreSaveByUserId
- QuickTeleportService._lastRequestClockByUserId

=====================================================
四、初始化顺序（MainServer）
=====================================================
1. RemoteEventService:Init()
2. PlayerDataService:Init()
3. HomeService:Init()
4. CurrencyService:Init(...)
5. FriendBonusService:Init(...)
6. QuickTeleportService:Init(...)
7. GMCommandService:Init(...)
8. BrainrotService:Init(...)
9. SocialService:Init(...)
10. PlayerAdded: 家园分配 -> 读档 -> 好友加成初始化 -> 脑红恢复 -> 社交状态同步 -> 金币同步
11. PlayerRemoving: 解绑 -> 好友加成重算 -> 脑红运行态清理 -> 社交家园面板清空 -> 回收家园 -> 保存

=====================================================
五、维护约束
=====================================================
1. 新增/变更网络事件时，必须同步更新:
- RemoteEvent当前列表.lua
- RemoteNames.lua
- RemoteEventService.lua

2. 客户端请求必须服务端校验。
3. 与金币产出相关状态统一在 HomeState.ProductionState 维护。
4. 点赞数据属于永久玩家数据，严禁在非 `/clear` 流程下重置。
5. 好友加成只影响在线实时产出，不影响离线收益结算。
6. 快捷传送目标坐标只能由服务端解析，客户端不可直传坐标。

=====================================================
文档结束
=====================================================
]]