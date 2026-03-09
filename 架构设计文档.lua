--[[
=====================================================
游戏整体架构设计文档（V1.4）
=====================================================

项目名称: BrainrotsTemplate
当前版本: V1.4
文档更新时间: 2026-03-08

一、核心分层
1. Shared 配置层（ReplicatedStorage/Shared）
- GameConfig: 全局配置（家园、DataStore、脑红、社交、好友产速加成）
- BrainrotConfig: 脑红静态表（含 IdleAnimationId）
- RemoteNames / FormatUtil: 事件名与格式化工具

2. 服务层（ServerScriptService/Services）
- PlayerDataService: 读写玩家数据、自动保存、离线结算基础时间戳
- HomeService: 家园分配/回收/传送
- CurrencyService: 金币增减与同步
- BrainrotService: 脑红背包、放置、产金、领取、状态同步
- FriendBonusService: V1.4 新增，同服好友关系计算与加成同步
- GMCommandService: GM 命令（/addcoins /addbrainrot /clear）
- RemoteEventService: 统一创建和获取 RemoteEvent
- SocialService: 家园信息板展示、点赞交互与点赞状态同步

3. 客户端层（StarterPlayerScripts）
- MainClient + CoinDisplayController: 金币数字滚动、抖动、CoinAdd 动效
- SocialController: LikeTips 弹窗动画、点赞状态同步、Information Prompt 本地可见性过滤
- FriendBonusController: V1.4 新增，Friend Bonus 文本实时更新

=====================================================
二、V1.4 变更点
=====================================================

1. 同服好友产速加成（新增）
- 规则:
  - 1 位好友在线: +10%
  - 2 位好友在线: +20%
  - 3 位好友在线: +30%
  - 4 位好友在线: +40%（上限）
- 生效时机:
  - 好友上线后立刻生效
  - 好友离线后立刻移除

2. 实时产金加成接入（新增）
- BrainrotService 每秒产金时读取 FriendBonusService 的加成百分比。
- 使用 FriendBonusRemainder 处理小数增量，避免低产速下百分比精度丢失。
- 离线收益结算逻辑保持无好友加成（仅按基础 CoinPerSecond * 离线秒数）。

3. 客户端展示（新增）
- UI 路径: StarterGui/Main/Cash/FriendBonus
- 默认文本: Friend Bonus: +0%
- 当加成变化时，服务端通过 FriendBonusSync 事件推送更新文本。

4. 网络事件新增（V1.4）
- FriendBonusSync (S->C)
- RequestFriendBonusSync (C->S)

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
  - FriendBonusRemainder (V1.4 新增)
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

=====================================================
四、初始化顺序（MainServer）
=====================================================
1. RemoteEventService:Init()
2. PlayerDataService:Init()
3. HomeService:Init()
4. CurrencyService:Init(...)
5. FriendBonusService:Init(...)
6. GMCommandService:Init(...)
7. BrainrotService:Init(...)
8. SocialService:Init(...)
9. PlayerAdded: 家园分配 -> 读档 -> 好友加成初始化 -> 脑红恢复 -> 社交状态同步 -> 金币同步
10. PlayerRemoving: 解绑 -> 好友加成重算 -> 脑红运行态清理 -> 社交家园面板清空 -> 回收家园 -> 保存

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

=====================================================
文档结束
=====================================================
]]
