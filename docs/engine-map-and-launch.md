# Astral 发动机模式、增压与发车控制

## 驾驶员控制

MAP、比赛 BOOST 和 LAUNCH 各自保存选择。三个发车预设各有 `rpm` 和 `torquePercent`。按下 Start 后进入待命，手刹输入超过 60% 时 LC 应用所选限转和限扭，启用 ALS 的 MAP 会按涡轮轴速差补能。

| 选择 | 控制内容 | 生效时机 |
| --- | --- | --- |
| MAP | Road/Stage 的升挡点火切断时间、怠速、常态限转和基础废气阀压力偏移。每张 Stage 选择踏板曲线和赛段 ALS 标定，可选关闭 ALS | 切图时应用。街机换挡点应和当前限转匹配 |
| BOOST | 驾驶员用独立旋钮选择增压减量，0 mbar 表示不减 | 停车和行驶中都可换档。所有 MAP 共用同一 BOOST 选档，切图只更新 MAP 的基础偏移 |
| LAUNCH | 独立选择发车 RPM 和发动机扭矩上限 | Stage 允许使用。按下 Start 锁定预设并显示 LAUNCH READY。手刹超过 60% 后发布 `launchActive`，扭矩上限生效，发动机升到所选转速才触发限转 |

按速魔 NeoX 的布局，下方两个旋钮分别给 Engine MAP 和 BOOST。两个拇指滚轮预留给主动中差，分别调油门 map 和刹车 map。Launch Control 用独立按键进入或取消发车待命。

所有车型默认从 MAP 1（Road）生成。拉力车可在「发动机与控制单元 → 生成时的发动机 MAP」选择 MAP 1～5。拉力车按 Road → Stage Soft → Stage Low → Stage Med → Stage High 循环，RX 的四个位置依次为 Road、Stage Low、Stage Med、Stage High。旋钮与调校菜单从 1 编号，底层 mapId 和保存的调校变量仍从 0 计数。

### 拉力车型的 eWasteGate 与 ALS

拉力车的四张 Stage 使用同一踏板图和全负荷增压标定。MAP 2（Stage Soft）关闭赛段 ALS。MAP 3、4、5 的赛段 ALS 依次为 Soft、Medium、Aggressive，各档的 `powerCoef` 决定可用补能功率。

全松油时，`closedThrottleBoostByRPM` 按发动机转速给出目标。例如 WRC17 在 4800 rpm 及以下请求零表压，涡轮会凭惯性继续转动。继续给油时，`targetFractions` 按映射后的油门，在收油曲线和 `fullThrottleBoostByRPM` 之间插值。两张转速表的第二列都是基础表压的比例。eWasteGate 再用涡轮的 `pressurePSI` 曲线把目标表压换算成目标轴速。制动降挡时，ALS 按目标与实际轴速之差补能，原生涡轮用实际轴速驱动啸叫音调。

停车空挡或踩下离合时，普通轰油的废气阀目标上限为 1.5 psi（约 0.10 bar）。挂挡接合离合，或车辆开始滚动后，上限逐渐放开。车身对地速度达到 4 m/s 时，即可使用完整的赛段标定。

手刹触发发车程序后，eWasteGate 放开普通空轰上限，继续使用本车的收油与全负荷转速表。松油怠速时不请求涡轮补能，实际表压保持在怠速负压。开启 ALS 时，控制器按当前档位设置放炮倍率，并短暂断火，让排气产生爆音。踩油门后，目标压力随踏板和发动机转速上升。高转时松油，目标随发动机回落，实际压力随涡轮减速下降。LC1、LC2、LC3 共用这套逻辑，各自保留发车限转和限扭。发车沿用当前 MAP 的 ALS 功率系数。MAP 2 只靠发动机排气建压，MAP 3～5 分别最多使用 14%、30%、100% 的 ALS 补能功率。退出发车后恢复比赛 BOOST 减量。

### 各车标定与整车验证

WRC17 Finland 作为响应基准。测试在四挡松油轻刹 1.83 秒，再踩满油门，按 60 Hz 记录实际表压。各车沿用 MAP 3、4、5 的补能系数 0.14、0.30、1.00。先按发动机常用转速调整收油曲线，再核对四档重新达到 1 bar 表压的时间。

| 测试配置 | 涡轮 | 收油目标为零的最高转速 | 全油目标达到额定表压的转速 | 复踩到 1 bar，按 MAP 2 / 3 / 4 / 5 排列（秒） |
| --- | --- | ---: | ---: | --- |
| WRC17 Finland | A | 4800 rpm | 5500 rpm | 0.65 / 0.45 / 0.37 / 0.22 |
| Rally1 2022 | A | 5500 rpm | 6000 rpm | 0.60 / 0.42 / 0.33 / 0.18 |
| Rally1 2025 | A | 5200 rpm | 5850 rpm | 0.62 / 0.45 / 0.38 / 0.23 |
| Rally2 Finland、WRC Kit | B | 4250 rpm | 5100 rpm | 0.63 / 0.45 / 0.37 / 0.20 |
| WRC16 | B | 4250 rpm | 5100 rpm | 0.63 / 0.45 / 0.37 / 0.22 |

改前，Rally1 2022 的中、强两档在复踩前仍高于 1 bar。Rally2 同两档的回压时间只差约 0.03 秒。现在两个车型分别相差约 0.15 和 0.17 秒。五款衍生配置的原生静态扭矩曲线逐点相同，3000 rpm 全油稳态带载扭矩的改前、改后差值均在 0.003 Nm 以内。

瞬时和持续放炮各用自己的装车基础系数，两者共用倍率 `1 + 19 × 放炮请求`。赛段和给油发车时使用实际 ALS 补能请求。手刹触发程序后的松油怠速期间，启用 ALS 的档位用当前 `powerCoef` 计算放炮倍率，涡轮补能请求保持为零。WRC17 和 Rally2 的瞬时基础系数为 4.2，持续为 3。请求为 0、0.5、1 时，瞬时系数分别为 4.2、44.1、84，持续系数分别为 3、31.5、60。

Turbo A、B 参照 Vivace 1.6 比赛涡轮，在 `mainEngine` 中给瞬时和持续放炮系数各乘 3，给持续放炮音量系数乘 1.5。这三项与发动机、ECU 的标定叠乘。BeamNG 根据排气端累积量、发动机负荷和音效冷却时间决定是否触发爆音，单次播放音量由对应的音量系数和排气端音量决定。

## Launch 与 ALS 的关系

Škoda Fabia Rally2 evo 有两个操作件。中央面板的 Stage 按钮切换 Road/Stage，MAP SW 旋钮选择松油门时的 ALS 等级，1 档关闭，5 档最强。发车流程要求选好发车 RPM 和 ALS、进入 Stage，再按 Launch Start，踩住油门至少 3 秒给涡轮升速。Polo GTI R5 的 Engine Map 旋钮则把 Road 放在 0 档，其余档位选择不同 Stage 标定，1 档明确关闭 ALS。Polo 同样另有 Start 按键。两车手册都把选赛段设置和启动发车程序列为不同操作。〔Škoda Motorsport，Fabia Rally2 evo User Manual，2022-07-29，第 50～53 页。Volkswagen Motorsport，Polo GTI R5 Manual B.2，第 12、14 页。〕

现代 i20 N Rally2 的检修流程要求在不同 ALS 和 RPM 设置下检查发车时的涡轮转速及压力。该流程没有给出内部控制算法。[Hyundai Motorsport，i20 N Rally2 手册，PDF 第 169 页](https://hyundairacingparts.com/wp-content/uploads/2026/01/User-Manual-v4-v2-i20n-Rally2.pdf#page=169)

离合分离时，发动机可以很快到达发车限转，涡轮仍需要排气能量才能升速。有些 ECU 在发车期间推迟点火，把更多能量送到涡轮端；Haltech 称这类做法为 Launch Anti-Lag。只听爆响无法判断 ECU 用了哪种标定，也无法读出实际建压速度。[Haltech 的 Launch Control 说明](https://support.haltech.com/portal/en/kb/articles/how-launch-control-works)

Astral 的 Turbo A、B 和 RX 共用一个 ALS 控制器。各 ECU 在 Stage 设置行选择赛段 ALS 档位。按下 Start 后，LC 发布 `launchArmed = 1`。等待手刹期间 ALS 补能为零。手刹触发后 LC 发布 `launchActive = 1`，启用 ALS 的 MAP 开始执行发车 ALS 逻辑。

发车中仍可换到另一张允许 Launch 的 Stage MAP，ALS 强度随 MAP 更新，正在使用的发车预设继续生效。发车结束时，LC 清除激活状态并解除发车限转和限扭，赛段 ALS 重新接管。切回 Road 会取消发车。

## BOOST 的实车依据

Fabia Rally2 evo 通过中央菜单设置五档 BOOST。原厂调整程序要求主电源开、点火关，并举出 pop-off 频繁开启或路况困难时降低增压的用途。i20 N Rally2 把 BOOST 做成方向盘旋钮，其中三档分别降低 20、40 和 80 mbar。现代的旋钮说明没有写停车条件；车手实际多久动一次、ECU 在哪些负荷下立即接受，手册没有说明。〔Škoda 同册第 54～56 页；[现代手册，PDF 第 61～63 页](https://hyundairacingparts.com/wp-content/uploads/2026/01/User-Manual-v4-v2-i20n-Rally2.pdf#page=62)〕

## Lua 分工

| 模块 | 现有能力与拟议改动 |
| --- | --- |
| [engineMap.lua](../vehicles/qlourie_astral_r/lua/controller/engineMap.lua) | 沿用已有的 `setParameters` 分发。在切图、车辆复位时应用常态参数，将原来由 Launch 每帧写入的 `idleAV`、`revLimiterAV` 移回这里。现有 `throttleMap` 继续选择踏板图 |
| [launchControl.lua](../vehicles/qlourie_astral_r/lua/controller/launchControl.lua) | 接收 Stage 许可，保存预设。手刹触发执行时调用原厂 `setTempRevLimiter`，退出时调用 `resetTempRevLimiter`。`twoStep` 跟随实际激活状态 |
| [eWasteGate.lua](../vehicles/qlourie_astral_r/lua/controller/eWasteGate.lua) | 综合踏板请求、MAP 基础偏移与 BOOST 减量，调用原厂 `setWastegateOffset`。拉力车型同时向 ALS 提供目标轴速 |
| [dynamicAntiLag.lua](../vehicles/qlourie_astral_r/lua/controller/dynamicAntiLag.lua) | 拉力车型跟随废气阀目标轴速，RX1 使用自己的保转和发车标定。通过 `engine:setAntilagCoef()` 补能 |
| 序列变速箱 | 原厂序列箱负责选择挡位和自动离合。`shiftLogic-astralSequential.lua` 将原厂街机换挡表提供给 `engineMap`，由 MAP 切换高负荷升降挡点和带油升挡断火时间 |

## Lua 实施顺序

### 1. 让 MAP 持有常态怠速和限转

第一批改三个文件，沿用各 ECU 现有标定。

- `engineMap.lua`：在现有 `applyDriveMode` 增加应用发动机常态参数的分支。进入 Road 时应用 Road 设定，回到 Stage 时恢复该 ECU 的比赛设定。车辆生成、复位和恢复已选地图沿用现有切图入口。
- `launchControl.lua`：移除每帧写 `idleAV`、`revLimiterAV` 的代码及其参数接收逻辑。发车期间照旧调用原厂临时限转接口。
- [Astral_ecu.jbeam](../vehicles/qlourie_astral_r/engine/Astral_ecu.jbeam)：把各 ECU 的常态 RPM 字段从 Launch 设置行移到 MAP 的发动机设置行。保留各车型自己的比赛默认值。

完成条件：默认生成、Road → Stage → Road、车辆复位都能选对常态限转。单独修改发车 RPM 对常态限转没有副作用。

### 2. 把 Launch 许可、预设和激活拆开

`engineMap` 通过 `setParameters({isAllowed = ...})` 分发许可。ECU 的 `launchControl.presets` 按顺序引用三组 RPM 和扭矩百分比。点动力控制面板上的 LC 按钮可依次选择 LC1、LC2、LC3。方向盘和键盘都能绑定上一档、下一档或直选某一档。独立的 Start 动作锁定预设，再按一次可取消待命或执行。

每个随车配置都在 `.pc` 的 `vars` 里保存六个值。`$launchRPM1`～`$launchRPM3` 是三档的发车转速，每格 100 rpm。`$launchTorque1`～`$launchTorque3` 是各档的峰值扭矩上限，从 50% 到 100%，每格 5 个百分点。调校菜单可以分别改这六个值，驾驶时用按键选择已调好的档位。

三档扭矩上限均默认 100%，沿用发动机原上限。低于 100% 时，发车程序开始执行时会把所装发动机的峰值扭矩 `engine.maxTorque` 乘以该档百分比，再与原扭矩上限取较小值，写入 `engine.maxTorqueLimit`。发车结束时恢复进入前的上限，车辆复位由原厂动力系统重新初始化。

在允许发车的 MAP 下，车身对地速度绝对值 ≤ 0.5 m/s 时可以按键待命。手刹输入超过 60% 时开始执行，按键时已超过门槛则立即执行。手刹回到 60% 或以下，LC 解除发车限转和限扭，停止发车 ALS，回到待命。仪表继续显示 LAUNCH READY，按钮保持红色。再次拉过 60% 就用同一预设重新执行。同一次发车可以切换到另一张允许发车的 Stage MAP。车速达到 10 km/h、再次按键、切回 Road 或复位都会退出发车控制。

仪表可以从 `electrics.values` 读取 `launchPreset`（从 1 起）、`launchArmed`（待命及执行期间为 1）、`launchActive`（仅执行期间为 1）和 `launchTargetRPM`（待命时显示，退出后为 0）。发车预设控制 RPM 和扭矩。

### 3. 独立 BOOST（已接入）

`eWasteGate` 保存 BOOST 选档，在切换 MAP 时接收基础偏移。验证旋钮时保持踏板请求和 MAP 相同。拉力车型在发车结束后恢复旋钮选定的减量。

### 4. 发车与赛段 ALS

拉力车型可用 `boostTargetPsi`、`boostTargetTurboRPM`、`turboRPM` 和 `turboBoost` 分别检查目标表压、目标轴速、实际轴速和实际表压。两个表压信号的单位都是 psi。RX1 读取涡轮零件的 `dynamicAntiLag.launchTurboTargetRPM`，初值为 135,100 rpm。再次按 Start 或起跑达到 10 km/h 时，检查 `launchActive` 是否清零。

下面的固定保转流程适用于 RX1。`minTurboRPM` 指定 Soft、Medium 和 Aggressive 三档的收油目标轴速，分别为 45,000、65,000 和 85,000 rpm。

行驶时油门达到 5% 后，收至 2% 或以下即采用该档目标。涡轮高于目标时自然回落，低于目标时 ALS 补能。如果收油时轴速已经更低，就以收油时的轴速为上限。发动机接近怠速时，目标逐渐降到零。再次给油达到 5%、切回 Road 或进入 Launch 都会结束这次保转。

三档共用 10 秒的赛段工作上限，从收油开始计时。中途切换 Stage 会沿用已经过去的时间。超时后须重新给油再收油，才能触发下一轮。Launch 按自己的退出条件运行。

试车时对照 `stageAlsTargetRPM` 和 `turboRPM` 看目标与实际轴速，再用 `boostTargetPsi` 看废气阀目标。赛段保转退出时，`stageAlsTargetRPM` 归零，废气阀恢复踏板请求。

### 5. 接 Road/Stage 换挡

Road 带油升挡断火 150 ms，Stage 六速为 52 ms、五速为 58 ms。手动升挡和街机自动升挡都使用当前 MAP 的时长。Road 在收油、制动和带油升挡时关闭排气放炮，切回 Stage 后恢复所装发动机、ECU 和涡轮的放炮标定。

街机在 Road 按「Road 限转 ÷ 比赛红线」缩放各前进挡的高负荷升降挡点。每挡的降挡点最高取上一挡升进来后预计转速的 95%，给断火期间的转速下降留出余量。Stage 恢复所装 ECU 的比赛换挡表。

五速和六速的自动离合沿用 Vivace 砂石拉力序列箱的起步设置，`clutchLaunchStartRPM` 为 3000，`clutchLaunchTargetRPM` 为 2000。两者在 Road 和 Stage 共用。LC1～LC3 的发车限转仍由 ECU 的发车预设决定。
