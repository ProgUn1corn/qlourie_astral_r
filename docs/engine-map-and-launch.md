# Astral 发动机模式、增压与发车控制

## 驾驶员控制

本稿记录电控设计。MAP、比赛 BOOST 和 LAUNCH 各自保存选择。Launch 生效时独立决定发车转速及发车压力或扭矩，退出后恢复当前赛段设置。发车建压速度和各档数值还有待游戏内测量。

普通 BOOST、发车限转和发车限扭已接入。三个发车预设各有 `rpm` 和 `torquePercent`。发车压力目标和 ALS 补能留到下一阶段。

| 选择 | 控制内容 | 生效时机 |
| --- | --- | --- |
| MAP | Road/Stage 的升挡点火切断时间、怠速、常态限转和基础废气阀压力偏移。每张 Stage 选择踏板曲线和赛段 ALS 标定，可选关闭 ALS | 切图时应用。街机换挡点应和当前限转匹配 |
| BOOST | 驾驶员用独立旋钮选择增压减量，0 mbar 表示不减 | 停车和行驶中都可换档。所有 MAP 共用同一 BOOST 选档，切图只更新 MAP 的基础偏移 |
| LAUNCH | 独立选择发车预设，含发车 RPM，以及目标表压或发动机扭矩上限 | Stage 允许使用。按下 Launch 且激活成功就开始请求建压，到达发车转速才限转。踏板曲线和换挡时间继续服从当前 MAP |

按速魔 NeoX 的布局，下方两个旋钮分别给 Engine MAP 和 BOOST。两个拇指滚轮预留给主动中差，分别调油门 map 和刹车 map。Launch Control 用独立按键激活当前发车预设。

BOOST 提供可绑定的上一档、下一档动作。普通行驶中转动旋钮，当次选档即更新比赛目标。发车压力接管期间也接受旋钮输入，只更新保存的 BOOST 选档；退出发车时使用最新选档。

## 压力与状态

| 状态 | 废气旁通阀控制 |
| --- | --- |
| 普通行驶，或已选预设但尚未激活 Launch | 给原厂的偏移 = 当前 MAP 的基础 offset − BOOST 减量（先换算为 psi）。Road 的基础 offset 已抵消涡轮基准，任何减量都不会产生正的增压目标 |
| Launch 已激活且预设含发车压力 | 从按键激活起直接采用预设的目标表压，包括怠速和升转阶段。比赛 BOOST 选档仍可更新 |
| 发车结束或取消 | 按当前 MAP 的基础 offset 和最新 BOOST 选档恢复普通计算 |

例如赛段基准为 1.50 bar 表压，BOOST 减 200 mbar，发车目标为 1.40 bar 表压。目标依次为 **1.30 → 1.40 → 1.30 bar**。这是给控制器的目标，实际压力还取决于涡轮获得的能量。对于只选扭矩限制的预设，扭矩以发动机 N·m 标定。若需要控制松离合后的最初几米，应为这段限扭单独定义退出条件。

## Launch 与 ALS 的关系

Škoda Fabia Rally2 evo 有两个操作件。中央面板的 Stage 按钮切换 Road/Stage，MAP SW 旋钮选择松油门时的 ALS 等级，1 档关闭，5 档最强。发车流程要求选好发车 RPM 和 ALS、进入 Stage，再按 Launch Start，踩住油门至少 3 秒给涡轮升速。Polo GTI R5 的 Engine Map 旋钮则把 Road 放在 0 档，其余档位选择不同 Stage 标定，1 档明确关闭 ALS。Polo 同样另有 Start 按键。两车手册都把选赛段设置和启动发车程序列为不同操作。〔Škoda Motorsport，Fabia Rally2 evo User Manual，2022-07-29，第 50～53 页。Volkswagen Motorsport，Polo GTI R5 Manual B.2，第 12、14 页。〕

现代 i20 N Rally2 的检修流程要求在不同 ALS 和 RPM 设置下检查发车时的涡轮转速及压力。该流程没有给出内部控制算法。[Hyundai Motorsport，i20 N Rally2 手册，PDF 第 169 页](https://hyundairacingparts.com/wp-content/uploads/2026/01/User-Manual-v4-v2-i20n-Rally2.pdf#page=169)

离合分离时，发动机可以很快到达发车限转，涡轮仍需要排气能量才能升速。有些 ECU 在发车期间推迟点火，把更多能量送到涡轮端；Haltech 称这类做法为 Launch Anti-Lag。只听爆响无法判断 ECU 用了哪种标定，也无法读出实际建压速度。[Haltech 的 Launch Control 说明](https://support.haltech.com/portal/en/kb/articles/how-launch-control-works)

Astral 的每张 Stage MAP 自带赛段 ALS 标定。车手选一次 MAP 就确定了正常行驶时的踏板响应和松油 ALS。按下 Launch 并成功激活时，即使发动机还在怠速、驾驶员尚未踩油门，Launch 也会提出独立的发车建压请求。即使赛段 ALS 选为关闭，发车请求也可以生效。实际压力由涡轮响应决定。

按键激活时同时设好临时发车转速上限。发动机可以继续升转，达到上限时才执行限转。发车中仍可换到另一张允许 Launch 的 Stage MAP，踏板图等常态设置随之更新，正在使用的发车预设继续生效。结束发车时撤销建压请求和临时限转，赛段 ALS 随即按当前 MAP 工作。切回 Road 会取消发车。

现有 ALS 源自 BeamNG 原厂实现。接发车建压时可以重写赛段与发车各自的触发和退出条件，单独评估现有 `antilagCoef` 估算是否适用。原有的车速门槛属于旧代码。

## BOOST 的实车依据

Fabia Rally2 evo 通过中央菜单设置五档 BOOST。原厂调整程序要求主电源开、点火关，并举出 pop-off 频繁开启或路况困难时降低增压的用途。i20 N Rally2 把 BOOST 做成方向盘旋钮，其中三档分别降低 20、40 和 80 mbar。现代的旋钮说明没有写停车条件；车手实际多久动一次、ECU 在哪些负荷下立即接受，手册没有说明。〔Škoda 同册第 54～56 页；[现代手册，PDF 第 61～63 页](https://hyundairacingparts.com/wp-content/uploads/2026/01/User-Manual-v4-v2-i20n-Rally2.pdf#page=62)〕

## Lua 分工

| 模块 | 现有能力与拟议改动 |
| --- | --- |
| [engineMap.lua](../vehicles/qlourie_astral_r/lua/controller/engineMap.lua) | 沿用已有的 `setParameters` 分发。在切图、车辆复位时应用常态参数，将原来由 Launch 每帧写入的 `idleAV`、`revLimiterAV` 移回这里。现有 `throttleMap` 继续选择踏板图 |
| [launchControl.lua](../vehicles/qlourie_astral_r/lua/controller/launchControl.lua) | 接收 Stage 许可，保存预设。按键激活时调用原厂 `setTempRevLimiter`，退出时调用 `resetTempRevLimiter`。`twoStep` 跟随实际激活状态 |
| [eWasteGate.lua](../vehicles/qlourie_astral_r/lua/controller/eWasteGate.lua) | 综合踏板请求、MAP 基础偏移与 BOOST 减量，调用原厂 `setWastegateOffset`。已预留在 `launchActive` 生效且提供 `launchBoostTargetPsi` 时接管压力的入口 |
| 赛段 ALS（策略待设计） | 接收 MAP 选定的 ALS 等级。若发车和赛段最终共用 `engine:setAntilagCoef()`，由一处写入该接口，按实际发车状态切换请求 |
| 序列变速箱 | 沿用原厂升挡判断和 `engine:cutIgnition()`。原厂在初始化时把 `ignitionCutTime` 读进局部变量。后续只验证动态传入切断时长的最小改动，街机升挡点单独核对 |

## Lua 实施顺序

### 1. 让 MAP 持有常态怠速和限转

第一批改三个文件，沿用各 ECU 现有标定。

- `engineMap.lua`：在现有 `applyDriveMode` 增加应用发动机常态参数的分支。进入 Road 时应用 Road 设定，回到 Stage 时恢复该 ECU 的比赛设定。车辆生成、复位和恢复已选地图沿用现有切图入口。
- `launchControl.lua`：移除每帧写 `idleAV`、`revLimiterAV` 的代码及其参数接收逻辑。发车期间照旧调用原厂临时限转接口。
- [Astral_ecu.jbeam](../vehicles/qlourie_astral_r/engine/Astral_ecu.jbeam)：把各 ECU 的常态 RPM 字段从 Launch 设置行移到 MAP 的发动机设置行。保留各车型自己的比赛默认值。

完成条件：默认生成、Road → Stage → Road、车辆复位都能选对常态限转。单独修改发车 RPM 对常态限转没有副作用。

### 2. 把 Launch 许可、预设和激活拆开

`engineMap` 通过 `setParameters({isAllowed = ...})` 分发许可。ECU 的 `launchControl.presets` 按顺序引用三组 RPM 和扭矩百分比。点动力控制面板上的 LC 按钮可依次选择 LC1、LC2、LC3。方向盘和键盘都能绑定上一档、下一档或直选某一档。独立的 Start 动作激活或取消所选预设。

三档扭矩上限均默认 100%，沿用发动机原上限。低于 100% 时，按 Start 会把所装发动机的峰值扭矩 `engine.maxTorque` 乘以该档百分比，再与原扭矩上限取较小值，写入 `engine.maxTorqueLimit`。0% 封闭正燃烧扭矩。发车结束时恢复进入前的上限，车辆复位由原厂动力系统重新初始化。

在允许发车的 MAP 下，车身对地速度绝对值 ≤ 0.5 m/s 时可以按键激活。松手刹、挂挡或松油门都能保持发车状态。同一次发车使用按键时的预设，切换允许发车的 Stage 可继续。车身达到 10 km/h、再次按键、切回 Road 或复位都会解除临时限转。

仪表可以从 `electrics.values` 读取 `launchPreset`（从 1 起）、`launchActive`（0 或 1）和 `launchTargetRPM`（退出后为 0）。当前预设控制 RPM 和扭矩，比赛 BOOST 继续照常响应。

### 3. 接独立 BOOST 和发车目标

由 eWastegate 保存比赛 BOOST 选档，接收 MAP 基础设定，读取 Launch 的介入状态和压力目标。按“压力与状态”表只选一路目标，由 eWastegate 统一写原厂废气阀偏移。接入的 ECU 在同一批改动中移除旧的偏移写入行。使用扭矩型预设时，Launch 通过发动机现有扭矩上限执行、退出时恢复。

验证时，在 Stage 行驶中转动一格 BOOST，确认普通压力目标随即更新。往返切换 Road 和 Stage，检查 BOOST 选档保留。发车压力介入期间再转一格，确认发车目标保持原值，退出后按最新 BOOST 档恢复普通计算。

### 4. 接赛段 ALS 和发车建压

MAP 发送赛段 ALS 等级。ALS 模块在 `launchActive` 期间执行发车建压请求，退出后执行当前赛段策略，两种请求共用一个发动机输出。用“赛段 ALS 关、怠速按 Launch”验证发车建压能单独启动，再取消发车验证它会关闭。建压强度和响应速度留给游戏内标定。

### 5. 接 Road/Stage 换挡

在序列箱原有升挡逻辑实际调用 `cutIgnition` 的地方接入所选时长。先验证一个能在运行时取到该值的最小方案，再核对街机模式的升挡点可以随 Road/Stage 切换。验证手动升挡和街机自动升挡两个入口。这个部分只依赖第 1 步的 MAP，传动侧可以独立推进。
