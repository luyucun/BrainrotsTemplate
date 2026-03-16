--[[
=====================================================
RemoteEvent 当前列表（V2.4.1）
=====================================================

文档更新时间: 2026-03-16
说明:
- V2.3 全局排行榜未新增 RemoteEvent。
- V2.4.1 特殊事件新增 2 个 RemoteEvent，用于同步客户端本地表现。
- /event <事件Id> 为 GM 聊天命令，由服务端直接处理。

一、事件树
ReplicatedStorage
- Events
  - CurrencyEvents
    - CoinChanged
    - RequestCoinSync
  - SystemEvents
    - HomeAssigned
    - LikeTip
    - SocialStateSync
    - RequestSocialStateSync
    - FriendBonusSync
    - RequestFriendBonusSync
    - RequestQuickTeleport
    - ClaimCashFeedback
    - RebirthStateSync
    - RequestRebirthStateSync
    - RequestRebirth
    - RebirthFeedback
    - SpecialEventStateSync
    - RequestSpecialEventStateSync
  - BrainrotEvents
    - BrainrotStateSync
    - RequestBrainrotStateSync

二、事件详情
1. CoinChanged（S -> C）
- 参数: total / delta / reason / timestamp
- 用途: 金币数值同步，并驱动本地金币滚动反馈。

2. RequestCoinSync（C -> S）
- 参数: 无
- 用途: 客户端主动请求最新金币数据。

3. HomeAssigned（S -> C）
- 参数: homeId
- 用途: 告知客户端当前玩家被分配到哪个家园。

4. LikeTip（S -> C）
- 参数: message / timestamp
- 用途: 给点赞发送方或被点赞方弹出提示。

5. SocialStateSync（S -> C）
- 参数: likedOwnerUserIds
- 用途: 同步当前玩家已经点过赞的家园主人列表，用于 Prompt 可见性过滤。

6. RequestSocialStateSync（C -> S）
- 参数: 无
- 用途: 客户端主动请求社交状态。

7. FriendBonusSync（S -> C）
- 参数: friendCount / bonusPercent / timestamp
- 用途: 同步当前同服好友数量与加成百分比。

8. RequestFriendBonusSync（C -> S）
- 参数: 无
- 用途: 客户端主动请求好友加成状态。

9. RequestQuickTeleport（C -> S）
- 参数: payload.target（Home / Shop / Sell）
- 用途: 请求服务端执行快捷传送。
- 校验: 仅允许固定枚举目标，坐标始终由服务端解析。

10. ClaimCashFeedback（S -> C）
- 参数: positionKey / claimKey / timestamp
- 用途: 只通知触发领取的玩家，在本地播放领取音效与金币飞散回收特效。
- 规则: 仅当该位置确实有已放置脑红且本次真实领取到金币时才下发。

11. RebirthStateSync（S -> C）
- 参数: rebirthLevel / currentBonusRate / nextRebirthLevel / nextRequiredCoins / nextBonusRate / maxRebirthLevel / isMaxLevel / currentCoins / timestamp
- 用途: 刷新 Rebirth 面板和主界面左侧 Rebirth 显示。

12. RequestRebirthStateSync（C -> S）
- 参数: 无
- 用途: 客户端主动请求最新 Rebirth 状态。

13. RequestRebirth（C -> S）
- 参数: 无
- 用途: 发起一次 Rebirth 请求。
- 校验: 服务端根据当前玩家真实数据判断是否满足条件。

14. RebirthFeedback（S -> C）
- 参数: status / message / timestamp
- 用途: 返回成功提示或失败原因。
- 状态值: Success / RequirementNotMet / AlreadyMax

15. SpecialEventStateSync（S -> C）
- 参数: activeEvents / serverTime / timestamp
- activeEvents[i]: runtimeKey / eventId / name / templateName / lightingPath / startedAt / endsAt / source
- 用途: 同步当前服务器正在生效的特殊事件列表，供客户端在本地挂角色事件模板和本地切换天空盒。

16. RequestSpecialEventStateSync（C -> S）
- 参数: 无
- 用途: 客户端主动请求当前特殊事件状态，避免本地启动晚于首次服务端推送时漏掉事件。

17. BrainrotStateSync（S -> C）
- 参数: inventory / placed / equippedInstanceId / unlockedBrainrotIds / discoveredCount / discoverableCount / totalProductionBaseSpeed / totalProductionMultiplier / totalProductionSpeed
- 用途: 同步脑红背包、放置状态、图鉴解锁历史，以及当前总产速汇总信息。

18. RequestBrainrotStateSync（C -> S）
- 参数: 无
- 用途: 客户端主动请求脑红与图鉴状态。

三、行为补充说明
1. Index 界面继续复用 BrainrotStateSync，不额外新增 Index 专属 RemoteEvent。
2. Claim UI 路径已切换为 ClaimX/Touch/.../Money(Frame)，但网络事件结构不变。
3. Rebirth 成功后会重新下发 RebirthStateSync 与 BrainrotStateSync，以刷新前端表现。
4. 全局排行榜公共榜单由服务端直接渲染到场景 UI，底部个人卡使用玩家 Attribute，不通过 RemoteEvent 驱动。
5. TotalPlaySeconds 为永久数据，其更新逻辑不依赖新增 RemoteEvent。
6. V2.4.1 起，特殊事件改为“服务端调度 + 客户端本地表现”。
7. 服务端负责 UTC 调度、权重选择、GM /event、当前活跃事件状态同步。
8. 客户端负责本地复制 ReplicatedStorage/Event 模板到自己角色，以及本地复制 Lighting 事件天空盒子节点到 Lighting。

四、维护约束
1. 当 RemoteEvent 发生变化时，必须同步更新：
- 本文件
- 架构设计文档.lua
- RemoteNames.lua
- RemoteEventService.lua

2. 所有客户端 -> 服务端请求都必须保留服务端校验。
3. ClaimCashFeedback 必须继续保持 FireClient 给触发者本人，不可广播。
4. 特殊事件当前只同步“事件状态”，不直接同步具体本地实例；客户端负责根据状态自己生成和移除本地表现。

=====================================================
列表结束
=====================================================
]]