--[[
=====================================================
游戏整体架构设计文档（V1.8.1）
=====================================================

项目名称: BrainrotsTemplate
当前版本: V1.8.1
文档更新时间: 2026-03-10

一、核心分层
1. Shared 配置层（ReplicatedStorage/Shared）
- GameConfig: 全局配置（家园、DataStore、脑红、社交、好友产速加成、快捷传送、脑红信息牌、榜单字段、Claim 动效参数）
- BrainrotConfig: 脑红静态表（12 条测试脑红）
- BrainrotDisplayConfig: 品质/稀有度显示名与渐变路径映射
- RemoteNames / FormatUtil: 事件名与格式化工具

2. 服务层（ServerScriptService/Services）
- PlayerDataService: 读写玩家数据、自动保存、离线结算基础时间戳
- HomeService: 家园分配/回收/传送
- CurrencyService: 金币增减与同步、单服内置榜单（Cash）
- BrainrotService: 脑红背包、放置、产金、领取、状态同步、头顶信息牌、总产速计算、V1.8.1 Claim 反馈表现
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
- ClaimFeedbackController (V1.8.1): 监听 ClaimCashFeedback，仅本地播放 ADDCash 音效

=====================================================
二、V1.8.1 变更点
=====================================================

1. Claim 领取反馈表现（新增）
- Claim/Touch 按压: Claim 本体不动，仅 Touch 下压后回弹，使用缓动曲线。
- 脑红弹跳: 对应 Position 上已放置脑红上弹后平滑回落（去除末端弹性）。
- 粒子特效: 从 ReplicatedStorage/Effect/Claim 目录分别复制 Glow/Smoke/Money/Stars，并挂载到 Claim/Touch。
  - Glow / Smoke: 每次触碰各 Emit(1) 一次，等待粒子生命周期结束后销毁。
  - Money / Stars: 正常播放，固定 1.5 秒后移除。
  - 快速重复触发: 新触发前先清理旧粒子节点，再重建新一轮特效。

2. Claim 触碰触发规则（调整）
- 仅触碰 Claim/Touch 的 Touch 节点才会触发领取流程。
- 玩家持续站在 Claim 不动: 最多触发一次。
- 玩家在 Claim 上移动: 不会再次触发领取流程。
- 玩家离开 Claim 后再次触碰: 可再次触发（受 ClaimTouchDebounceSeconds 限制）。
- 修复连续多次触碰时脑红弹跳高度累加: 每次弹跳前先恢复到基准位。

3. Claim 音效下发（新增）
- 新增 RemoteEvent: ClaimCashFeedback (S->C)。
- 服务端仅对触发领取者 FireClient，客户端本地播放 SoundService/Audio/ADDCash。
- 若场景缺少 ADDCash，客户端回退到 `rbxassetid://139922061047157`。

4. V1.7 能力延续
- 玩家总产速公式: 最终产速 = 基础总产速 * (1 + 加成1 + 加成2 + ...)
- BrainrotStateSync 扩展字段:
  - totalProductionBaseSpeed
  - totalProductionMultiplier
  - totalProductionSpeed
- Tab 榜单仅显示 Cash（K/M/B），不显示 Rank。

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
- BrainrotService._claimTouchDebounceByUserId（V1.8.1: 触碰状态与二次触发防抖）
- BrainrotService._claimEffectByUserId（V1.8.1: 当前 Claim 粒子节点）
- BrainrotService._claimBounceStateByUserId（V1.8.1: 脑红弹跳动画状态）
- BrainrotService._missingDisplayPathWarned
- FriendBonusService._stateByUserId
- SocialService._homeInfoByName
- PlayerDataService._allowDataStoreSaveByUserId
- QuickTeleportService._lastRequestClockByUserId

玩家 Attribute
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
11. PlayerRemoving: 解绑 -> 好友加成重算 -> 脑红运行态清理 -> 清理 Claim 反馈运行态 -> 社交家园面板清空 -> 回收家园 -> 保存

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
9. Claim 音效必须保持“仅触发者本地可听见”。

=====================================================
文档结束
=====================================================

====================================================
六、V2.1 武器系统补充（2026-03-12）
====================================================
1. 新增 WeaponService：负责玩家武器拥有/装备状态维护；当前固定 1 个武器槽位。
2. 新增 WeaponKnockbackService：玩家挥击后在短窗口内命中其他玩家触发击飞。
3. 击飞规则：仅击飞，不扣血，不击杀；为纯服务端逻辑，不新增 RemoteEvent。
4. MainServer 接入：PlayerAdded 绑定武器与击飞监听，PlayerRemoving 清理监听。
]]