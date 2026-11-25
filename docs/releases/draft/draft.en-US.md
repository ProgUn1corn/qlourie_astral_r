# Qlourie Astral R — Next release (draft)

**English** | [简体中文](./draft.zh-CN.md)

Back on a new PC, I finally rebuilt the dashboard that came out of Automation. I also went back to the rally engines’ boost figures and spent a fair bit of time on the dampers, particularly on the fast landings in Finland.

## Chassis and bodywork

- **Rebuilt the dashboard mesh.** The original Automation export had rough topology all across the dash. I redid the mesh and split out the centre console so it has its own flexbody attached to the chassis.

- Reworked the lower edge of the windscreen to go with the new wiper, adapted from *EA SPORTS WRC*.

- Fixed the 5 kg that disappeared when fitting the driver with animated hands. The driver reference node now weighs 12 kg in that configuration.

- Reduced the brake cooling coefficients on the front bumper ducts and rear intakes. For example, the WRC17 front duct options went from 1.48 and 1.40 to 1.25 and 1.15. The blanking plate uses 1.00.

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

- **The electronic wastegate reads both engine speed and throttle.** Each car has a closed-throttle boost target at each engine speed. Opening the throttle blends towards the full-load target. On WRC17, lifting requests zero gauge boost at or below 4,800 rpm. A downshift under braking raises the target as engine speed rises above that point. At full throttle and zero boost trim, it requests full boost from 5,500 rpm.
  - BOOST has its own bindings. You can take 0, 20, 40 or 80 mbar out of the target on the move. Switch engine maps and the trim stays where you left it.

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

After a 1.83-second lift with light braking in fourth gear, the WRC17 Finland setup recovered 1 bar of boost in 0.65, 0.45, 0.37 and 0.22 seconds on MAPs 2 through 5. The Rally2 Finland setup took 0.63, 0.45, 0.37 and 0.20 seconds in the same test.

- **Launch control now has three independent presets.** Select LC1, LC2 or LC3 on the LC icon. Once stopped in Stage, press your *Toggle Launch Control* binding to start. Once the icon turns red, use the throttle to build boost. The selected Stage map sets launch anti-lag strength. With ALS off, exhaust flow alone spins up the turbo. With ALS on, the exhaust can pop as soon as you arm Launch. The boost gauge stays in vacuum at idle. The launch limiter cuts at the selected rpm. Reach 10 km/h, press the button again or switch to Road to leave launch control.

Each vehicle setup specifies an rpm limit and a torque cap for LC1, LC2 and LC3. Adjust each preset in the tuning menu before the run, then select it with the LC button. RPM moves in 100 rpm steps. The torque cap ranges from 50% to 100% of peak engine torque in steps of five percentage points.

- Lengthened the Rally1 five-speed Type-A gearset and the WRC17 six-speed Type-B gearset. The race flywheel’s added inertia went from **0.0200 to 0.0265 kg·m²**, and the shared 1.6-litre’s base engine braking torque went from 35 to 40 N·m.

- Recalculated the rally shift lights from the new full-load exports, fitted gear ratios and heavier flywheel. Each upshift compares the acceleration available in the current and next gear at the same road speed. The WRC Kit keeps its own 33 mm light profile in the Rally2 ECU.
  - The WRC16 signals its first upshift at 6,290 rpm on Type-A and 6,380 rpm on Type-B. The Kit’s four Type-A flashes are 6,440, 6,560, 6,500 and 6,350 rpm.
  - Both WRC16 gearsets use the Type-A full-throttle automatic shift points. The Rally2 WRC Kit uses its own 33 mm calibration. Neutral flashes at 3,000 rpm and top gear at each car’s limiter.

- **Both instant and sustained afterfire now follow anti-lag demand on the rally cars.** In Stage Soft, WRC17 and Rally2 use the stock Vivace NGRC1 instant coefficient of 4.2 and a sustained coefficient of 3. At maximum assist in Stage Low, Med and High, the instant values reach 15.37, 28.14 and 84. The sustained values reach 10.98, 20.10 and 60. Both return to their base values as demand falls to zero. At closed-throttle launch idle, the selected ALS level sets the afterfire multiplier while turbine assist stays at zero.
  - WRC16 and both Rally1 ECUs retain their instant base of 60, which reaches 1200 at full assist in Stage High. Turbo A and B both apply a 1.5 multiplier to sustained pop volume.

- Brought the engine up 3 dB and revised the intake and exhaust EQ. All three turbos now use a shaft whine volume setting of 0.1. Reduced the straight-cut gear whine on both sequential gearboxes.

- Revised the RX3’s second throttle map and its curve in the throttle workbook. Fixed the throttle response when reversing in Arcade gearbox mode.

## Suspension

- The old Type-A valving is now the **Linear Piston**, and Type-B is the **Digressive Piston**. I tried making the shim stacks interchangeable, but a stiff stack on the digressive piston could give much the same curve as the linear setup. Each piston now comes with its own stack.

- On the **Linear Piston**, tightening high-speed compression (HSC) brings the second knee in earlier and steepens the curve beyond it. On the **Digressive Piston**, HSC moves the first knee over twice its previous range. The middle click keeps the 26.11.11 digressive curve on tarmac, gravel and RX.
  - From full soft to full hard, the tarmac Linear knee moves from 0.48 to 0.22 m/s, and the gravel knee from 0.76 to 0.44 m/s. That lets the hard setting build support earlier without the old spread in force at landing speeds.

- On the tarmac linear piston at −12c, going from full soft to full hard adds 816 N per damper at 0.5 m/s, close to the old 760 N. At 2.0 m/s the same adjustment adds 3,516 N, down from 6,760 N in 26.11.11. On gravel the spread at 1.0 m/s went from 1,520 to 1,296 N. The RX linear piston keeps its previous mid-click curve.

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

- Raised the handbrake lever setting from 0.74 to 0.76 on the Finland, Kenya, Circuit, Croatia and Monte Carlo setups for both Rally2 and WRC17, and on WRC16 Gravel Balanced.

- Updated the [gearing and shift-light workbook](../../gearing_shiftlights.xlsx) with the six rally engine exports and the per-gear shift points. The figures on the power curves are in hp. The WRC16 sheet now uses the ratios fitted to the car. Removed six separate engine curve JSON exports and cleared obsolete ALS throttle, brake and rpm thresholds from ten vehicle presets.

- Updated the tarmac, gravel and RX damper workbooks. Select a piston and the calculator and sweep charts use its in-game valving.

- Added a 500 Hz CSV recorder for the two front dampers. It logs shaft speed and damper length on each side so you can compare a stage run with the damper curves.

- Standardized JBeam and Lua comment formatting and aligned the front and rear damper notes on total piston travel and effective damping travel.

- Updated the vehicle preview and all preset thumbnails.

[Compare 26.11.11 with main on GitHub](https://github.com/ProgUn1corn/qlourie_astral_r/compare/26.11.11...main)
