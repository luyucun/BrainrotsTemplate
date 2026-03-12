--[[
=====================================================
RemoteEvent 当前列表（V1.8.1）
=====================================================

文档更新时间: 2026-03-10
说明: V1.8.1 调整 Claim 粒子实现方式（事件定义不变），Claim 领取音效仍由 ClaimCashFeedback 触发。

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
   │  ├─ RequestQuickTeleport (RemoteEvent) [V1.5]
   │  └─ ClaimCashFeedback (RemoteEvent) [V1.8]
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

9. RequestQuickTeleport (C->S) [V1.5]
- 参数:
  - payload.target: string (Home/Shop/Sell)
- 用途: 玩家点击 Main/Top 快捷按钮后，请求服务端执行传送。
- 校验:
  - 仅允许 Home/Shop/Sell 三种目标。
  - 目标坐标由服务端读取场景节点，不信任客户端坐标。

10. ClaimCashFeedback (S->C) [V1.8]
- 参数:
  - positionKey: string
  - claimKey: string
  - timestamp: number
- 用途: 仅通知触发领取的玩家在本地播放领取音效（SoundService/Audio/ADDCash）。

11. BrainrotStateSync (S->C)
- 参数:
  - inventory: array
  - placed: array
  - equippedInstanceId: number
  - totalProductionBaseSpeed: number [V1.7]
  - totalProductionMultiplier: number [V1.7]
  - totalProductionSpeed: number [V1.7]
- 用途: 同步脑红背包/放置/装备状态与当前总产速信息。

12. RequestBrainrotStateSync (C->S)
- 参数: 无
- 用途: 客户端主动拉取脑红状态。

三、V1.8.1 行为补充
1. Claim 触碰触发后，服务端执行按压动画/脑红弹跳/粒子特效（Claim 本体不动，优先驱动 Touch）。
2. Claim 触碰规则:
- 仅触碰 Claim/Touch 的 Touch 节点才视为有效触碰。
- 持续站立不动只触发一次。
- 站在 Claim 上移动不会再次触发。
- 离开 Claim 后再次触碰可再次触发（受 ClaimTouchDebounceSeconds 限制）。
3. 粒子特效改为从 ReplicatedStorage/Effect/Claim 复制发射器并挂载到 Touch：Glow/Smoke 各 Emit(1) 后按生命周期销毁，Money/Stars 固定 1.5 秒移除；快速重复触发时先清旧粒子再重建。
4. ClaimCashFeedback 只下发给触发者本人，实现“只有自己听到”的音效。
5. 排行榜仍为仅 Cash 列，不显示 Rank；Cash 使用 K/M/B 大数值显示。

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

五、V2.1 武器击飞补充（2026-03-12）
1. 新增 WeaponKnockbackService（服务端）。
2. 判定方式：Tool.Activated + Handle.Touched（服务端）。
3. 本次无新增 RemoteEvent，RemoteNames.lua / RemoteEventService.lua 结构不变。
]]