--[[
=====================================================
游戏整体架构设计文档（V1.7）
=====================================================

项目名称: BrainrotsTemplate
当前版本: V1.7
文档更新时间: 2026-03-09

一、核心分层
1. Shared 配置层（ReplicatedStorage/Shared）
- GameConfig: 全局配置（家园、DataStore、脑红、社交、好友产速加成、快捷传送、脑红信息牌、榜单字段）
- BrainrotConfig: 脑红静态表（12 条测试脑红）
- BrainrotDisplayConfig: 品质/稀有度显示名与渐变路径映射
- RemoteNames / FormatUtil: 事件名与格式化工具

2. 服务层（ServerScriptService/Services）
- PlayerDataService: 读写玩家数据、自动保存、离线结算基础时间戳
- HomeService: 家园分配/回收/传送
- CurrencyService: 金币增减与同步、V1.7 单服内置榜单（Cash）
- BrainrotService: 脑红背包、放置、产金、领取、状态同步、头顶信息牌、V1.7 总产速计算
- FriendBonusService: 同服好友关系计算与加成同步
- QuickTeleportService: 处理 Main/Top/Home/Shop/Sell 快捷传送请求
- GMCommandService: GM 命令（/addcoins /addbrainrot /clear）
- RemoteEventService: 统一创建和获取 RemoteEvent
- SocialService: 家园信息板展示、点赞交互与点赞状态同步

3. 客户端层（StarterPlayerScripts）
- MainClient + CoinDisplayController: 金币数字滚动、抖动、CoinAdd 动效
- SocialController: LikeTips 弹窗动画、点赞状态同步、Information Prompt 本地可见性过滤
- FriendBonusController: Friend Bonus 文本实时更新
- QuickTeleportController: 绑定 Main/Top/Home/Shop/Sell 按钮并发起传送请求

=====================================================
二、V1.7 变更点
=====================================================

1. 玩家总产速（新增）
- 定义: 当前摆在展台上的所有脑红基础产速之和，再乘以总加成倍率。
- 公式: 最终产速 = 基础总产速 * (1 + 加成1 + 加成2 + ...)
- 当前接入加成:
  - FriendBonusService 同服好友加成
  - 预留 ExtraProductionBonusPercent 属性加成扩展位
- 服务端每秒刷新并写入玩家 Attribute:
  - TotalProductionSpeedBase
  - TotalProductionBonusRate
  - TotalProductionMultiplier
  - TotalProductionSpeed

2. BrainrotStateSync 补充（新增）
- totalProductionBaseSpeed
- totalProductionMultiplier
- totalProductionSpeed

3. 单服内置榜单（新增）
- 使用默认 Tab 榜单（leaderstats）
- 字段:
  - Cash（StringValue，K/M/B 等大数值显示）
- 显示列: 玩家名字 / Cash（K/M/B）
- 排序: 使用 Roblox 内置榜单默认顺序

4. 榜单显示约束（新增）
- 不额外显示 Rank 列，仅保留 Cash 列参与排序与展示

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
- BrainrotService._missingDisplayPathWarned
- FriendBonusService._stateByUserId
- SocialService._homeInfoByName
- PlayerDataService._allowDataStoreSaveByUserId
- QuickTeleportService._lastRequestClockByUserId

玩家 Attribute（V1.7）
- CashRaw
- TotalProductionSpeedBase
- TotalProductionBonusRate
- TotalProductionMultiplier
- TotalProductionSpeed

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
10. PlayerAdded: 家园分配 -> 读档 -> 好友加成初始化 -> 脑红恢复/挂载信息牌/计算总产速 -> 社交状态同步 -> 金币与榜单同步
11. PlayerRemoving: 解绑 -> 好友加成重算 -> 脑红运行态清理 -> 清理榜单字段 -> 社交家园面板清空 -> 回收家园 -> 保存

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
7. 头顶信息牌仅在运行态场景模型挂载，不在背包 Tool 上挂载。
8. 榜单不额外显示 Rank 列，Cash 使用 K/M/B 大数值显示。

=====================================================
文档结束
=====================================================
]]
