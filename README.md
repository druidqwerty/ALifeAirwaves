# A-Life: Airwaves & Contracts [B42]

<p align="center"><a href="https://boosty.to/lrgpp"><img src="https://raw.githubusercontent.com/druidqwerty/ALifeAirwaves/main/docs/banner.png" alt="LrgPP mods on Boosty" width="640"></a></p>

Radio airwaves, dynamic SOS rescue contracts, supply drops, and tactical town recon for [Project A-Life [ALIFE NPCS]](https://steamcommunity.com/sharedfiles/filedetails/?id=3803984183) by Vice. Connects living survivor squads, outposts, and (optionally) [A-Life: Caravans](https://steamcommunity.com/sharedfiles/filedetails/?id=3829571361) convoys to real in-game walkie-talkies, HAM stations, and vehicle radios across dedicated frequencies (`94.2 MHz`, `101.6 MHz`, `106.4 MHz`).

[Source / releases (MIT)](https://github.com/druidqwerty/ALifeAirwaves) · [Русский](README_RU.md) · [Verification Report (0.1.0)](TEST_0.1.0.md)

Free and open source. The code is developed with AI; direction, testing and time are mine. [Support the mods on Boosty](https://boosty.to/lrgpp).

> **0.1.0 (test version) — Initial public test release.** Validated by 162 simulation assertions (`tools/run_test.py`), main-menu engine load check (`tools/pz_loadcheck.py`), and a 6-stage live singleplayer test in Project Zomboid 42.21.0 (`tools/livetest/live_sp.py`). See [TEST_0.1.0.md](TEST_0.1.0.md).

## What you can do

- **Tune into living survivor airwaves (`94.2 / 101.6 / 106.4 MHz`):**
  - **94.2 MHz — Knox Survivor Emergency:** patrol check-ins, horde warnings, and incoming SOS distress calls.
  - **101.6 MHz — Caravan & Trade Net:** outpost broadcasts, supply drop dispatches, and live convoy updates when *A-Life: Caravans* is installed.
  - **106.4 MHz — Knox Tactical Recon:** skirmish alerts, ammunition distress calls, and sector recon summaries.
  - Registered as real `ZomboidRadio` / `DynamicRadio` channels so you hear broadcasts on Walkie-Talkies, HAM Radios, and Vehicle Radios, mirrored to the in-game **Airwaves Log** and overhead `HaloText` notifications.
- **Auto-mark intercepted coordinates on your map (`WorldMapSymbols`):**
  - Carry a pen or pencil (`Base.Pen`, `Base.Pencil`, etc.) to automatically annotate intercepted coordinates and SOS beacons on the world map, or click **Mark on Map** / **Show on Map** inside the Airwaves window.
  - Live SOS beacons and supply drop zones also render on the world map and minimap.
- **Answer dynamic SOS beacons & field contracts:**
  - Survivor groups broadcast real-time distress calls: **Pinned by a Horde** (clear nearby zombies), **Wounded Fighter** (deliver bandages, first aid kits, disinfectant, or antibiotics), **Out of Ammo** (deliver any ammunition box), or **Roadside Breakdown** (deliver a petrol can, wrench, duct tape, or car battery).
  - Accept contracts in the **SOS & Contracts** tab, reach the coordinates before the timer expires, help the squad, and earn physical gear rewards plus A-Life faction reputation and favor.
- **Order radio supply drops, hail caravans & request town recon:**
  - With a powered high-tier radio (`WalkieTalkie4`, `WalkieTalkie5`, `HamRadio`, or `VehicleRadio`) and barter credit (`Base.Money` or trade goods), order **Medical**, **Ammo**, **Fuel & Repair**, **Tools**, or **Rations** crates delivered by a courier squad to a nearby road point.
  - When *A-Life: Caravans* is installed, use **Hail / Call Caravan** on the trade channel to locate and halt a nearby friendly convoy.
  - Request **Tactical Town Recon** for Muldraugh, West Point, Rosewood, March Ridge, Riverside, Echo Creek, Irvington, Brandenburg, or Louisville to see active survivor squads, outposts, convoys, and local zombie threat levels.

## Requirements and installation

- **Project Zomboid Build 42.21.0** and **Project A-Life 1.4.6** are the verified target for 0.1.0.
- Required: [Project A-Life [ALIFE NPCS]](https://steamcommunity.com/sharedfiles/filedetails/?id=3803984183).
- Recommended (optional):
  - [A-Life: Caravans](https://steamcommunity.com/sharedfiles/filedetails/?id=3829571361) — live convoy broadcasts, shared faction favor, and radio caravan hailing.
  - [A-Life: Reactive Survivors](https://steamcommunity.com/sharedfiles/filedetails/?id=3829332775) — faster NPC threat awareness and crowd positioning.
  - [Project A-Life – Jeem Extension](https://steamcommunity.com/sharedfiles/filedetails/?id=3806944055) — public UI color palette integration.
- Load `ALifeAirwaves` after `ProjectALifeNPCs`. No Java agent or `ZombieBuddy` installation is required to play.

## In-game settings (no file edits or restarts)

- **Host / World settings (`Sandbox → A-Life: Airwaves & Contracts`):** enable switch, broadcast interval (`BroadcastIntervalMinutes`), SOS interval (`SOSContractIntervalMinutes`), SOS timeout (`SOSTimeoutMinutes`), reward multiplier (`RewardMultiplier`), supply dispatch cooldown (`SupplyDispatchCooldownMinutes`), recon cooldown (`IntelCooldownMinutes`), auto map markers (`AutoMapMarkers`), require powered radio (`RequirePoweredRadio`), channel frequencies (`EmergencyFreqKhz`, `TradeFreqKhz`, `TacticalFreqKhz`), and debug logging. Polled live every 2 seconds.
- **Personal settings (`Options → Mods → A-Life: Airwaves & Contracts`):** window hotkey (`openKey`, default `F9`), overhead radio notices (`haloNotices`), right-click radio context menu (`contextMenu`), world map & minimap beacon overlay (`worldMapOverlay`), and channel filter (`freqFilter`).

## My mods

- [SmoothRide MP](https://steamcommunity.com/sharedfiles/filedetails/?id=3827367565)
- [ZombieSync MP](https://steamcommunity.com/sharedfiles/filedetails/?id=3827946115)
- [Tripping Zombies MP Fix](https://steamcommunity.com/sharedfiles/filedetails/?id=3829034899)
- [Wandering Hordes Performance Fix](https://steamcommunity.com/sharedfiles/filedetails/?id=3829140377)
- [Download Unstuck](https://steamcommunity.com/sharedfiles/filedetails/?id=3829163351)
- [A-Life: Reactive Survivors](https://steamcommunity.com/sharedfiles/filedetails/?id=3829332775)
- [A-Life: Caravans](https://steamcommunity.com/sharedfiles/filedetails/?id=3829571361)
- **A-Life: Airwaves & Contracts** (this mod)

## Credits

**Vice / Project A-Life:** NPCs, world simulation, factions, and Knox County Radio. Development uses AI assistance, with direction and testing by druid.

© 2026 druidqwerty. Released under the MIT License. Project A-Life by Vice.
