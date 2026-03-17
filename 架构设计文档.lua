--[[
=====================================================
游戏整体架构设计文档（V2.5）
=====================================================

项目名称: BrainrotsTemplate
当前版本: V2.5
文档更新时间: 2026-03-17

一、核心分层
1. Shared 配置层（ReplicatedStorage/Shared）
- GameConfig: 全局配置，集中管理家园、DataStore、脑红、武器、Rebirth、全局排行榜、特殊事件、脑红升级参数等。
- BrainrotConfig: 脑红静态配置表，来源于 Excel 脑红表同步结果。
- RebirthConfig: Rebirth 静态配置表。
- BrainrotDisplayConfig: 脑红品质/稀有度展示名与渐变路径映射。
- RemoteNames / FormatUtil: RemoteEvent 名称与格式化工具。

2. 服务层（ServerScriptService/Services）
- PlayerDataService: 玩家数据读写、默认值合并、会话缓存、自动保存、排行榜快照持久化。
- HomeService: 家园分配、回收、传送。
- CurrencyService: 金币增减、同步，以及默认玩家列表 Cash 展示。
- BrainrotService: 脑红背包、装备、放置、产金、领取、世界模型运行态、Index 解锁历史、Claim UI 刷新、Brand 升级台刷新、升级服务端校验。
- RebirthService: Rebirth 条件校验、执行、状态同步、产速倍率更新。
- FriendBonusService: 同服好友数量统计与好友产速加成同步。
- QuickTeleportService: Home / Shop / Sell 快捷传送请求。
- GMCommandService: GM 命令入口，当前支持 /addcoins /addbrainrot /clear /event。
- RemoteEventService: 统一创建和获取 RemoteEvent。
- SocialService: 家园信息板、点赞交互、点赞提示与状态同步。
- WeaponService: 武器拥有/装备状态管理，当前固定 1 个武器槽位。
- WeaponKnockbackService: 挥击命中后的击飞逻辑，不扣血、不击杀。
- GlobalLeaderboardService: 全局总产速榜/总时长榜刷新、榜单 UI 填充、玩家个人卡片属性同步。
- SpecialEventService: V2.4.1 特殊事件调度、跨服统一时间片选取、客户端状态同步、GM 手动触发。

3. 客户端层（StarterPlayerScripts）
- MainClient: 客户端启动入口与首次请求同步。
- CoinDisplayController: 金币滚动、抖动、浮字反馈；V2.5 起主界面 CoinNum 显示向上取整，浮字最多 1 位小数。
- SocialController: 点赞提示、点赞状态过滤、Prompt 本地可见性处理。
- FriendBonusController: Friend Bonus 文本更新。
- QuickTeleportController: 顶部 Home / Shop / Sell 快捷按钮。
- ClaimFeedbackController: 仅本地播放领取音效与金币飞散回收特效。
- MainButtonFxController: 主界面按钮 Hover / Press 动效。
- ModalController: 通用弹窗开关与 Blur 动效。
- IndexController: 图鉴界面、分类页签、条目渲染、渐变展示、进度统计。
- BrainrotUpgradeController: 扫描自己家园的 BrandX 升级台，绑定点击升级、箭头上下循环动画、升级成功/失败音效。
- RebirthController: Rebirth 面板、进度、请求与反馈表现。
- GlobalLeaderboardController: 本地玩家卡片刷新，读取玩家 Attribute 更新两个排行榜下方个人信息区域。
- SpecialEventController: 监听特殊事件同步，在本地给自己角色挂事件模板，并本地复制 Lighting 事件天空盒子节点。

二、近阶段功能要点
1. V2.1 / V2.1.1
- Index 界面复用 BrainrotStateSync 的解锁历史数据。
- Claim 显示路径统一为 ClaimX/Touch/.../Money(Frame)，不再使用旧 BillboardGui 路径。

2. V2.2
- Rebirth 等级为永久玩家数据。
- Rebirth 成功后清空当前金币与待领取金币，并重新应用 Rebirth 产速倍率。

3. V2.3
- 新增全局总产速排行榜与全局总游玩时长排行榜。
- 公共 Top50 榜单由服务端直接驱动场景内 UI。
- 玩家自己的底部个人卡片由客户端读取玩家 Attribute 驱动。
- TotalPlaySeconds 为永久数据，/clear 不清空该字段。

4. V2.4 / V2.4.1 特殊事件
- 每 30 分钟触发一次特殊事件，按 UTC 整点和 30 分对齐，与服务器开启时间无关。
- 事件从 GameConfig.SPECIAL_EVENT.Entries 中按权重选择，且本次事件不能与上次调度事件重复。
- 服务端负责调度和状态同步；客户端负责本地角色挂件和本地 Lighting 表现。
- GM 可通过 /event <事件Id> 在当前服务器手动触发事件。

5. V2.5 脑红升级
- 所有脑红在首次获得时默认 Level=1。
- 脑红升级费用: baseCoinPerSecond * 1.5^(currentLevel-1)。
- 脑红当前产速: baseCoinPerSecond * 1.25^(currentLevel-1)。
- BrainrotService 在服务端刷新 BrandX 升级台文案，并把升级后的等级与产速写回运行态和存档。
- BrainrotUpgradeController 负责 BrandX 点击请求、Arrow 循环动画、升级成功/失败音效。
- 金币底层允许小数；主界面 CoinNum 仍按整数显示并向上取整。
- 升级费用、产速、待领取金币等带小数的文案统一最多显示 1 位小数，四舍五入。

三、关键数据结构
1. 持久化 PlayerData
- Currency.Coins
- Growth.PowerLevel
- Growth.RebirthLevel
- HomeState.HomeId
- HomeState.PlacedBrainrots[positionKey] -> InstanceId / BrainrotId / Level / PlacedAt
- HomeState.ProductionState[positionKey] -> CurrentGold / OfflineGold / FriendBonusRemainder
- BrainrotData.Inventory[{ InstanceId, BrainrotId, Level }]
- BrainrotData.EquippedInstanceId / NextInstanceId / StarterGranted / UnlockedBrainrotIds
- WeaponState.StarterWeaponGranted / OwnedWeaponIds / EquippedWeaponId
- LeaderboardState.TotalPlaySeconds / ProductionSpeedSnapshot
- SocialState.LikesReceived / LikedPlayerUserIds
- Meta.CreatedAt / LastLoginAt / LastLogoutAt / LastSaveAt

2. 运行态数据（不入档）
- BrainrotService._runtimePlacedByUserId
- BrainrotService._runtimeIdleTracksByUserId
- BrainrotService._claimTouchDebounceByUserId
- BrainrotService._claimEffectByUserId
- BrainrotService._claimBounceStateByUserId
- BrainrotService._brandsByUserId
- BrainrotService._upgradeRequestClockByUserId
- FriendBonusService._stateByUserId
- RebirthService._lastRequestClockByUserId
- GlobalLeaderboardService._memoryScoresByBoardKey / _cachedEntriesByBoardKey / _userInfoByUserId
- QuickTeleportService._lastRequestClockByUserId
- SpecialEventService._activeEventsByRuntimeKey / _scheduleState

四、关键同步协议
1. CoinChanged
- 服务端下发 total / delta / reason / timestamp。
- V2.5 起 total 与 delta 可带小数；CoinDisplayController 决定展示策略。

2. BrainrotStateSync
- inventory[i] 现包含 level / baseCoinPerSecond / coinPerSecond / nextUpgradeCost。
- placed[i] 现包含 level / baseCoinPerSecond / coinPerSecond / nextUpgradeCost。
- totalProductionBaseSpeed / totalProductionSpeed 现反映升级后的真实产速，而不再只是基础表值求和。

3. RequestBrainrotUpgrade / BrainrotUpgradeFeedback
- 客户端只上传 positionKey。
- 服务端重新校验脑红存在、等级、费用、金币余额与请求频率。
- 成功后同时触发: 扣金币 -> 升级 -> 刷新 Brand UI -> 刷新 BrainrotStateSync -> 更新总产速 Attribute。
- 反馈事件只负责客户端本地音效，不承载可信业务结果。

五、服务端初始化顺序（MainServer）
1. RemoteEventService:Init()
2. PlayerDataService:Init()
3. WeaponService:Init(...)
4. WeaponKnockbackService:Init()
5. HomeService:Init()
6. CurrencyService:Init(...)
7. FriendBonusService:Init(...)
8. QuickTeleportService:Init(...)
9. BrainrotService:Init(...)
10. RebirthService:Init(...)
11. GMCommandService:Init(...)
12. SocialService:Init(...)
13. GlobalLeaderboardService:Init(...)
14. SpecialEventService:Init(...)
15. PlayerAdded 流程: 分配家园 -> 读档 -> 恢复武器 -> 初始化好友加成 -> 初始化 Rebirth 属性 -> 恢复脑红/离线收益/图鉴历史/Brand 升级台 -> 社交同步 -> 同步当前活跃特殊事件状态 -> 金币同步 -> 排行榜个人卡刷新
16. PlayerRemoving 流程: 解绑 -> 武器清理 -> 排行榜快照刷新 -> 好友加成重算 -> 脑红运行态清理 -> Rebirth 清理 -> 社交清理 -> 回收家园 -> 保存数据
17. BindToClose: 先刷新全局排行榜快照，再保存所有玩家数据

六、维护约束
1. 未来若新增或修改 RemoteEvent，必须同步更新：
- RemoteEvent当前列表.lua
- 架构设计文档.lua
- RemoteNames.lua
- RemoteEventService.lua

2. 所有客户端 -> 服务端请求都必须继续做服务端校验。
3. 所有产出相关状态统一维护在 HomeState.ProductionState。
4. 点赞、图鉴解锁历史、Rebirth 等级、总游玩时长均属于永久数据。
5. /clear 不得清空 TotalPlaySeconds。
6. Claim 音效继续保持“仅触发者自己本地可听见”。
7. 公共排行榜行内容由服务端驱动，底部个人卡片由客户端驱动。
8. 当前特殊事件系统采用“服务端调度 + 客户端本地表现”；若未来需要倒计时 UI、全服公告或跨玩家可见表现，再继续扩展同步协议。
9. V2.5 起，脑红等级只以服务端存档和服务端计算结果为准，客户端不可自行推导为最终真值。

=====================================================
文档结束
=====================================================
]]
