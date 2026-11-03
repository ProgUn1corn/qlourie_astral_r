# Qlourie Astral R — draft2

**English** | [简体中文](./draft2.zh-CN.md)

## Rally2 WRC Kit

The 2027 Rally2 WRC Kit is now available under **Prototype / Testing**. It starts with the Rally2 EVO tarmac car and its five-speed Type-A gearset. The Kit leaves out the 10 kg of front ballast fitted to the Rally2 Tarmac Balanced setup.

- The Kit has its own front bumper, front fenders, front lip and larger rear wing. I moved their nodes to match the bodywork, rebuilt the wing's endplate supports and revised the aero.

- The Kit uses the Rally2 engine, turbo and ECU with a 33 mm restrictor in place of the 32 mm one. Peak power rises from **290 to 307 PS**. The Kit peaks around 5660 rpm, then eases back to 304 PS at 6500 rpm and 301 PS at 7000 rpm. The WRC16 shares the 33 mm restrictor and stays at about 310 PS with its own ECU calibration.

- With the Kit's 33 mm restrictor and Type-A gears, the four upshift flashes are **6450, 6620, 6550 and 6390 rpm**. The existing Rally2 ECU selects this map when the Kit's parts are fitted.

## Chassis and bodywork

- **Reworked the WRC17 aero balance.** I had been looking too much at total downforce. Removing the rear wing increased the front axle's downforce reading: the wing loads the rear axle but also unloads the front through its pitching moment. That makes a big difference when deciding where to add downforce.
  - Rebalanced downforce and drag across the front bumper, front lip, large diveplanes, front fenders, rear wing and diffuser. Removed the rear fenders' extra downforce and adjusted the wing and endplate aero.
  - Retuned the gravel lip reference position after testing both surfaces at the same wind speed. The gravel car now produces less downforce than the tarmac car.

- **Reworked the Rally2 and WRC Kit aero.** Adjusted their bumpers, front lips, rear wings and the small diffuser under the rear bumper. The standard Rally2 front fenders now get their contribution from their shape, while the Kit retains its small aero lip. Removed the extra downforce from the Rally2 rear fenders.

- Revised the WRC16 double-deck rear wing's node positions, downforce and drag.

- Recalibrated drag on the body, floor, tailgate, rear bodywork and radiators. Each car now has its own measured base with the main aero devices removed; the fitted rear bodywork and cooling parts make a difference even before adding a wing.

- Moved the front lip and rear diffuser aero reference nodes into the suspension parts. Tarmac and gravel versions can now have their own reference positions. Revised the lip stall angles and front fender geometry alongside the aero changes.

- Reworked the front bumper attachments on Rally2, WRC17, Rally1 and RX, including the splitter connections. Increased front and rear bumper attachment stiffness and revised deformation and break thresholds.

- Adjusted the floor and front crash beam node positions. Marked the lip and diffuser reference-node connections as optional for combinations without the corresponding suspension nodes.

The latest **180 km/h wind-tunnel measurements** are below. These replace the earlier road-speed measurements in this draft. Front share comes from the front and rear axle downforce readings.

| Configuration | Total downforce (N) | Drag (N) | Downforce / drag | Front share |
| --- | ---: | ---: | ---: | ---: |
| WRC17 Tarmac | 3680 | 2263 | 1.63 | 55.4% |
| WRC17 Gravel | 3330 | 2200 | 1.51 | 57.9% |
| Rally2 Tarmac | 1634 | 1225 | 1.33 | 57.9% |
| Rally2 Gravel | 1149 | 1144 | 1.00 | 57.4% |
| Rally2 WRC Kit | 1898 | 1277 | 1.49 | 57.1% |

## Engine and transmission

- **Shift lights now follow the fitted ECU, gearset and restrictor.** The previously commented-out Type-B maps now work when Type-B gears are installed. Each ECU keeps its own calibration, including separate Rally1 2022 and 2025 maps; the Rally2 WRC Kit uses the Rally2 ECU's 33 mm map.

- Put the map selection in the shared interior configuration so the different instrument panels use the same selection logic. If a particular restrictor has no dedicated map, the ECU uses its default-bore map for that gearset, then its Type-A map as a fallback.

## Suspension and tyres

- Raised gravel **HBS damping** to a **12000–16000 N·s/m** adjustment range, with **14000 N·s/m** at the middle setting. WRC17 and Rally1 gravel presets keep their original clicks, with damping settings increased by 2000. The fixed RA65 HBS baseline is now 14000, retaining its low-speed compression linkage.

- Changed adjustable HBS settings to integer clicks: WRC17 and RX1 use −16 to 0, with −8 as the default; Rally1 uses −8 to 0, with −4 as the default. JBeam converts clicks to damping, at 250 or 500 N·s/m per click respectively. Converting to clicks preserves each setup's damping setting, and the damper test model reads the same calculated value. RX1 keeps its 12000 middle setting; RX3 retains its 8000 baseline and low-speed compression linkage.

- Increased RA65 mechanical rebound-stop damping from **1949 to 2227 N·s/m**, retaining the existing travel and engagement point.

- **Retuned the gravel tyres after more sliding and high-speed cornering tests.** Increased carcass and tread reinforcement stiffness while reducing circumferential stiffness. Sliding friction goes from **1.05 to 1.10**, and the tread coefficient from **0.86 to 0.90**.

- Increased sliding friction on the 235/40 R18 FX and F tarmac tyres from **1.01 to 1.02**, and adjusted the F compound's load sensitivity. RX tyres get a tread coefficient increase from **0.52 to 0.56**.

## Misc

- **Updated the supplied setups after more driving tests.**
  - Rally2 Gravel Balanced has revised rear compression and rebound damping. Arctic rear differential preload is now 60 Nm. Finland uses softer springs front and rear, one click less low-speed compression damping on both axles, revised rebound, the rear ARB at M and 60 Nm of front differential preload.
  - WRC17 Gravel Balanced and Arctic use front ARB position L and rear M, with revised damping. Their rear differential preloads are 80 Nm and 60 Nm respectively. Finland uses softer springs, revised front and rear rebound, and 60 Nm of front differential preload; its spring platform offsets increase by 3 mm at the front and 6 mm at the rear.
  - WRC16 Gravel Balanced uses 23.5 N/mm front and 21 N/mm rear springs, with both spring platform offsets reduced by 6 mm. The rear ARB is at M and rear differential preload is 80 Nm. The tarmac setup's rear ARB moves to H, and its front spring platform offset drops by 3 mm.
  - Rally2 Tarmac Balanced now uses −22R front and −16R rear rebound settings. WRC17 Tarmac Balanced uses −30R at the rear.
  - The WRC Kit gets revised rear high-speed compression and rebound damping, with spring platform offsets of 18 mm front and 24 mm rear.
  - Rally1 2022 uses rear ARB position M, with 60 Nm front and 80 Nm rear differential preload.
  - RX3 front differential preload is now 60 Nm.

- Shortened the Kit part display names to **WRC Kit** and gave its front lip a matching dedicated slot.

- Updated the WRC Kit's vehicle information for its new output and the WRC16's displayed peak-power and peak-torque RPM bands.

- Added the WRC Kit engine-curve export and its own page in the [gearing and shift-light workbook](../../gearing_shiftlights.xlsx), with the revised curve and shift points.

- Added an [aerodynamics workbook](../../aerodynamics.xlsx) with separate WRC17, Rally2 and WRC Kit pages.
  - The model pages show whole-car downforce, drag, downforce-to-drag ratio and front share. Each has front, rear and total downforce curves through **200 km/h**, estimated from the 180 km/h tarmac wind-tunnel baseline using speed squared at a fixed attitude. Gravel results stay as short notes.
  - The Parameters sheet keeps each car's base readings and the successive component measurements for comparison.
  - A parts calculator lets you select which aero devices are fitted and estimate total drag, downforce and downforce-to-drag ratio from those measured increments.
