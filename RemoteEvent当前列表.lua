--[[
=====================================================
RemoteEvent 当前列表（V1.1 基线）
=====================================================

更新时间: 2026-03-06
目录结构:
ReplicatedStorage
└── Events (Folder)

=====================================================
一、完整树状列表（含版本）
=====================================================

ReplicatedStorage
└── Events (Folder)
    ├── CurrencyEvents (Folder) [V1.0]
    │   ├── CoinChanged (RemoteEvent) [V1.0]
    │   └── RequestCoinSync (RemoteEvent) [V1.0]
    ├── SystemEvents (Folder) [V1.0]
    │   └── HomeAssigned (RemoteEvent) [V1.0]
    └── BrainrotEvents (Folder) [V1.1]
        ├── BrainrotStateSync (RemoteEvent) [V1.1]
        └── RequestBrainrotStateSync (RemoteEvent) [V1.1]

版本说明:
- V1.0: 初始金币/家园同步事件
- V1.1: 脑红系统事件

=====================================================
二、事件目录总览
=====================================================

1) CurrencyEvents (Folder)
2) SystemEvents (Folder)
3) BrainrotEvents (Folder)

=====================================================
三、分组明细
=====================================================

【CurrencyEvents】
- CoinChanged (S->C)
  参数:
  {
      total = number,      -- 当前金币总额
      delta = number,      -- 本次变化值（可正可负）
      reason = string,     -- 变化来源，例如 GMCommand/InitialSync/BrainrotProduction
      timestamp = number   -- 发送时序标记
  }

- RequestCoinSync (C->S)
  参数: 无
  说明: 客户端请求金币同步，服务端会回发 CoinChanged（delta=0）。

【SystemEvents】
- HomeAssigned (S->C)
  参数:
  {
      homeId = string      -- 例如 Home01
  }
  说明: 玩家进入后，服务端通知当前分配到的家园编号。

【BrainrotEvents】
- BrainrotStateSync (S->C)
  参数:
  {
      inventory = array,          -- 背包脑红列表
      placed = array,             -- 展示平台已放置脑红列表
      equippedInstanceId = number -- 当前拿在手上的脑红实例ID
  }
  说明: 服务端在玩家就绪、放置、装备变化后推送脑红状态。

- RequestBrainrotStateSync (C->S)
  参数: 无
  说明: 客户端主动请求最新脑红状态。

=====================================================
四、维护约束
=====================================================

1. 新增业务事件时，必须同步更新:
   - 本文件
   - 架构设计文档.lua
   - RemoteNames.lua
   - RemoteEventService.lua
2. 涉及客户端提交的请求类事件，必须服务端校验。
3. 货币类事件统一在 CurrencyEvents 下维护。
4. 脑红类事件统一在 BrainrotEvents 下维护。
5. GM 命令扩展（/addbrainrot）不新增 RemoteEvent，直接服务端改数据与同步。

=====================================================
列表结束
=====================================================
]]
