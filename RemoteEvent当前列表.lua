--[[
=====================================================
RemoteEvent 当前列表（V1.2.1）
=====================================================

文档更新时间: 2026-03-06
说明: V1.2.1 无新增 RemoteEvent，仅行为调整（待机动画、Prompt 限制、数据保护）。

一、事件树
ReplicatedStorage
└─ Events
   ├─ CurrencyEvents
   │  ├─ CoinChanged (RemoteEvent) [V1.0]
   │  └─ RequestCoinSync (RemoteEvent) [V1.0]
   ├─ SystemEvents
   │  └─ HomeAssigned (RemoteEvent) [V1.0]
   └─ BrainrotEvents
      ├─ BrainrotStateSync (RemoteEvent) [V1.1]
      └─ RequestBrainrotStateSync (RemoteEvent) [V1.1]

二、事件说明
1. CoinChanged (S->C)
- 参数:
  - total: number
  - delta: number
  - reason: string
  - timestamp: number
- 用途: 同步玩家金币变化并驱动客户端动画。

2. RequestCoinSync (C->S)
- 参数: 无
- 用途: 客户端主动请求金币同步，服务端回发 CoinChanged。

3. HomeAssigned (S->C)
- 参数:
  - homeId: string
- 用途: 通知客户端当前分配到的家园。

4. BrainrotStateSync (S->C)
- 参数:
  - inventory: array
  - placed: array
  - equippedInstanceId: number
- 用途: 同步脑红背包/放置/装备状态。

5. RequestBrainrotStateSync (C->S)
- 参数: 无
- 用途: 客户端主动拉取脑红状态。

三、V1.2.1 行为补充（无新增事件）
1. 放置脑红后自动循环待机动画（服务端驱动）。
2. 手持脑红时禁用模型内 ProximityPrompt。
3. 平台已被占用时禁用平台 ProximityPrompt，空位恢复。
4. 读档连续失败时禁写回防止清档；`/clear` 使用强制写回通道。

四、维护约束
1. 未来新增事件必须同步更新:
- 本文件
- 架构设计文档.lua
- RemoteNames.lua
- RemoteEventService.lua
2. 所有 C->S 行为必须做服务端校验。

=====================================================
列表结束
=====================================================
]]
