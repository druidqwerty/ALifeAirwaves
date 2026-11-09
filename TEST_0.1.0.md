# A-Life: Airwaves & Contracts — 0.1.0 Verification Report (2026-11-09)

## 1. Automated Simulation & Static Checks (`tools/run_test.py`)
- **Command:** `python -I tools/run_test.py`
- **Coverage:**
  - Kahlua syntax gate across all 10 runtime Lua files (`lupa` compile + static scan for forbidden `goto`, `::label::`, `continue`, `table.unpack`).
  - `42/media/sandbox-options.txt` validation (0 `--` comments, all 13 `translation =` keys mapped in `Sandbox.json`).
  - Bilingual localization check across `EN` and `RU` (`IG_UI.json`, `UI.json`, `Sandbox.json`: identical key sets, non-empty UTF-8 strings, 0 `%` characters in `Sandbox.json`, all `IGUI_ALA_*` and `UI_ALA_*` references resolved).
  - Simulation suite (`tools/test_ala.lua`): **81 assertions in EN + 81 assertions in RU = 162 assertions passed (`TOTAL failed = 0`)**.
  - Verified: lazy boot, ZomboidRadio 3-channel registration (`94.2`, `101.6`, `106.4 MHz`), radio device scanning & tuning, writing utensil check, live broadcast emission (`SquadLedger`, `OutpostRegistry`, `ALifeCaravans`), `WorldMapSymbols` auto-marking, SOS contract creation/acceptance/materialization/fulfillment (`horde`, `medical`, `ammo`, `breakdown`), duplicate-payout receipt guard, supply drop dispatch & claim, caravan hail integration, town recon intel, `ALA_AirwavesWindow` 3-tab UI rendering, context menus, hotkey toggle, and `PZAPI.ModOptions`.

## 2. Main Menu Engine Load Check (`tools/pz_loadcheck.py`)
- **Command:** `python -I tools/pz_loadcheck.py start && python -I tools/pz_loadcheck.py wait 90`
- **Mods enabled:** `ZombieBuddy`, `ProjectALifeNPCs`, `ALifeCaravans`, `ALifeAirwaves`
- **Result:**
  - `mod lua seen: True` (`LOG : Lua f:0> [ALA] v0.1.0 client loaded`)
  - All EN/RU translation JSONs and `sandbox-options.txt` loaded cleanly.
  - `--- errors: 0` (exit code `0`).

## 3. Live In-Game Singleplayer Test (`tools/livetest/live_sp.py`)
- **Run ID:** `tools/livetest/runs/20261109_041311`
- **Environment:** Project Zomboid Build `42.21.0` isolated singleplayer Sandbox world (`Muldraugh, KY`, `10637, 10267, 0`) with `ProjectALifeNPCs` (1.4.6), `ALifeCaravans` (0.7.2), and `ALifeAirwaves` (0.1.0).
- **Verified Steps in `ALALive_result.txt` & `console.txt`:**
  1. `STEP 1 PASS`: `ProjectALife`, `ALifeCaravans`, and `ALifeAirwaves` booted (`[ALA] v0.1.0 installed (singleplayer)`, `ZomboidRadio channels registered=3`).
  2. `STEP 2 PASS`: `Radio.WalkieTalkie4` powered & tuned to `101.6 MHz`, `Base.Pen` detected (`canWriteOnMap = true`).
  3. `STEP 3 PASS`: Live broadcasts emitted on `ZomboidRadio` and coordinates auto-marked (`broadcasts=5 mapMarks=2`).
  4. `STEP 4a/4b PASS`: Dynamic medical SOS contract created (`sos:7 at 10688,10313`), accepted, materialized with A-Life survivors, and fulfilled (`rewards granted=3 favor=3`).
  5. `STEP 5a/5b PASS`: Supply drop (`pkg_medical`, `drop:9 at 10715,10313`) dispatched via radio and claimed (`items=5`), Muldraugh Recon Intel generated.
  6. `STEP 6 PASS`: `ALA_AirwavesWindow` opened in-game, rendered all 3 tabs (`Airwaves Log`, `SOS & Contracts`, `Supply & Intel`), marked map coordinates, and closed with `errors=0`.
- **Final Counters:** `broadcasts=8 sosCreated=2 sosAccepted=1 sosCompleted=1 sosFailed=0 dispatches=1 dispatchClaimed=1 caravanCalls=0 intelReports=1 mapMarks=5 radioTunes=1 radioAired=8 lines=0 errors=0`.

## Known Scope & Limitations (0.1.0 test version)
- First public test release (`0.1.0 (test version)`).
- Live verification completed in singleplayer with `ProjectALifeNPCs` and `ALifeCaravans`. Extended dedicated-server multiplayer sessions and custom third-party radio item packs require broader player testing.

© 2026 druidqwerty. Released under the MIT License. Project A-Life by Vice.
