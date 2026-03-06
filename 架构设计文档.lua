--[[
=====================================================
游戏整体架构设计文档（V1.1 基线）
=====================================================

项目名称: BrainrotsTemplate
当前版本: V1.1
文档更新时间: 2026-03-06

说明:
1. 本文档对应当前 V1.1 需求实现（V1.0 + 脑红基础逻辑）。
2. 采用“服务端权威，客户端表现”的 Roblox 常规架构。
3. 新功能开发时，必须同步更新本文件与 RemoteEvent当前列表.lua。

=====================================================
一、推荐 Studio 层级结构
=====================================================

ReplicatedStorage
├── Shared
│   ├── GameConfig (ModuleScript)
│   ├── RemoteNames (ModuleScript)
│   ├── FormatUtil (ModuleScript)
│   └── BrainrotConfig (ModuleScript)
├── Model
│   ├── Common
│   ├── Uncommon
│   ├── Rare
│   ├── Epic
│   ├── Legendary
│   ├── Mythic
│   ├── Secret
│   ├── God
│   └── OG
└── Events
    ├── CurrencyEvents
    │   ├── CoinChanged (RemoteEvent)
    │   └── RequestCoinSync (RemoteEvent)
    ├── SystemEvents
    │   └── HomeAssigned (RemoteEvent)
    └── BrainrotEvents
        ├── BrainrotStateSync (RemoteEvent)
        └── RequestBrainrotStateSync (RemoteEvent)

ServerScriptService
├── MainServer (Script)
└── Services
    ├── RemoteEventService (ModuleScript)
    ├── PlayerDataService (ModuleScript)
    ├── HomeService (ModuleScript)
    ├── CurrencyService (ModuleScript)
    ├── GMCommandService (ModuleScript)
    └── BrainrotService (ModuleScript)

StarterPlayer
└── StarterPlayerScripts
    ├── MainClient (LocalScript)
    └── Controllers
        └── CoinDisplayController (ModuleScript)

本地文件目录（当前采用平铺，便于按修改时间排序手动同步到 Studio）:
- MainServer.server.lua -> ServerScriptService/MainServer
- RemoteEventService.lua -> ServerScriptService/Services/RemoteEventService
- PlayerDataService.lua -> ServerScriptService/Services/PlayerDataService
- HomeService.lua -> ServerScriptService/Services/HomeService
- CurrencyService.lua -> ServerScriptService/Services/CurrencyService
- GMCommandService.lua -> ServerScriptService/Services/GMCommandService
- BrainrotService.lua -> ServerScriptService/Services/BrainrotService
- MainClient.client.lua -> StarterPlayer/StarterPlayerScripts/MainClient
- CoinDisplayController.lua -> StarterPlayer/StarterPlayerScripts/Controllers/CoinDisplayController
- GameConfig.lua -> ReplicatedStorage/Shared/GameConfig
- RemoteNames.lua -> ReplicatedStorage/Shared/RemoteNames
- FormatUtil.lua -> ReplicatedStorage/Shared/FormatUtil
- BrainrotConfig.lua -> ReplicatedStorage/Shared/BrainrotConfig

=====================================================
二、模块职责划分
=====================================================

1) MainServer
- 系统启动入口，控制初始化顺序。
- 管理玩家进入/离开生命周期。
- 串联家园、数据、货币、GM、脑红系统。

2) RemoteEventService
- 创建并缓存 Events 下的 RemoteEvent。
- 为后续版本新增事件提供统一接入点。

3) PlayerDataService
- 负责玩家数据加载、缓存、保存、自动保存、关服保存。
- 数据隔离规则:
  - Studio: Brainrots_PlayerData_STUDIO_V1
  - 线上: Brainrots_PlayerData_LIVE_V1
- 支持 Studio API 关闭时自动切内存模式。

4) HomeService
- 按 Home01 -> Home05 顺序分配空家园。
- 保证一个家园同一时刻只归属一个玩家。
- 管理 RespawnLocation 与重生回家园逻辑。
- 玩家离开后立即释放家园占用。

5) CurrencyService
- 服务端权威维护金币变化。
- 只通过服务端接口 AddCoins/SetCoins 改变金币。
- 通过 CoinChanged 事件下发总值与本次 delta，驱动客户端 UI 表现。

6) GMCommandService
- 仅 Studio 环境启用。
- 仅开发者（Creator/配置白名单）可用 /addcoins xxxx 与 /addbrainrot id 数量。
- 命令生效后走 CurrencyService，避免绕过数据层。

7) BrainrotConfig
- 维护脑红基础表（ID/名称/品质/稀有度/模型路径/图标/产速）。
- 维护品质与稀有度数值映射表。
- 维护 V1.1 测试初始脑红列表。

8) BrainrotService
- 负责脑红背包 Tool 生成与装备/收回逻辑。
- 绑定家园 Platform 的 ProximityPrompt（长按 1 秒）放置脑红。
- 按 Attachment + 可调偏移挂载脑红模型。
- 维护放置状态并每秒结算脑红产金。
- 通过 BrainrotStateSync 下发脑红状态（背包/放置/当前装备）。

9) CoinDisplayController
- 监听 CoinChanged，处理金币 UI 表现:
  - 0.6 秒数字滚动到目标值
  - CoinNum 两次快速放大缩回
  - CoinAdd 冒出 + 回弹 + 渐隐
  - 快速连续变化时自动把旧提示上推，避免重叠

=====================================================
三、初始化顺序（V1.1）
=====================================================

1. RemoteEventService:Init()
2. PlayerDataService:Init()
3. HomeService:Init()
4. CurrencyService:Init(...)
5. GMCommandService:Init(...)
6. BrainrotService:Init(...)
7. 玩家进入:
   - 分配家园
   - 加载玩家数据
   - 写入 HomeId
   - 绑定 GM
   - 初始化脑红（背包/平台恢复/状态同步）
   - 同步金币

=====================================================
四、核心数据结构（PlayerDataService）
=====================================================

PlayerData（V1.1）:
- Version: number
- Currency:
  - Coins: number
- Growth:
  - PowerLevel: number
  - RebirthLevel: number
- HomeState:
  - HomeId: string
  - PlacedBrainrots: table
    - [positionKey] = {
        InstanceId: number,
        BrainrotId: number,
        PlacedAt: unix timestamp
      }
  - ProductionState: table
- BrainrotData:
  - NextInstanceId: number
  - EquippedInstanceId: number
  - StarterGranted: boolean
  - Inventory: array
    - { InstanceId: number, BrainrotId: number }
- Meta:
  - CreatedAt: unix timestamp
  - LastLoginAt: unix timestamp
  - LastSaveAt: unix timestamp

=====================================================
五、V1.1 需求映射
=====================================================

- 脑红基础配置（ID/品质/稀有度/模型路径/产速/图标） -> BrainrotConfig
- 脑红背包与拿起/放回 -> BrainrotService（Tool 装备 + 再次点击收回）
- 展示平台放置（Prompt 长按 1 秒） -> BrainrotService
- Attachment 挂载与朝上偏移参数 -> GameConfig.BRAINROT + BrainrotService
- 每秒产金 -> BrainrotService + CurrencyService
- 金币展示动效 -> CoinDisplayController

=====================================================
六、后续扩展约束
=====================================================

1. 新系统优先复用 Shared/GameConfig 与 Services。
2. 所有客户端请求类行为必须服务端校验。
3. 新增 RemoteEvent 时，必须同步更新:
   - 架构设计文档.lua
   - RemoteEvent当前列表.lua
   - RemoteNames.lua
   - RemoteEventService.lua
4. 新脑红字段优先挂在 BrainrotConfig 与 PlayerData.BrainrotData 下，避免结构发散。

=====================================================
文档结束
=====================================================
]]
