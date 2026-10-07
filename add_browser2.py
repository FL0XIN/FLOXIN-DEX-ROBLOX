import sys

PATH = 'dex.source.lua'
with open(PATH, 'r', encoding='utf-8') as f:
    src = f.read()

ORIG = len(src)
print(f"[i] Original: {ORIG}")

if '["Browser"] = function' in src:
    print("ABORT: already patched")
    sys.exit(1)

# 1. insert Browser module
with open('browser_module.lua', 'r', encoding='utf-8') as f:
    module = f.read()

MARKER = '["Console"] = function()'
src = src.replace(MARKER, module + MARKER, 1)
src = src.replace('"ModelViewer","BulkCopier"}', '"ModelViewer","BulkCopier","Browser"}', 1)
src = src.replace('Console = Apps.Console', 'Console = Apps.Console\n\t\tBrowser = Apps.Browser', 1)
src = src.replace('Console = Console,', 'Console = Console,\n\t\t\tBrowser = Browser,', 1)
src = src.replace('Console.Init()', 'Console.Init()\n\t\tBrowser.Init()', 1)
print("[1] Browser module inserted")

# 2. Add CreateApp line WITH Material Icons icon (right after 3D Viewer CreateApp)
OLD = 'Main.CreateApp({Name = "3D Viewer", IconMap = Explorer.LegacyClassIcons, Icon = 54, Window = ModelViewer.Window})'
NEW = OLD + '\n\t\tMain.FloxIcons = Main.FloxIcons or Lib.IconMap.new("rbxassetid://3926305904",900,900,36,36)\n\t\tMain.CreateApp({Name = "Browser", IconMap = Main.FloxIcons, Icon = 242, Window = Browser.Window})'

if src.count(OLD) != 1:
    print(f"ABORT: 3D Viewer found {src.count(OLD)} times")
    sys.exit(1)
src = src.replace(OLD, NEW, 1)
print("[2] Browser icon set to Material Icons #242")

# verify
checks = [
    ('["Browser"] = function', 1),
    ('Browser.Init()', 1),
    ('Browser = Apps.Browser', 1),
    ('Browser = Browser,', 1),
    ('Name = "Browser"', 1),
    ('Main.FloxIcons = Main.FloxIcons or Lib.IconMap', 1),
]
for n, e in checks:
    c = src.count(n)
    if c != e:
        print(f"FAIL: {n} = {c} (expected {e})")
        sys.exit(1)
    print(f"  OK  {n} x{c}")

with open(PATH, 'w', encoding='utf-8') as f:
    f.write(src)

print()
print(f"[OK] New size: {len(src)} (delta +{len(src)-ORIG})")
print("SUCCESS")
