--[[
=====================================================
RemoteEvent 当前列表（V1.5）
=====================================================

文档更新时间: 2026-03-09
说明: V1.5 新增快捷传送请求事件。 

一、事件树
ReplicatedStorage
└─ Events
   ├─ CurrencyEvents
   │  ├─ CoinChanged (RemoteEvent) [V1.0]
   │  └─ RequestCoinSync (RemoteEvent) [V1.0]
   ├─ SystemEvents
   │  ├─ HomeAssigned (RemoteEvent) [V1.0]
   │  ├─ LikeTip (RemoteEvent) [V1.3]
   │  ├─ SocialStateSync (RemoteEvent) [V1.3]
   │  ├─ RequestSocialStateSync (RemoteEvent) [V1.3]
   │  ├─ FriendBonusSync (RemoteEvent) [V1.4]
   │  ├─ RequestFriendBonusSync (RemoteEvent) [V1.4]
   │  └─ RequestQuickTeleport (RemoteEvent) [V1.5]
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

4. LikeTip (S->C) [V1.3]
- 参数:
  - message: string
  - timestamp: number
- 用途: 点赞后给点赞者/被点赞者弹出提示文案。

5. SocialStateSync (S->C) [V1.3]
- 参数:
  - likedOwnerUserIds: array<number>
- 用途: 同步“我已点赞过哪些玩家”，用于客户端隐藏不可点赞的 Information Prompt。

6. RequestSocialStateSync (C->S) [V1.3]
- 参数: 无
- 用途: 客户端主动拉取社交点赞状态。

7. FriendBonusSync (S->C) [V1.4]
- 参数:
  - friendCount: number
  - bonusPercent: number
  - timestamp: number
- 用途: 同步同服好友加成百分比，驱动客户端 Friend Bonus 文本实时更新。

8. RequestFriendBonusSync (C->S) [V1.4]
- 参数: 无
- 用途: 客户端主动拉取当前好友加成状态。

9. RequestQuickTeleport (C->S) [V1.5 新增]
- 参数:
  - payload.target: string (Home/Shop/Sell)
- 用途: 玩家点击 Main/Top 快捷按钮后，请求服务端执行传送。
- 校验:
  - 仅允许 Home/Shop/Sell 三种目标。
  - 目标坐标由服务端读取场景节点，不信任客户端坐标。

10. BrainrotStateSync (S->C)
- 参数:
  - inventory: array
  - placed: array
  - equippedInstanceId: number
- 用途: 同步脑红背包/放置/装备状态。

11. RequestBrainrotStateSync (C->S)
- 参数: 无
- 用途: 客户端主动拉取脑红状态。

三、V1.5 行为补充
1. Home 按钮：传送到玩家所属 Home 的 SpawnLocation。
2. Shop 按钮：传送到 Workspace/Shop01/PrisonerTouch 上方（Y 偏移可配置）。
3. Sell 按钮：传送到 Workspace/Shop02/PrisonerTouch 上方（Y 偏移可配置）。
4. 服务端对 RequestQuickTeleport 做参数白名单和请求防抖校验。

四、维护约束
1. 未来新增事件必须同步更新:
- 本文件
- 架构设计文档.lua
- RemoteNames.lua
- RemoteEventService.lua

2. 所有 C->S 行为必须做服务端校验。
3. 点赞数据为永久数据，存储在 PlayerData.SocialState。
4. 快捷传送坐标由服务端计算，客户端不得直传世界坐标。

=====================================================
列表结束
=====================================================
]]