# Qlourie Astral R — draft2

**English** | [简体中文](./draft2.zh-CN.md)

## Rally2 WRC Kit

The 2027 Rally2 WRC Kit is now available under **Prototype / Testing**. It starts with the Rally2 EVO tarmac car and its five-speed Type-A gearset. The Kit leaves out the 10 kg of front ballast fitted to the Rally2 Tarmac Balanced setup.

- The Kit has its own front bumper, front fenders, front lip and larger rear wing. I moved their nodes to match the bodywork, rebuilt the wing's endplate supports and revised the aero.

- The Kit uses the Rally2 engine, turbo and ECU with a 33 mm restrictor in place of the 32 mm one. Peak power rises from **290 to 307 PS**. The Kit peaks around 5660 rpm, then eases back to 304 PS at 6500 rpm and 301 PS at 7000 rpm. The WRC16 shares the 33 mm restrictor and stays at about 310 PS with its own ECU calibration.

- With the Kit's 33 mm restrictor and Type-A gears, the four upshift flashes are **6450, 6620, 6550 and 6390 rpm**. The existing Rally2 ECU selects this map when the Kit's parts are fitted.

## Chassis and bodywork

- **Reworked the WRC17 aero balance.** I had been looking too much at total downforce. Removing the rear wing increased the front axle's downforce reading: the wing loads the rear axle but also unloads the front through its pitching moment. That makes a big difference when deciding where to add downforce.
  - Rebalanced downforce and drag across the front bumper, front lip, large diveplanes, front fenders, rear wing and diffuser. More of the load now comes from the diveplanes and front fenders, with less from the diffuser. Removed the rear fenders' extra downforce and adjusted the wing and endplate aero.
  - At **192 km/h**, the final tarmac measurement is **3997 N of downforce and 2300 N of drag**, with a **55.8:44.2 front/rear split**. The front and rear axle readings are 2229 N and 1768 N, giving an overall downforce-to-drag ratio of about 1.74.
  - At the same speed, the gravel setup produces **3564 N of total downforce**.

- Moved the front lip and rear diffuser aero reference nodes into the suspension parts. Tarmac and gravel versions can now have their own reference positions. Revised the WRC17 lip's stall angle and front fender geometry alongside the aero changes.

- Reworked the front bumper attachments on Rally2, WRC17, Rally1 and RX, including the splitter connections. Increased front and rear bumper attachment stiffness and revised deformation and break thresholds.

- Adjusted the floor and front crash beam node positions. Marked the lip and diffuser reference-node connections as optional for combinations without the corresponding suspension nodes.

## Engine and transmission

- **Shift lights now follow the fitted ECU, gearset and restrictor.** The previously commented-out Type-B maps now work when Type-B gears are installed. Each ECU keeps its own calibration, including separate Rally1 2022 and 2025 maps; the Rally2 WRC Kit uses the Rally2 ECU's 33 mm map.

- Put the map selection in the shared interior configuration so the different instrument panels use the same selection logic. If a particular restrictor has no dedicated map, the ECU uses its default-bore map for that gearset, then its Type-A map as a fallback.

## Suspension and tyres

- Raised gravel **HBS damping** to a **12000–16000 N·s/m** adjustment range, with **14000 N·s/m** at the middle setting. WRC17 and Rally1 gravel presets keep their original clicks, with saved values increased by 2000. The fixed RA65 HBS baseline is now 14000, retaining its low-speed compression linkage.

- Changed adjustable HBS settings to integer clicks: WRC17 and RX1 use −16 to 0, with −8 as the default; Rally1 uses −8 to 0, with −4 as the default. JBeam converts clicks to damping, at 250 or 500 N·s/m per click respectively. Saved setups keep the same damping, and the damper test model reads the same calculated value.

- Increased RA65 mechanical rebound-stop damping from **1949 to 2227 N·s/m**, retaining the existing travel and engagement point.

- Adjusted the gravel tyres' sliding friction coefficient from **1.05 to 1.08** and tread coefficient from **0.86 to 0.90**. RX tyres also get a tread coefficient increase from **0.52 to 0.56**.

## Misc

- **Updated the supplied setups after more driving tests.**
  - Rally2 Gravel Balanced has revised rear compression and rebound damping. Arctic rear differential preload is now 60 Nm. Finland uses softer springs front and rear, one click less low- and high-speed compression damping on both axles, the rear ARB at M and 60 Nm of front differential preload.
  - WRC17 Gravel Balanced and Arctic use front ARB position L and rear M, with revised damping. Their rear differential preloads are 80 Nm and 60 Nm respectively. Finland uses softer springs, revised front and rear rebound, and 60 Nm of front differential preload.
  - WRC16 Gravel Balanced uses 23.5 N/mm front and 21 N/mm rear springs, with both spring platform offsets reduced by 6 mm. The rear ARB is at M and rear differential preload is 80 Nm. The tarmac setup's rear ARB moves to H.
  - Rally1 2022 uses rear ARB position M, with 60 Nm front and 80 Nm rear differential preload.
  - RX3 front differential preload is now 60 Nm.

- Updated the WRC Kit's vehicle information for its new output and the WRC16's displayed peak-power and peak-torque RPM bands.

- Added the WRC Kit engine-curve export and its own page in the [gearing and shift-light workbook](../../gearing_shiftlights.xlsx), with the revised curve and shift points.

- Added an [aerodynamics workbook](../../aerodynamics.xlsx) with component downforce, drag and downforce-to-drag ratios, plus the measured whole-car baseline. Three **0–200 km/h** charts show front, rear and total downforce, scaled from the 192 km/h tarmac measurement using speed squared at a fixed attitude. The gravel result stays as a short note below the main table.
