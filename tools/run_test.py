"""Run the lupa simulation tests and static Kahlua/localization checks for A-Life: Airwaves & Contracts.
Exit 1 on any failure.
"""
import glob
import json
import os
import re
import sys

import lupa
try:
    import lupa.lua51
    lupa.LuaRuntime = lupa.lua51.LuaRuntime
except ImportError:
    pass

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_ROOT = os.path.dirname(HERE).replace("\\", "/")
TRANSLATE = os.path.join(MOD_ROOT, "42", "media", "lua", "shared", "Translate")


def load(lang, name):
    with open(os.path.join(TRANSLATE, lang, name), "rb") as handle:
        raw = handle.read()
    return json.loads(raw.decode("utf-8"))


def main():
    failed = 0
    lua_files = sorted(glob.glob(os.path.join(MOD_ROOT, "42", "media", "lua", "**", "*.lua"), recursive=True))
    if not lua_files:
        print("FAIL no Lua files found under 42/media/lua")
        return 1

    ui_refs = set()
    modopt_refs = set()

    for path in lua_files:
        with open(path, encoding="utf-8") as handle:
            source = handle.read()
        executable = re.sub(r"--\[\[.*?\]\]|--[^\n]*", "", source, flags=re.S)
        executable_nostr = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', executable)
        for match in re.finditer(r"\bgoto\b|\bcontinue\b|::[A-Za-z_][A-Za-z0-9_]*::|\btable\.unpack\b", executable_nostr):
            line = executable_nostr.count("\n", 0, match.start()) + 1
            print("FAIL Kahlua unsupported token", match.group(0), path, "line", line)
            failed += 1
        try:
            lupa.LuaRuntime().compile(source)
        except Exception as error:  # noqa: BLE001
            print("FAIL syntax", path, error)
            failed += 1

        for m in re.finditer(r'L\.ui\(\s*"([A-Za-z0-9_]+)"\s*,', executable):
            ui_refs.add("IGUI_ALA_ui_" + m.group(1))
        for m in re.finditer(r'"(UI_ALA_[A-Za-z0-9_]+)"', executable):
            modopt_refs.add(m.group(1))

    translations = {}
    sandbox_path = os.path.join(MOD_ROOT, "42", "media", "sandbox-options.txt")
    with open(sandbox_path, encoding="utf-8") as handle:
        sb_text = handle.read()
        for line_number, line in enumerate(sb_text.splitlines(), 1):
            if "--" in line:
                print("FAIL CustomSandboxOptions comment", sandbox_path, "line", line_number)
                failed += 1

    for name in ("IG_UI.json", "UI.json", "Sandbox.json"):
        en, ru = load("EN", name), load("RU", name)
        if set(en) != set(ru):
            print("FAIL translation keys differ in", name, sorted(set(en) ^ set(ru)))
            failed += 1
        for key, value in list(en.items()) + list(ru.items()):
            if not str(value).strip():
                print("FAIL empty translation", name, key)
                failed += 1
            if name == "Sandbox.json" and "%" in str(value):
                print("FAIL percent sign in Sandbox.json", key, value)
                failed += 1
        translations.update(en)

    for key in re.findall(r"translation\s*=\s*([\w_]+)", sb_text):
        if "Sandbox_" + key not in translations:
            print("FAIL missing Sandbox translation", key)
            failed += 1

    for key in sorted(ui_refs):
        if key not in translations:
            print("FAIL missing IGUI_ALA_ui key in IG_UI.json:", key)
            failed += 1

    for key in sorted(modopt_refs):
        if key not in translations:
            print("FAIL missing UI_ALA key in UI.json:", key)
            failed += 1

    for lang in ("EN", "RU"):
        lang_map = {}
        for name in ("IG_UI.json", "UI.json", "Sandbox.json"):
            lang_map.update(load(lang, name))
        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        lua.globals().MOD_ROOT = MOD_ROOT
        lua.globals().TEST_LANG = lang
        table = lua.table()
        for key, value in lang_map.items():
            table[key] = value
        lua.globals().TRANSLATIONS = table
        with open(os.path.join(HERE, "test_ala.lua"), encoding="utf-8") as handle:
            source = handle.read()
        print(f"== test_ala.lua ({lang})")
        failed += lua.execute(source) or 0

    print("TOTAL failed =", failed)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
