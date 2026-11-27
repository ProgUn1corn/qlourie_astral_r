# Qlourie Astral R — Next release (draft)

**English** | [简体中文](./draft.zh-CN.md)

Back on a new PC, I finally rebuilt the dashboard that came out of Automation. I also went back to the rally engines’ boost figures and spent a fair bit of time on the dampers, particularly on the fast landings in Finland.

## Chassis and bodywork

- **Rebuilt the dashboard mesh.** The original Automation export had rough topology all across the dash. I redid the mesh and split out the centre console so it has its own flexbody attached to the chassis.

- Reworked the lower edge of the windscreen to go with the new wiper, adapted from *EA SPORTS WRC*.

- Moved both onboard camera meshes from the body nodes to the front chassis nodes, keeping their roll cage attachments to reduce mesh jitter in replays.

- Retopologized all front lip meshes.

- Fixed the 5 kg that disappeared when fitting the driver with animated hands. The driver reference node now weighs 12 kg in that configuration.

- Reduced the brake cooling coefficients on the front bumper ducts and rear intakes. For example, the WRC17 front duct options went from 1.48 and 1.40 to 1.25 and 1.15. The blanking plate uses 1.00.

### Aerodynamics

- **Retuned the bumpers and rear wings for more downforce and drag.** On the WRC17, the front bumper and diveplanes take a bigger share of the work. I also repositioned the rear diffuser nodes on the WRC17 and Rally1, restored the two aero triangles on the Rally1 rear undertray and increased the drag from the mud flaps.

- The Rally1 winglets used to catch a pure side wind across an oversized triangle. I redrew those surfaces and checked each rear wing with a 90 km/h wind blowing straight across the car. Fitting the wing added 137 N of side force on Rally1 and 115 N on WRC17. Under the same test, Rally2 added 22 N, WRC16 38 N, the WRC Kit 37 N and RX1 36 N. I also removed the visible fin from the WRC16 and RX1 wings.

I measured each complete car with a 180 km/h headwind. The first two columns use the tarmac setups for the rally cars and the race setup for RX1.

| Car | Drag (N) | Downforce (N) | Gravel drag (N) | Gravel downforce (N) |
|---|---:|---:|---:|---:|
| WRC17 | 2443 | 3909 | 2452 | 3610 |
| Rally1 | 2006 | 3318 | 1990 | 2909 |
| Rally2 | 1369 | 1769 | 1353 | 1256 |
| Rally2 WRC Kit | 1475 | 2049 | — | — |
| RX1 | 1623 | 2211 | — | — |

On tarmac the complete WRC Kit gains **280 N of downforce for 106 N of extra drag** over the regular Rally2. With the rear wing off, I could also compare the wings themselves. The Kit wing added 704 N of downforce, the twin-element RX1 wing 768 N and the WRC16 wing 811 N. I tested the Kit and WRC16 wings on the same Rally2.

### Cockpit instruments

- Rebuilt the instrument cluster mesh and repaired its topology. All 21 rally presets use **TypeA** (`Astral_gauge_rally`) with the WRC17 mount. RX1 and RX3 use **TypeB** (`Astral_gauge_rx`), which includes the rear-view mirror, extra brake light and stall warning. Both clusters share the 800 × 480 Skia display and use the shift-light calibration from the fitted ECU.

- Road puts speed first and shows gear, engine rpm, coolant temperature and fuel. Stage puts the gear and rpm in the centre. The cyan, yellow and red bands follow the same per-gear thresholds and flash signal as the physical shift lights.

- The co-driver screen opens on engine rpm, boost in bar, coolant and oil temperatures, fuel remaining and a colour-coded MAP number. Bind **Cycle Pages** to switch between engine readings and brakes. The co-driver’s selected page stays visible while the driver changes MAP or BOOST or prepares to launch.

- The brakes page shows disc surface temperature (°C) at each wheel on the left and front and rear brake pressure bars on the right. Both bars use front circuit pressure at full pedal as 100%. The rear reading follows the balance bar setting and the two master cylinder sizes. On Rally2 Tarmac Balanced, full pedal fills the front bar and brings the rear to about 57%.

- Selecting LC1, LC2 or LC3 brings up **LAUNCH CONTROL** and the new preset on the driver’s screen for 1.6 seconds, matching the MAP and BOOST adjustment pages. Pressing Start opens **LAUNCH READY** with the selected preset, ALS level and launch rpm limit. While the program is active, the left panel turns red at the launch light threshold.

## Engine and transmission

- **Corrected the rally boost pressure.** I’d read 2.5 bar absolute as 2.5 bar on the boost gauge. Turbo A and B now target **1.5 bar gauge (21.75 psi)** in competition trim. The compressor pressure curve reaches that figure at about 162,500 turbo rpm and continues above it. The electronic wastegate controls boost. Both turbos use a pressure rise rate setting of 50 psi/s.
  - I folded the old Rally2 intake correction into the shared 1.6-litre engine, then refitted the ECU and restrictor curves to keep the power bands the cars had before. The 32 mm Rally2 makes **290 PS**, and the same engine and ECU with the Kit’s 33 mm restrictor makes **307 PS**.
  - Smoothed the dip around 2,000–2,500 rpm on the naturally aspirated curves and the step at 800–850 rpm on the rally ECUs. The RX turbo retains its separate 55.5 psi competition target.

- **WRC16 now limits engine speed to 6,500 rpm in Road and 8,500 rpm in Stage**, up from 5,500 and 7,650 rpm. In Stage, the WRC block allows 8,500 rpm and the Rally2 block allows 7,500 rpm, including in the WRC Kit. Both engines now share the same time-based cut settings across ECUs.
  - WRC16 and the Rally2 WRC Kit share one 33 mm restrictor calibration. The WRC16 ECU carries its high-rpm correction in `torqueModIntake`. Peak torque is 411 Nm at about 4,450 rpm, and peak power comes at about 6,000 rpm. Boosted torque falls to 271 Nm at 7,500 rpm, 238 Nm at 8,000 and 199 Nm just before the 8,500 rpm limiter. The Kit retains its existing power and torque curves through its 7,500 rpm limiter.
  - The sixth-gear shift light on both gearsets now flashes at 8,500 rpm. Each of the three WRC16 launch presets can be set from 4,500 to 8,500 rpm in 100 rpm steps.

- **Every car spawns in MAP 1 (Road) by default.** On rally cars, choose a different starting position with Engine MAP at Spawn in the tuning menu. Press `Ctrl+Q` or click the icon beside the tach to advance one map. Each position can also be bound directly to a wheel rotary.
  - Road uses a 150 ms ignition cut on powered upshifts and silences exhaust pops on lift, braking and upshifts. Switching back to Stage restores the 52 ms cut on the six-speed sequential or 58 ms on the five-speed.
  - Arcade lowers its high-load upshift and downshift points to suit the Road rev limit, so it can shift up at full throttle. Stage restores the competition shift points. Both gearboxes use the Vivace rally sequential’s automatic clutch settings for pulling away.

**Rally engine MAPs**

| MAP | Mode | Pedal curve | ALS | Suggested use |
|---|---|---|---|---|
| 1 | Road | Progressive | Off | Road sections |
| 2 | Stage Soft | Subtle Linear | Off | Ice, snow or very slippery stages |
| 3 | Stage Low | Subtle Linear | Soft (14%) | Loose or slippery gravel |
| 4 | Stage Med | Subtle Linear | Medium (30%) | Firm gravel or wet tarmac |
| 5 | Stage High | Subtle Linear | Aggressive (100%) | High-grip stages, including dry tarmac |

ALS percentages give the available anti-lag power.

**RX1 and RX3 engine MAPs**

| MAP | Mode | Pedal curve | ALS | Suggested use |
|---|---|---|---|---|
| 1 | Road | Progressive | RX1 off / RX3 not fitted | Paddock and transit |
| 2 | Stage Low | Progressive | RX1 soft, 45,000 rpm / RX3 not fitted | Loose surfaces or low-grip race starts |
| 3 | Stage Med | Subtle Linear | RX1 medium, 65,000 rpm / RX3 not fitted | Mixed-surface laps |
| 4 | Stage High | Subtle Linear | RX1 aggressive, 85,000 rpm / RX3 not fitted | High-grip race sections (RX1) |

RX1 rpm values are turbine-speed targets on lift. RX3 uses the same pedal curve in Stage Med and Stage High.

### Electronic wastegate (eWasteGate)

The rally ECUs set a boost target from engine rpm and mapped throttle. At each engine speed there are two pressure targets, one with the throttle closed and one at full load. Opening the throttle progressively blends between them. For example, 50% mapped throttle takes the target 65% of the way from the closed-throttle value to the full-load value. All pressures below are gauge pressures.

| Rally calibration | Closed throttle requests zero boost up to | Full throttle first requests full boost at |
|---|---:|---:|
| WRC17 (Turbo A) | 4,800 rpm | 5,500 rpm |
| Rally1 2022 (Turbo A) | 5,500 rpm | 6,000 rpm |
| Rally1 2025 (Turbo A) | 5,200 rpm | 5,850 rpm |
| Rally2, Rally2 WRC Kit and WRC16 (Turbo B) | 4,250 rpm | 5,100 rpm |

- **Braking and downshifting.** In WRC17 Stage with zero BOOST trim, a closed-throttle downshift from 6,000 to 6,500 rpm raises the target from about 0.45 to 0.87 bar. The brake pedal has no separate trigger. With left-foot braking, the ECU still reads how much throttle you are holding. The shaft takes time to accelerate, so the gauge and turbo whine can lag behind the target.
- **BOOST rotary.** The driver can subtract 0, 20, 40 or 80 mbar on the move. Turbo A and B have a nominal Stage target of 1.50 bar at full load, so selecting −80 mbar brings it to about 1.42 bar. Road requests zero boost and remembers the trim for the return to Stage. Boost control also works in Stage Soft with ALS off.
- **Free-revving.** At a standstill in neutral or with the clutch fully disengaged, the normal rally target is capped at 1.5 psi (about 0.10 bar). Engaging the clutch in gear or picking up road speed releases the cap progressively. During an active launch the ECU uses the same throttle and rpm curves with the free-rev cap and race BOOST trim suspended.

RX1 has a 55.5 psi (about 3.83 bar) race turbo. Its normal target follows throttle opening and BOOST trim. During a lift, the wastegate allows enough pressure for the shaft speed requested by RX1 anti-lag, up to the driver's trimmed boost ceiling.

### Anti-lag (dynamicAntiLag)

On rally cars, the wastegate controller looks up the shaft speed needed to produce the requested pressure on the fitted turbo. ALS compares that speed with actual shaft rpm and adds turbine power while the shaft is short of target. The three ALS levels share the same target. Stage Low can request up to 14% of the available assist, Stage Med 30% and Stage High 100%. As the shaft catches up, the request falls. In Stage Soft the engine’s exhaust alone spins up the turbo.

**How much difference does the MAP make?** The Finland test used a 1.83-second lift with light braking in fourth gear followed by full throttle, with actual boost recorded at 60 Hz. Times below run from throttle reapplication until boost reached 1.0 bar.

| Finland setup | MAP 2 / Off | MAP 3 / Soft | MAP 4 / Medium | MAP 5 / Aggressive |
|---|---:|---:|---:|---:|
| WRC17 | 0.65 s | 0.45 s | 0.37 s | 0.22 s |
| Rally2 | 0.63 s | 0.45 s | 0.37 s | 0.20 s |

**Exhaust pops.** On Stage, instant and sustained afterfire scale from ×1 at zero assist to ×20 at full assist. On WRC17 and Rally2 the base coefficients are 4.2 instant (as on the Vivace NGRC1) and 3 sustained. At maximum demand in Low, Med and High, that gives 15.37 / 28.14 / 84 instant and 10.98 / 20.10 / 60 sustained. WRC16 and both Rally1 ECUs keep their instant base of 60, reaching 1,200 in High. Turbo A and B also apply ×1.5 to sustained pop volume. Launch at idle has its own ignition behaviour, described below.

**Rallycross.** RX1 arms its hold above idle once throttle reaches 5%. Lifting to 2% or less then holds up to 45,000, 65,000 or 85,000 shaft rpm, capped at the speed the turbo had at lift. The hold tapers near idle and lasts up to 10 seconds per lift. During an active launch, RX1 uses a separate 135,100 rpm shaft target with ALS enabled. The naturally aspirated RX3 uses launch rpm and torque limits without turbo or ALS controls.

### Launch control (launchControl)

Each setup saves three pairs of settings for LC1, LC2 and LC3. In the tuning menu, set launch rpm in 100 rpm steps and the torque cap from 50% to 100% of peak engine torque in five-point steps. For example, WRC17 Finland ships with 6,100 / 6,500 / 7,000 rpm and Rally2 Finland with 5,900 / 6,200 / 6,600 rpm. Both use 100% torque in all three presets. The LC preset sets rpm and torque. The engine MAP determines the available ALS power.

1. **Select and arm.** Choose a preset with the LC icon or a bound input. The main dash briefly shows **LAUNCH CONTROL** and the preset. In Stage, at 1.8 km/h or less, press *Toggle Launch Control*. The button turns red and **LAUNCH READY** shows the selected rpm limit. While waiting for the handbrake, normal engine limits apply and ALS assist is zero.
2. **Pull past 60% handbrake and apply throttle.** If the handbrake is already past 60% when you arm, the program starts immediately. The torque cap takes effect and the temporary limiter cuts as the engine reaches the preset rpm. On rally cars, a closed-throttle idle can produce launch pops with ALS enabled while requesting zero turbine assist. Opening the throttle raises the boost target. The selected ALS level helps build pressure, or exhaust alone does the work with ALS off.
3. **Release and launch.** At 60% handbrake or below, the launch limiter and torque cap release and launch ALS stops. The red button and **LAUNCH READY** remain, so pulling past 60% again before 10 km/h reapplies the same preset. At 10 km/h the system exits automatically. Pressing the button again or selecting Road also exits. To select another LC preset while armed, cancel first.

### Transmission and sound

- Lengthened the Rally1 five-speed Type-A gearset and the WRC17 six-speed Type-B gearset. The race flywheel’s added inertia went from **0.0200 to 0.0265 kg·m²**, and the shared 1.6-litre’s base engine braking torque went from 35 to 40 N·m.

- Recalculated the rally shift lights from the new full-load exports, fitted gear ratios and heavier flywheel. Each upshift compares the acceleration available in the current and next gear at the same road speed. The WRC Kit keeps its own 33 mm light profile in the Rally2 ECU.
  - The WRC16 signals its first upshift at 6,290 rpm on Type-A and 6,380 rpm on Type-B. The Kit’s four Type-A flashes are 6,440, 6,560, 6,500 and 6,350 rpm.
  - Both WRC16 gearsets use the Type-A full-throttle automatic shift points. The Rally2 WRC Kit uses its own 33 mm calibration. Neutral flashes at 3,000 rpm and top gear at each car’s limiter.

- Brought the engine up 3 dB and revised the intake and exhaust EQ. All three turbos now use a shaft whine volume setting of 0.025. Reduced the straight-cut gear whine on both sequential gearboxes.

- Revised the RX3’s second throttle map and its curve in the throttle workbook. Fixed the throttle response when reversing in Arcade gearbox mode.

## Suspension

- The old Type-A valving is now the **Linear Piston**, and Type-B is the **Digressive Piston**. I tried making the shim stacks interchangeable, but a stiff stack on the digressive piston could give much the same curve as the linear setup. Each piston now comes with its own stack.

- On the **Linear Piston**, tightening high-speed compression (HSC) brings the second knee in earlier and steepens the curve beyond it. On the **Digressive Piston**, HSC moves the first knee over twice its previous range. The middle click keeps the 26.11.11 digressive curve on tarmac, gravel and RX.
  - From full soft to full hard, the tarmac Linear knee moves from 0.54 to 0.28 m/s, and the gravel knee from 0.76 to 0.44 m/s. That lets the hard setting build support earlier without the old spread in force at landing speeds.

- On the tarmac linear piston at −12c, going from full soft to full hard adds 660 N per damper at 0.5 m/s, down from 760 N in 26.11.11. At 2.0 m/s the same adjustment adds 3,408 N, down from 6,760 N. On gravel the spread at 1.0 m/s went from 1,520 to 1,296 N. The RX linear piston keeps its previous mid-click curve.

- Jump landings felt smoother in Finland. Comparing the final Finland setups with their 26.11.11 counterparts, the base compression force per front damper at 1.0 m/s is 118 N lower on Rally2 and 62 N lower on WRC17. At 2.0 m/s the difference grows to 1,081 N and 707 N respectively. These are calculated damper forces at the stated shaft speeds.

- Widened the rebound adjuster’s effect on the LRS damping multiplier from ±0.05 to ±0.15 around the midpoint. I also softened the hydraulic rebound stops front and rear. WRC17 tarmac now uses 2,000 N·s/m, while WRC17 gravel, Rally1 gravel and RX1 use 1,000 N·s/m.

- Revised the camber and toe offsets in the Rally2, WRC17 and Rally1 suspension geometry.

- Stiffened the spring collar guides on both Rally2 tarmac front struts (RA60). Also stiffened the front and rear strut guides on Rally2, WRC17, Rally1 and RX.

- Retuned the tyres.
  - On the **GX and G gravel tyres**, the tread coefficient went from 0.88 to 0.90. I also adjusted the transition into sliding and the way grip changes under load.
  - On the **FX and F tarmac tyres**, I reduced the load-sensitivity slope more at the front than at the rear and revised the transition into sliding. The **ALP** got a smaller load-sensitivity change on the front axle.

## Misc

- Both **Finland** setups now have stiffer springs. Rally2 runs 28.5 N/mm front and 26 rear, and WRC17 runs 27.5 front and 25 rear. Both use a 22.7 mm rear anti-roll bar in the first mounting hole. Up front, Rally2 uses the middle hole and WRC17 uses the first. I revised the damping on both cars, raised the Rally2 spring height settings by 3 mm at both ends and softened the WRC17 rear hydraulic bump stop by two clicks.

- Revised the front and rear differential setups across the rally presets. Rally2 and WRC17 now use a 50° front drive ramp on gravel, with 5+5 friction faces on Balanced and Arctic, 4+4 in Finland and 6+6 in Kenya. Both Finland cars run 45 Nm front and 75 Nm rear preload. On tarmac, both Croatia cars run 45/60 Nm and both Monte Carlo cars use 5+5 up front. WRC16, Rally1 and the WRC Kit also got revised preload settings.

- Updated the **Circuit, Croatia and Monte Carlo** alignments for Rally2 and WRC17. Both Circuit setups now run 27 psi front and rear, down from 29. Rally2 Croatia now carries 10 kg of ballast at the front and 25 kg at the rear. Both Croatia setups also have revised rebound clicks.

- Retuned the **Kenya** dampers on Rally2 and WRC17. Both run −18c front and −16c rear, with revised high-speed compression and rebound. I also adjusted front toe on WRC17 Kenya. On WRC16 Gravel Balanced, I lowered the spring height settings by 3 mm at both ends and revised rear compression and rebound.

- Kenya now runs 70 Nm of rear differential preload on Rally2 and 80 Nm on WRC17. The WRC17 active centre diff uses a brake preload multiplier of 30× in Finland, 40× in Kenya and Croatia, and 25× on Circuit.

- Raised the front and rear spring height settings by 3 mm on WRC17 Croatia. I also softened high-speed compression at both ends and set the hydraulic bump stops to −4 clicks at the front and −6 at the rear.

- Raised the handbrake lever setting from 0.74 to 0.76 on the Finland, Kenya, Circuit, Croatia and Monte Carlo setups for both Rally2 and WRC17, and on WRC16 Gravel Balanced.

- Updated the [gearing and shift-light workbook](../../gearing_shiftlights.xlsx) with the six rally engine exports and the per-gear shift points. The figures on the power curves are in hp. The WRC16 sheet now uses the ratios fitted to the car. Removed six separate engine curve JSON exports and cleared obsolete ALS throttle, brake and rpm thresholds from ten vehicle presets.

- Updated the tarmac, gravel and RX damper workbooks. Select a piston and the calculator and sweep charts use its in-game valving.

- Updated the [aerodynamics workbook](../../aerodynamics.xlsx) with the component measurements and rear-wing crosswind tests. The Rally2 sheet now lets you select the standard car, the WRC16 wing swap or the WRC Kit. For the Kit, the parts gave an estimate of 1478 N of drag and 2050 N of downforce, within 3 N and 1 N of the complete car.

- Added a 500 Hz CSV recorder for the two front dampers. In the vehicle Lua console, run `extensions.astralDamperCsv.start()` to load the recorder and begin sampling shaft speed and length on both sides. Run `extensions.astralDamperCsv.stop()` to finish the file.

- Standardized JBeam and Lua comment formatting and aligned the front and rear damper notes on total piston travel and effective damping travel.

- Retook the vehicle preview and all 23 preset thumbnails at higher graphics settings.

[Compare 26.11.11 with main on GitHub](https://github.com/ProgUn1corn/qlourie_astral_r/compare/26.11.11...main)
