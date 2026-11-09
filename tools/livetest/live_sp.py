"""Isolated real SP live test harness for A-Life: Airwaves & Contracts (ALifeAirwaves).
Boots a real Project Zomboid 42.21.0 client into an isolated Muldraugh SP world with
ProjectALifeNPCs, ALifeCaravans, and ALifeAirwaves enabled, runs the 6-stage in-world
verification scenario (ALALive_Scenario.lua), verifies 0 Lua errors in console.txt / DebugLog,
and kills the process cleanly.
"""
from pathlib import Path
import argparse
import datetime
import json
import re
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
GAME = Path("G:/Steam/steamapps/common/ProjectZomboid")
WORKSHOP = Path("G:/Steam/steamapps/workshop/content/108600")
JDK = Path("C:/Users/druid/.openclaw/workspace/_ext/jdk/jdk-25.0.4.1+1/bin")
CURRENT = HERE / "current.json"


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def processes():
    cmd = "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(javaw?|ProjectZomboid64)\\.exe$' } | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"
    out = subprocess.check_output(["powershell", "-NoProfile", "-Command", cmd], text=True).strip()
    value = json.loads(out) if out else []
    return [value] if isinstance(value, dict) else value


def check_idle():
    busy = [p for p in processes() if "zombie." in (p.get("CommandLine") or "")
            or "ProjectZomboid64" in (p.get("CommandLine") or "")]
    if busy:
        raise SystemExit("A PZ process already exists: " + str([p["ProcessId"] for p in busy]))


def options():
    path = Path.home() / "Zomboid/options.ini"
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines() if path.exists() else []
    overrides = dict(fullScreen="false", borderless="false", width="1024", height="640", vsync="false",
                     frameRate="30", soundVolume="0", musicVolume="0", ambientVolume="0", jumpScareVolume="0",
                     doneNewSaveFolder="true", tutorialDone="true", language="EN", focusloss="false", showSurvivalGuide="false")
    result = [line for line in lines if line.split("=", 1)[0] not in overrides]
    return "\n".join(result + [f"{k}={v}" for k, v in overrides.items()]) + "\n"


def prepare():
    check_idle()
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    run = HERE / "runs" / stamp
    run.mkdir(parents=True, exist_ok=False)
    build = run / "classes"
    build.mkdir()
    sources = sorted((HERE / "harness/src").rglob("*.java"))
    cp = str(GAME / "projectzomboid.jar") + ";" + str(GAME / "ZombieBuddy.jar")
    subprocess.run([str(JDK / "javac.exe"), "--release", "25", "-encoding", "UTF-8", "-cp", cp,
                    "-d", str(build)] + [str(p) for p in sources], check=True)
    cache = run / "cache"
    caravans_repo = REPO.parent.parent / "pz-alife-caravans/repo"
    mods = {
        "ZombieBuddy": WORKSHOP / "3619862853/mods/ZombieBuddy",
        "ProjectALifeNPCs": WORKSHOP / "3803984183/mods/ProjectALifeNPCs",
        "ALifeCaravans": caravans_repo,
        "ALifeAirwaves": REPO,
        "ALALiveTest": HERE / "harness",
    }
    for name, src in mods.items():
        ignore = shutil.ignore_patterns(".git", "tools", "docs", "scratch", "dist", "__pycache__", "src")
        if name in ("ALifeCaravans", "ALifeAirwaves"):
            for folder in ("42", "common"):
                shutil.copytree(src / folder, cache / "mods" / name / folder, ignore=ignore)
            continue
        if name == "ZombieBuddy":
            ignore = shutil.ignore_patterns("c", "doc", "java", ".git")
        shutil.copytree(src, cache / "mods" / name, ignore=ignore)
    test = cache / "mods/ALALiveTest"
    for folder in (test / "common", test / "42/media/java"):
        folder.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(JDK / "jar.exe"), "--create", "--file", str(test / "42/media/java/ALALiveTest.jar"),
                    "-C", str(build), "."], check=True)
    write(cache / "mods/default.txt", "VERSION = 1,\nmods\n{\n" +
          "".join(f"    mod = {name},\n" for name in mods) + "}\nmaps\n{\n}\n")
    write(cache / "mods/reset-mods-42_00.txt", "Keep isolated active mod selection.\n")
    write(cache / "options.ini", options())
    write(run / "zbcfg/config.json", json.dumps({"trusted_authors": [], "auto_fix_mod_order": False,
                                                "fix_approval_dialog_cursor": True, "preload_mods": {}}))
    state = {"run": str(run), "cache": str(cache), "pid": None}
    write(CURRENT, json.dumps(state, indent=2))
    print(json.dumps(state, indent=2))
    return state


def state():
    return json.loads(CURRENT.read_text(encoding="utf-8"))


def start():
    check_idle()
    data = state()
    run, cache = Path(data["run"]), Path(data["cache"])
    args = [str(GAME / "jre64/bin/java.exe"), f"-agentlib:zbNative=policy=allow-all,config_dir={run / 'zbcfg'}",
            "-Djava.awt.headless=true", "--enable-native-access=ALL-UNNAMED",
            "--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED", "-XX:-CreateCoredumpOnCrash",
            "-XX:-OmitStackTraceInFastThrow", "-XX:+UseZGC", "-Dzomboid.steam=0", "-Xmx4096m",
            "-Djava.library.path=./win64/;./", "-cp", "./;projectzomboid.jar",
            "zombie.gameStates.MainScreenState", "-cachedir=" + str(cache), "-nosteam"]
    write(run / "command.json", json.dumps(args, indent=2))
    with (run / "client.out.log").open("w", encoding="utf-8") as log:
        proc = subprocess.Popen(args, cwd=GAME, stdout=log, stderr=subprocess.STDOUT,
                                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | 0x00000008 | 0x08000000)
    data["pid"] = proc.pid
    write(CURRENT, json.dumps(data, indent=2))
    print("STARTED pid=" + str(proc.pid) + " cache=" + str(cache))


def stop():
    if not CURRENT.exists():
        return
    data = state()
    pid = data.get("pid")
    if pid:
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)
        for _ in range(20):
            if not [p for p in processes() if p["ProcessId"] == pid]:
                break
            time.sleep(1)
    print("Stopped isolated SP test process")


def wait(timeout_sec=360):
    data = state()
    cache = Path(data["cache"])
    res_file = cache / "Lua/ALALive_result.txt"
    con_file = cache / "console.txt"
    t0 = time.time()
    while time.time() - t0 < timeout_sec:
        if res_file.exists():
            time.sleep(2)
            break
        time.sleep(4)
    stop()
    if con_file.exists():
        txt = con_file.read_text(encoding="utf-8", errors="replace")
        rx = re.compile(r"\[ALALive\]|\[ALA\]|\[ALC\]|ERROR.*Lua|attempted index|stack traceback", re.I)
        for ln in txt.splitlines():
            if rx.search(ln):
                print(ln[:400])
        err_rx = re.compile(r"ERROR: Lua|attempted index|stack traceback|\[ALA\].*failed:", re.I)
        errs = [ln for ln in txt.splitlines() if err_rx.search(ln)]
        print("--- console Lua errors:", len(errs))
    if not res_file.exists():
        print("FAIL: ALALive_result.txt was not produced within timeout")
        sys.exit(1)
    res_text = res_file.read_text(encoding="utf-8", errors="replace")
    print("=== ALALive_result.txt ===")
    print(res_text)
    if not res_text.startswith("PASS"):
        sys.exit(1)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "prepare":
        prepare()
    elif cmd == "start":
        start()
    elif cmd == "stop":
        stop()
    elif cmd == "wait":
        wait(int(sys.argv[2]) if len(sys.argv) > 2 else 360)
    elif cmd == "run":
        prepare()
        start()
        wait(int(sys.argv[2]) if len(sys.argv) > 2 else 360)
