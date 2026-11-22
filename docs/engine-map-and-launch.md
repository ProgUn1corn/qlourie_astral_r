# Astral 发动机模式、增压与发车控制

## 驾驶员控制

MAP、比赛 BOOST 和 LAUNCH 各自保存选择。三个发车预设各有 `rpm` 和 `torquePercent`。按下 Start 后，LC 应用所选限转和限扭，发车 ALS 开始按涡轮轴转速补能。

| 选择 | 控制内容 | 生效时机 |
| --- | --- | --- |
| MAP | Road/Stage 的升挡点火切断时间、怠速、常态限转和基础废气阀压力偏移。每张 Stage 选择踏板曲线和赛段 ALS 标定，可选关闭 ALS | 切图时应用。街机换挡点应和当前限转匹配 |
| BOOST | 驾驶员用独立旋钮选择增压减量，0 mbar 表示不减 | 停车和行驶中都可换档。所有 MAP 共用同一 BOOST 选档，切图只更新 MAP 的基础偏移 |
| LAUNCH | 独立选择发车 RPM 和发动机扭矩上限 | Stage 允许使用。按下 Start 激活所选预设并发布 `launchActive`。扭矩上限立即生效，发动机升到所选转速才触发限转 |

按速魔 NeoX 的布局，下方两个旋钮分别给 Engine MAP 和 BOOST。两个拇指滚轮预留给主动中差，分别调油门 map 和刹车 map。Launch Control 用独立按键激活当前发车预设。

BOOST 提供可绑定的上一档和下一档动作。发车期间，废气旁通阀仍按踏板请求、当前 MAP 的基础偏移和 BOOST 旋钮选档工作。发车扭矩上限直接作用于发动机。

## Launch 与 ALS 的关系

Škoda Fabia Rally2 evo 有两个操作件。中央面板的 Stage 按钮切换 Road/Stage，MAP SW 旋钮选择松油门时的 ALS 等级，1 档关闭，5 档最强。发车流程要求选好发车 RPM 和 ALS、进入 Stage，再按 Launch Start，踩住油门至少 3 秒给涡轮升速。Polo GTI R5 的 Engine Map 旋钮则把 Road 放在 0 档，其余档位选择不同 Stage 标定，1 档明确关闭 ALS。Polo 同样另有 Start 按键。两车手册都把选赛段设置和启动发车程序列为不同操作。〔Škoda Motorsport，Fabia Rally2 evo User Manual，2022-07-29，第 50～53 页。Volkswagen Motorsport，Polo GTI R5 Manual B.2，第 12、14 页。〕

现代 i20 N Rally2 的检修流程要求在不同 ALS 和 RPM 设置下检查发车时的涡轮转速及压力。该流程没有给出内部控制算法。[Hyundai Motorsport，i20 N Rally2 手册，PDF 第 169 页](https://hyundairacingparts.com/wp-content/uploads/2026/01/User-Manual-v4-v2-i20n-Rally2.pdf#page=169)

离合分离时，发动机可以很快到达发车限转，涡轮仍需要排气能量才能升速。有些 ECU 在发车期间推迟点火，把更多能量送到涡轮端；Haltech 称这类做法为 Launch Anti-Lag。只听爆响无法判断 ECU 用了哪种标定，也无法读出实际建压速度。[Haltech 的 Launch Control 说明](https://support.haltech.com/portal/en/kb/articles/how-launch-control-works)

Astral 的 Turbo A、B 和 RX 共用一个 ALS 控制器。正常行驶时，Stage 1～3 分别选择 Soft、Medium、Aggressive。按下 Start 后，LC 发布 `launchActive = 1`，发车 ALS 接管涡轮补能。发动机在怠速、零油门时即可开始建压。

发车中仍可换到另一张允许 Launch 的 Stage MAP，踏板图随之更新，正在使用的发车预设继续生效。发车结束时，LC 清除激活状态并解除发车限转和限扭，ALS 将补能请求归零。切回 Road 会取消发车。

## BOOST 的实车依据

Fabia Rally2 evo 通过中央菜单设置五档 BOOST。原厂调整程序要求主电源开、点火关，并举出 pop-off 频繁开启或路况困难时降低增压的用途。i20 N Rally2 把 BOOST 做成方向盘旋钮，其中三档分别降低 20、40 和 80 mbar。现代的旋钮说明没有写停车条件；车手实际多久动一次、ECU 在哪些负荷下立即接受，手册没有说明。〔Škoda 同册第 54～56 页；[现代手册，PDF 第 61～63 页](https://hyundairacingparts.com/wp-content/uploads/2026/01/User-Manual-v4-v2-i20n-Rally2.pdf#page=62)〕

## Lua 分工

| 模块 | 现有能力与拟议改动 |
| --- | --- |
| [engineMap.lua](../vehicles/qlourie_astral_r/lua/controller/engineMap.lua) | 沿用已有的 `setParameters` 分发。在切图、车辆复位时应用常态参数，将原来由 Launch 每帧写入的 `idleAV`、`revLimiterAV` 移回这里。现有 `throttleMap` 继续选择踏板图 |
| [launchControl.lua](../vehicles/qlourie_astral_r/lua/controller/launchControl.lua) | 接收 Stage 许可，保存预设。按键激活时调用原厂 `setTempRevLimiter`，退出时调用 `resetTempRevLimiter`。`twoStep` 跟随实际激活状态 |
| [eWasteGate.lua](../vehicles/qlourie_astral_r/lua/controller/eWasteGate.lua) | 综合踏板请求、MAP 基础偏移与 BOOST 减量，调用原厂 `setWastegateOffset`。赛段保转期间按涡轮的 `pressurePSI` 曲线换算所需压力，最高取当前比赛增压上限。LC 直接限扭 |
| [dynamicAntiLag.lua](../vehicles/qlourie_astral_r/lua/controller/dynamicAntiLag.lua) | 赛段收油时按所选档位保转。发车期间改用涡轮零件的发车目标。两种工况都通过 `engine:setAntilagCoef()` 补能 |
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

### 3. 独立 BOOST（已接入）

`eWasteGate` 保存 BOOST 选档，在切换 MAP 时接收基础偏移。验证旋钮时保持踏板请求和 MAP 相同，激活或取消 Launch 后，废气阀仍按当前 BOOST 选档计算目标。

### 4. 发车与赛段 ALS

各涡轮的 `dynamicAntiLag.launchTurboTargetRPM` 指定发车时的涡轮轴目标转速，初值为 135,100 RPM。验证时，选允许发车的 Stage，停车怠速，松开油门按 Start。观察 `alsActive` 是否启动、`turboRPM` 是否上升，再单独观察 `turboBoost`。再次按 Start 或起跑达到 10 km/h 时，`alsActive` 应关闭，涡轮随后按实际负荷运转。

每套涡轮 ECU 的 Stage 设置行用 `minTurboRPM` 指定收油后的最低涡轮轴速，单位为 RPM。

| Stage | Rally2 | 其他涡轮 ECU |
| --- | ---: | ---: |
| 1 · Soft | 95,000 | 45,000 |
| 2 · Medium | 110,000 | 65,000 |
| 3 · Aggressive | 125,000 | 85,000 |

行驶时油门达到 5% 后，收至 2% 或以下即采用该档目标。涡轮高于目标时自然回落，低于目标时 ALS 补能。如果收油时轴速已经更低，就以收油时的轴速为上限。发动机接近怠速时，目标逐渐降到零。再次给油达到 5%、切回 Road 或进入 Launch 都会结束这次保转。

三档共用 10 秒的赛段工作上限，从收油开始计时。中途切换 Stage 会沿用已经过去的时间。超时后须重新给油再收油，才能触发下一轮。Launch 按自己的退出条件运行。

试车时对照 `stageAlsTargetRPM` 和 `turboRPM` 看目标与实际轴速，再用 `boostTargetPsi` 看废气阀目标。赛段保转退出时，`stageAlsTargetRPM` 归零，废气阀恢复踏板请求。

### 5. 接 Road/Stage 换挡

在序列箱原有升挡逻辑实际调用 `cutIgnition` 的地方接入所选时长。先验证一个能在运行时取到该值的最小方案，再核对街机模式的升挡点可以随 Road/Stage 切换。验证手动升挡和街机自动升挡两个入口。这个部分只依赖第 1 步的 MAP，传动侧可以独立推进。
